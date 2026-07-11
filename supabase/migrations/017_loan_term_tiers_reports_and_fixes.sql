-- supabase/migrations/016_loan_term_tiers_reports_and_fixes.sql
-- Comprehensive fix migration — safe to re-run (all idempotent)
--
-- FIXES:
--   1. CREATE loan_term_tiers table (CRITICAL — was never created; migrations 014/015
--      referenced it for INSERT/UPDATE but the table did not exist, causing
--      get_loan_tier() to always fail with "relation loan_term_tiers does not exist")
--   2. CREATE disbursement_assignments table (loan-apply/index.ts references it for
--      cash disbursement placeholder but the table was never defined)
--   3. Add tier_label FK column to loans table (loan-apply inserts it but column absent)
--   4. Fix reports RLS — allow employees to generate/read reports, not just head_manager
--   5. Add set_updated_at trigger to loan_term_tiers
--   6. Seed default tiers (idempotent via ON CONFLICT)
--   7. Add composite index on payment_schedules(loan_id, is_paid) for schedule queries
--   8. Fix reports table to include report_data JSONB column for storing actual results

-- ─── 1. loan_term_tiers (the missing table) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS loan_term_tiers (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tier_label          TEXT NOT NULL UNIQUE,
  min_amount          NUMERIC(12,2) NOT NULL,
  max_amount          NUMERIC(12,2) NOT NULL,
  term_days           INTEGER NOT NULL CHECK (term_days > 0),
  interest_rate       NUMERIC(5,4) NOT NULL DEFAULT 0.20
                        CHECK (interest_rate >= 0 AND interest_rate <= 1),
  penalty_rate        NUMERIC(5,4) NOT NULL DEFAULT 0.20
                        CHECK (penalty_rate >= 0 AND penalty_rate <= 1),
  penalty_grace_days  INTEGER NOT NULL DEFAULT 30 CHECK (penalty_grace_days >= 0),
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ,
  CONSTRAINT chk_tier_amount_range CHECK (max_amount > min_amount)
);

COMMENT ON TABLE loan_term_tiers IS
  'Configurable loan tiers — head_manager and employee can update term_days, '
  'interest_rate, penalty_rate per tier. Used by get_loan_tier() to compute '
  'installments server-side (loan-apply Edge Function).';

CREATE INDEX IF NOT EXISTS idx_loan_term_tiers_is_active
  ON loan_term_tiers (is_active) WHERE is_active = TRUE;

-- RLS: authenticated users can read tiers (lenders see rates when applying)
-- service_role manages all (Edge Functions)
ALTER TABLE loan_term_tiers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tiers_authenticated_read" ON loan_term_tiers;
CREATE POLICY "tiers_authenticated_read" ON loan_term_tiers
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "tiers_service_role_all" ON loan_term_tiers;
CREATE POLICY "tiers_service_role_all" ON loan_term_tiers
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- auto-updated_at on loan_term_tiers
DROP TRIGGER IF EXISTS trg_updated_at ON loan_term_tiers;
CREATE TRIGGER trg_updated_at
  BEFORE UPDATE ON loan_term_tiers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── 2. Seed default tiers (idempotent) ───────────────────────────────────────
INSERT INTO loan_term_tiers
  (tier_label, min_amount, max_amount, term_days, interest_rate, penalty_rate, penalty_grace_days, is_active)
VALUES
  ('micro',   3000.00,    9999.99,   40,  0.2000, 0.2000, 30, TRUE),
  ('small',   10000.00,  49999.99,   60,  0.2000, 0.2000, 30, TRUE),
  ('medium',  50000.00,  99999.99,   80,  0.2000, 0.2000, 30, TRUE),
  ('large',  100000.00, 500000.00,  120,  0.2000, 0.2000, 30, TRUE)
ON CONFLICT (tier_label) DO UPDATE SET
  min_amount         = EXCLUDED.min_amount,
  max_amount         = EXCLUDED.max_amount,
  term_days          = EXCLUDED.term_days,
  interest_rate      = EXCLUDED.interest_rate,
  penalty_rate       = EXCLUDED.penalty_rate,
  penalty_grace_days = EXCLUDED.penalty_grace_days,
  is_active          = TRUE,
  updated_at         = NOW();

