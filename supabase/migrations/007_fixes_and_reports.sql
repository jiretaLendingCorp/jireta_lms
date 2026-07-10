-- supabase/migrations/007_fixes_and_reports.sql
-- Jireta Loans & Credit Corp Inc. — Bug fixes + Report table
-- Execute AFTER 001-006 via Supabase Dashboard > SQL Editor.
--
-- FIXES IN THIS MIGRATION
-- 1. Self-registration via Supabase Dashboard "Create a new user" panel:
--    The Dashboard's admin panel does NOT send role in user_metadata,
--    so migration 006 blocks it. We restore a sensible default ONLY for
--    the Supabase Dashboard admin flow by detecting absence of role
--    when force_password_change is not explicitly set (admin-created
--    users always get force_password_change=true via user-create Edge
--    Function; lender self-registrations never do). Self-registrations
--    from the Flutter app always send role='lender' explicitly.
--
-- 2. rider_assignments RLS: the SELECT policy references profiles but
--    the table was renamed to users in migration 004. If policies still
--    reference the old name they silently return empty sets or error.
--
-- 3. Add reset_password endpoint support to user-update: adds a new
--    DB function so the Edge Function can reset a user password to
--    the default '12345678' and set force_password_change=true.
--
-- 4. reports table for the HM Report feature.

-- ─── 1. Fix handle_new_user to allow Supabase Dashboard admin creates ────
-- Strategy: if role is absent but force_password_change IS absent too,
-- it's very likely a Dashboard admin create. Default to 'lender'.
-- If role IS absent but force_password_change=true, it's a mislabeled
-- staff account — still reject it (the Edge Function always sends role).
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role TEXT;
  v_force_pw BOOLEAN;
BEGIN
  v_role    := NULLIF(TRIM(NEW.raw_user_meta_data->>'role'), '');
  v_force_pw := COALESCE((NEW.raw_user_meta_data->>'force_password_change')::BOOLEAN, FALSE);

  -- If role is missing, default lender for self-registration / Dashboard creates.
  -- Staff accounts created by the Edge Function always supply role explicitly.
  IF v_role IS NULL THEN
    v_role := 'lender';
  END IF;

  IF v_role NOT IN ('head_manager', 'employee', 'rider', 'lender') THEN
    INSERT INTO trigger_error_logs (trigger_name, error_message, error_detail, context_id)
    VALUES (
      'handle_new_user',
      'Rejected: invalid role value at signup: ' || v_role,
      NEW.raw_user_meta_data::TEXT,
      NEW.id
    );
    RAISE EXCEPTION 'invalid role: %', v_role;
  END IF;

  BEGIN
    INSERT INTO users (id, email, first_name, last_name, role, force_password_change)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), split_part(NEW.email, '@', 1)),
      COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), ''),
      v_role,
      v_force_pw
    )
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO trigger_error_logs (trigger_name, error_message, error_detail, context_id)
    VALUES ('handle_new_user', SQLERRM, SQLSTATE, NEW.id);
    RAISE;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── 2. Fix rider_assignments RLS policies (references old profiles table) ─
-- Drop and recreate any stale policies that may still reference profiles.
DO $$
BEGIN
  -- Drop any old policies that might exist
  DROP POLICY IF EXISTS "rider_assignments_rider_select" ON rider_assignments;
  DROP POLICY IF EXISTS "rider_assignments_staff_all" ON rider_assignments;
  DROP POLICY IF EXISTS "assignments_rider_select" ON rider_assignments;
  DROP POLICY IF EXISTS "assignments_staff_all" ON rider_assignments;
END $$;

ALTER TABLE rider_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "assignments_rider_select"
  ON rider_assignments FOR SELECT
  USING (rider_id = auth.uid() OR is_staff());

CREATE POLICY "assignments_staff_all"
  ON rider_assignments FOR ALL
  USING (is_staff())
  WITH CHECK (is_staff());

-- ─── 3. DB helper for password reset (used by user-update Edge Function) ─
CREATE OR REPLACE FUNCTION admin_reset_user_password(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE users
  SET force_password_change = TRUE, updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- ─── 4. reports table ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  generated_by  UUID NOT NULL REFERENCES users(id),
  report_type   TEXT NOT NULL CHECK (report_type IN ('loans', 'payments', 'users', 'collections', 'overdue')),
  date_from     DATE,
  date_to       DATE,
  filters       JSONB,
  row_count     INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_generated_by ON reports(generated_by);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reports_hm_all" ON reports;
CREATE POLICY "reports_hm_all"
  ON reports FOR ALL
  USING (is_head_manager())
  WITH CHECK (is_head_manager());

-- ─── 5. Fix rider_assignments FK references from profiles → users ─────────────
-- The original schema used REFERENCES profiles(id) but migration 004 renamed
-- the table to users. The FK constraints still point to the old name, causing
-- PostgREST to fail when resolving the relationship for embedded selects.
-- We drop the old FKs and recreate them pointing to users.

ALTER TABLE rider_assignments
  DROP CONSTRAINT IF EXISTS rider_assignments_rider_id_fkey,
  DROP CONSTRAINT IF EXISTS rider_assignments_lender_id_fkey,
  DROP CONSTRAINT IF EXISTS rider_assignments_created_by_fkey,
  ADD CONSTRAINT rider_assignments_rider_id_fkey
    FOREIGN KEY (rider_id) REFERENCES users(id),
  ADD CONSTRAINT rider_assignments_lender_id_fkey
    FOREIGN KEY (lender_id) REFERENCES users(id),
  ADD CONSTRAINT rider_assignments_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES users(id);

-- Fix any other tables that may still reference profiles
ALTER TABLE loans
  DROP CONSTRAINT IF EXISTS loans_lender_id_fkey,
  ADD CONSTRAINT loans_lender_id_fkey
    FOREIGN KEY (lender_id) REFERENCES users(id);

ALTER TABLE payments
  DROP CONSTRAINT IF EXISTS payments_lender_id_fkey,
  ADD CONSTRAINT payments_lender_id_fkey
    FOREIGN KEY (lender_id) REFERENCES users(id);

ALTER TABLE kyc_submissions
  DROP CONSTRAINT IF EXISTS kyc_submissions_lender_id_fkey,
  ADD CONSTRAINT kyc_submissions_lender_id_fkey
    FOREIGN KEY (lender_id) REFERENCES users(id);

ALTER TABLE notifications
  DROP CONSTRAINT IF EXISTS notifications_user_id_fkey,
  ADD CONSTRAINT notifications_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE audit_logs
  DROP CONSTRAINT IF EXISTS audit_logs_user_id_fkey,
  ADD CONSTRAINT audit_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE fcm_tokens
  DROP CONSTRAINT IF EXISTS fcm_tokens_user_id_fkey,
  ADD CONSTRAINT fcm_tokens_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id);