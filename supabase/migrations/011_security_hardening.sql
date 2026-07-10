-- supabase/migrations/011_security_hardening.sql
-- SECURITY HARDENING: applies all missing security controls identified in audit.
-- All sensitive operations stay in TypeScript Edge Functions (service role).
-- Flutter/Dart never talks directly to Postgres.

-- ─── 1. Row-Level Security: verify all tables have RLS enabled ─────────────
ALTER TABLE users              ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans              ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_schedules     ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_submissions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_assignments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications      ENABLE ROW LEVEL SECURITY;

-- ─── 2. Default DENY — authenticated users get nothing unless a policy grants ─
-- Service role bypasses RLS entirely (Edge Functions use service role).
-- Authenticated users only get what is explicitly granted below.

-- users: authenticated can only read own row; service role manages all
CREATE POLICY IF NOT EXISTS "Users: own row read" ON users
  FOR SELECT TO authenticated USING (id = auth.uid());

CREATE POLICY IF NOT EXISTS "Users: service role full" ON users
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- loans: lender can read own loans; service role manages all
CREATE POLICY IF NOT EXISTS "Loans: lender owns" ON loans
  FOR SELECT TO authenticated USING (lender_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Loans: service role full" ON loans
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- loan_schedules: lender can read own
CREATE POLICY IF NOT EXISTS "LoanSchedules: lender owns" ON loan_schedules
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM loans WHERE loans.id = loan_schedules.loan_id AND loans.lender_id = auth.uid())
  );

CREATE POLICY IF NOT EXISTS "LoanSchedules: service role full" ON loan_schedules
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- payments: lender or rider can read own payments
CREATE POLICY IF NOT EXISTS "Payments: participant reads" ON payments
  FOR SELECT TO authenticated
  USING (
    lender_id = auth.uid()
    OR recorder_id = auth.uid()
  );

CREATE POLICY IF NOT EXISTS "Payments: service role full" ON payments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- kyc_submissions: lender can read own
CREATE POLICY IF NOT EXISTS "KYC: lender owns" ON kyc_submissions
  FOR SELECT TO authenticated USING (lender_id = auth.uid());

CREATE POLICY IF NOT EXISTS "KYC: service role full" ON kyc_submissions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- rider_assignments: rider can read own
CREATE POLICY IF NOT EXISTS "Assignments: rider owns" ON rider_assignments
  FOR SELECT TO authenticated USING (rider_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Assignments: service role full" ON rider_assignments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- audit_logs: no direct read for authenticated; service role only
-- (HM reads through the audit Edge Function which uses service role)
CREATE POLICY IF NOT EXISTS "AuditLogs: service role only" ON audit_logs
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- system_settings: authenticated can read (lenders see loan params)
CREATE POLICY IF NOT EXISTS "Settings: authenticated read" ON system_settings
  FOR SELECT TO authenticated USING (true);

CREATE POLICY IF NOT EXISTS "Settings: service role full" ON system_settings
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- notifications: user reads own
CREATE POLICY IF NOT EXISTS "Notifications: own read" ON notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Notifications: service role full" ON notifications
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ─── 3. Auto-updated_at trigger on all mutable tables ─────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users','loans','kyc_submissions','rider_assignments',
    'system_settings','payments','rider_info'
  ]
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_updated_at ON %I;
       CREATE TRIGGER trg_updated_at BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at();',
      t, t
    );
  END LOOP;
END;
$$;

-- ─── 4. Prevent direct role escalation via users table ─────────────────────
-- Only service_role can update the role column.
-- Authenticated users cannot change their own role directly.
CREATE OR REPLACE FUNCTION prevent_role_escalation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- This function runs as definer (service_role); a trigger on the users
  -- table blocks authenticated direct writes to the role column.
  -- Service role calls bypass RLS entirely, so this only fires for
  -- direct authenticated writes.
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Direct role changes are not permitted. Use the admin Edge Function.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON users;
CREATE TRIGGER trg_prevent_role_escalation
  BEFORE UPDATE OF role ON users
  FOR EACH ROW
  WHEN (pg_trigger_depth() = 0)  -- don't fire when service_role runs internally
  EXECUTE FUNCTION prevent_role_escalation();

-- ─── 5. Loan amount & interest sanity check constraints ────────────────────
ALTER TABLE loans
  ADD CONSTRAINT IF NOT EXISTS chk_loans_principal_positive
    CHECK (principal_amount > 0),
  ADD CONSTRAINT IF NOT EXISTS chk_loans_interest_non_negative
    CHECK (interest_amount >= 0),
  ADD CONSTRAINT IF NOT EXISTS chk_loans_total_payable_gte_principal
    CHECK (total_payable >= principal_amount);

-- ─── 6. Audit log: immutable rows — no UPDATE or DELETE allowed ────────────
CREATE OR REPLACE FUNCTION prevent_audit_mutation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RAISE EXCEPTION 'Audit logs are immutable and cannot be modified or deleted.';
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_immutable_upd ON audit_logs;
CREATE TRIGGER trg_audit_immutable_upd
  BEFORE UPDATE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_mutation();

DROP TRIGGER IF EXISTS trg_audit_immutable_del ON audit_logs;
CREATE TRIGGER trg_audit_immutable_del
  BEFORE DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_mutation();

-- ─── 7. Index optimisations for frequently-joined columns ──────────────────
CREATE INDEX IF NOT EXISTS idx_loans_lender_id     ON loans(lender_id);
CREATE INDEX IF NOT EXISTS idx_loans_status        ON loans(status);
CREATE INDEX IF NOT EXISTS idx_payments_lender_id  ON payments(lender_id);
CREATE INDEX IF NOT EXISTS idx_kyc_lender_id       ON kyc_submissions(lender_id);
CREATE INDEX IF NOT EXISTS idx_assignments_rider   ON rider_assignments(rider_id);
CREATE INDEX IF NOT EXISTS idx_assignments_loan    ON rider_assignments(loan_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user  ON notifications(user_id, is_read);