-- ─── 3. get_loan_tier() — authoritative tier lookup used by loan-apply ─────────
CREATE OR REPLACE FUNCTION get_loan_tier(p_amount NUMERIC)
RETURNS loan_term_tiers
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT *
  FROM   loan_term_tiers
  WHERE  is_active = TRUE
    AND  p_amount >= min_amount
    AND  p_amount <= max_amount
  ORDER BY min_amount ASC
  LIMIT 1;
$$;

COMMENT ON FUNCTION get_loan_tier(NUMERIC) IS
  'Returns the single active tier whose range covers p_amount. '
  'Called by loan-apply Edge Function (server-side computation only).';

-- ─── 4. Add tier_label FK to loans ────────────────────────────────────────────
ALTER TABLE loans
  ADD COLUMN IF NOT EXISTS tier_label TEXT
    REFERENCES loan_term_tiers(tier_label) ON UPDATE CASCADE ON DELETE RESTRICT;

COMMENT ON COLUMN loans.tier_label IS
  'Which tier was active when this loan was applied. FK to loan_term_tiers.tier_label.';

CREATE INDEX IF NOT EXISTS idx_loans_tier_label ON loans(tier_label);

-- ─── 5. disbursement_assignments — cash disburse rider delivery table ──────────
-- loan-apply/index.ts inserts here when disbursement_method = 'cash'.
-- A rider is later assigned to physically deliver the cash to the lender.
CREATE TABLE IF NOT EXISTS disbursement_assignments (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id     UUID NOT NULL UNIQUE REFERENCES loans(id) ON DELETE CASCADE,
  rider_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  status      TEXT NOT NULL DEFAULT 'pending_assignment'
                CHECK (status IN ('pending_assignment','assigned','delivered','failed')),
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

COMMENT ON TABLE disbursement_assignments IS
  'Tracks rider delivery of cash loan disbursements. '
  'Created automatically when lender chooses cash disbursement method.';

CREATE INDEX IF NOT EXISTS idx_disb_assign_status
  ON disbursement_assignments (status);
CREATE INDEX IF NOT EXISTS idx_disb_assign_rider
  ON disbursement_assignments (rider_id) WHERE rider_id IS NOT NULL;

ALTER TABLE disbursement_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "disb_assignments_service_role" ON disbursement_assignments;
CREATE POLICY "disb_assignments_service_role" ON disbursement_assignments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "disb_assignments_staff_read" ON disbursement_assignments;
CREATE POLICY "disb_assignments_staff_read" ON disbursement_assignments
  FOR SELECT TO authenticated USING (is_staff());

DROP POLICY IF EXISTS "disb_assignments_rider_read" ON disbursement_assignments;
CREATE POLICY "disb_assignments_rider_read" ON disbursement_assignments
  FOR SELECT TO authenticated USING (rider_id = auth.uid());

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_updated_at ON disbursement_assignments;
CREATE TRIGGER trg_updated_at
  BEFORE UPDATE ON disbursement_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── 6. reports table — add report_data column if missing ─────────────────────
ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS report_data JSONB;

COMMENT ON COLUMN reports.report_data IS
  'Full serialised report result set — stored for re-download without recomputing.';

-- Fix reports RLS: employees should also be able to generate & view reports
DROP POLICY IF EXISTS "reports_hm_all" ON reports;
DROP POLICY IF EXISTS "reports_staff_all" ON reports;

CREATE POLICY "reports_staff_all" ON reports
  FOR ALL
  USING   (is_staff())
  WITH CHECK (is_staff());

-- ─── 7. Performance: composite index for payment schedule lookups ──────────────
CREATE INDEX IF NOT EXISTS idx_payment_schedules_loan_paid
  ON payment_schedules (loan_id, is_paid);

CREATE INDEX IF NOT EXISTS idx_payment_schedules_due_date_unpaid
  ON payment_schedules (due_date)
  WHERE is_paid = FALSE;

-- ─── 8. Performance: partial index for pending loans ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_loans_pending_review
  ON loans (created_at DESC)
  WHERE status IN ('pending', 'under_review');

CREATE INDEX IF NOT EXISTS idx_loans_active_maturity
  ON loans (maturity_date)
  WHERE status = 'active';