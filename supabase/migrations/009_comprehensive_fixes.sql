-- supabase/migrations/009_comprehensive_fixes.sql
-- Comprehensive fixes: rider_info table, audit log user names, interest rate control,
-- assignment type picker, security hardening, and 3NF improvements

-- ─── 1. Rider Info Table (3NF: rider-specific fields separate from users) ───
CREATE TABLE IF NOT EXISTS rider_info (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  address         TEXT,
  driver_license  TEXT,
  vehicle_info    TEXT,
  birthday        DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ
);

COMMENT ON TABLE rider_info IS '3NF: rider-specific attributes, separate from base users table';

CREATE INDEX IF NOT EXISTS idx_rider_info_user_id ON rider_info(user_id);

-- RLS on rider_info
ALTER TABLE rider_info ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on rider_info"
  ON rider_info FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Rider can read own rider_info"
  ON rider_info FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- ─── 2. Add interest_rate and penalty_rate to system_settings (controllable) ─
ALTER TABLE system_settings
  ADD COLUMN IF NOT EXISTS interest_rate   NUMERIC(5,4) NOT NULL DEFAULT 0.20,
  ADD COLUMN IF NOT EXISTS penalty_rate    NUMERIC(5,4) NOT NULL DEFAULT 0.20,
  ADD COLUMN IF NOT EXISTS penalty_grace_days INTEGER NOT NULL DEFAULT 30;

-- ─── 3. Audit log: add actor_name for human-readable logs ──────────────────
ALTER TABLE audit_logs
  ADD COLUMN IF NOT EXISTS actor_name TEXT,
  ADD COLUMN IF NOT EXISTS actor_role TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT;

-- Backfill existing audit logs with actor names from users table
UPDATE audit_logs al
SET
  actor_name = CONCAT(u.first_name, ' ', u.last_name),
  actor_role = u.role
FROM users u
WHERE al.user_id = u.id
  AND al.actor_name IS NULL;

-- ─── 4. Trigger: auto-populate actor_name on new audit log inserts ──────────
CREATE OR REPLACE FUNCTION populate_audit_actor()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_first  TEXT;
  v_last   TEXT;
  v_role   TEXT;
BEGIN
  SELECT first_name, last_name, role
  INTO v_first, v_last, v_role
  FROM users
  WHERE id = NEW.user_id;

  NEW.actor_name := TRIM(CONCAT(COALESCE(v_first,''), ' ', COALESCE(v_last,'')));
  NEW.actor_role := v_role;

  -- Auto-generate human-readable description if not provided
  IF NEW.description IS NULL THEN
    NEW.description := INITCAP(REPLACE(NEW.action, '_', ' '))
      || ' on ' || REPLACE(NEW.table_name, '_', ' ')
      || CASE WHEN NEW.record_id IS NOT NULL
              THEN ' (' || LEFT(NEW.record_id, 8) || ')'
              ELSE '' END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_actor ON audit_logs;
CREATE TRIGGER trg_audit_actor
  BEFORE INSERT ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION populate_audit_actor();

-- ─── 5. Security: Rate limiting table for auth attempts ────────────────────
CREATE TABLE IF NOT EXISTS auth_rate_limits (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  identifier  TEXT NOT NULL,  -- email or IP
  attempt_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  action      TEXT NOT NULL DEFAULT 'login'
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_identifier ON auth_rate_limits(identifier, attempt_at);

ALTER TABLE auth_rate_limits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only on auth_rate_limits"
  ON auth_rate_limits FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ─── 6. Security: Session tracking ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_sessions (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_info  TEXT,
  ip_address   TEXT,
  logged_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  logged_out_at TIMESTAMPTZ,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);

ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access on user_sessions"
  ON user_sessions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "User can see own sessions"
  ON user_sessions FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ─── 7. Lender-visible settings view ───────────────────────────────────────
CREATE OR REPLACE VIEW lender_loan_params AS
SELECT
  min_loan_amount,
  max_loan_amount,
  interest_rate,
  penalty_rate,
  penalty_grace_days
FROM system_settings
LIMIT 1;

-- Grant SELECT to authenticated users so lenders can see it
GRANT SELECT ON lender_loan_params TO authenticated;

-- ─── 8. Add indexes for audit log search ───────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_name ON audit_logs(actor_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);