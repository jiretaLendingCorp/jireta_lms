-- supabase/migrations/014_disbursement_force_password_tier_fix.sql
--
-- Fixes (all idempotent — safe to re-run):
--   1. Fix loan_term_tiers.is_active — seed rows did not set it explicitly
--      causing get_loan_tier() to return NULL for all amounts.
--   2. Add disbursement_method + disbursement_meta to loans table (Step 4).
--   3. Add force_password_change column to users table.
--   4. Recreate get_loan_tier() to always work with is_active flag.
--   5. Add missing API endpoints columns to audit_logs if not present.
--   6. Add kyc_id FK to assignments for credit investigation flow.

-- ─── 1. Fix is_active on tier seed rows ──────────────────────────────────────
UPDATE loan_term_tiers SET is_active = TRUE
WHERE tier_label IN ('micro','small','medium','large');

INSERT INTO loan_term_tiers
  (tier_label, min_amount, max_amount, term_days, interest_rate, penalty_rate, penalty_grace_days, is_active)
VALUES
  ('micro',   3000.00,    9999.99,   40,  0.2000, 0.2000, 30, TRUE),
  ('small',   10000.00,  49999.99,   60,  0.2000, 0.2000, 30, TRUE),
  ('medium',  50000.00,  99999.99,   80,  0.2000, 0.2000, 30, TRUE),
  ('large',  100000.00, 500000.00,  120,  0.2000, 0.2000, 30, TRUE)
ON CONFLICT (tier_label) DO UPDATE SET
  is_active          = TRUE,
  min_amount         = EXCLUDED.min_amount,
  max_amount         = EXCLUDED.max_amount,
  term_days          = EXCLUDED.term_days,
  interest_rate      = EXCLUDED.interest_rate,
  penalty_rate       = EXCLUDED.penalty_rate,
  penalty_grace_days = EXCLUDED.penalty_grace_days,
  updated_at         = NOW();

-- ─── 2. Recreate get_loan_tier() ─────────────────────────────────────────────
-- Ensures is_active filter works correctly. Monthly = ceil(term_days/30) months.
CREATE OR REPLACE FUNCTION get_loan_tier(p_amount NUMERIC)
RETURNS loan_term_tiers
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT *
  FROM   loan_term_tiers
  WHERE  is_active = TRUE
    AND  p_amount  >= min_amount
    AND  p_amount  <= max_amount
  ORDER BY min_amount ASC
  LIMIT 1;
$$;

-- ─── 3. loans — disbursement columns ─────────────────────────────────────────
ALTER TABLE loans
  ADD COLUMN IF NOT EXISTS disbursement_method TEXT
    CHECK (disbursement_method IN ('cash','gcash','office') OR disbursement_method IS NULL),
  ADD COLUMN IF NOT EXISTS disbursement_meta   JSONB;

COMMENT ON COLUMN loans.disbursement_method IS
  'How approved funds reach the lender: cash=rider delivers, gcash=auto-transfer, office=pickup';
COMMENT ON COLUMN loans.disbursement_meta IS
  'Encrypted PII for GCash disbursement: {gcash_name, gcash_number} (AES-256-GCM)';

-- ─── 4. users — force_password_change ────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS force_password_change BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN users.force_password_change IS
  'Set TRUE by head_manager/employee via /user-update/reset-password. '
  'Router redirects to /force-change-password until user changes their password.';

-- ─── 5. assignments — kyc_id for Credit Investigation flow ───────────────────
ALTER TABLE rider_assignments
  ADD COLUMN IF NOT EXISTS kyc_id UUID
    REFERENCES kyc_submissions(id) ON DELETE SET NULL;

COMMENT ON COLUMN rider_assignments.kyc_id IS
  'For credit investigation type: references the KYC submission the rider must verify.';

CREATE INDEX IF NOT EXISTS idx_rider_assignments_kyc_id
  ON rider_assignments (kyc_id)
  WHERE kyc_id IS NOT NULL;

-- ─── 6. audit_logs — ensure actor columns exist (009 may not have run) ────────
ALTER TABLE audit_logs
  ADD COLUMN IF NOT EXISTS actor_name  TEXT,
  ADD COLUMN IF NOT EXISTS actor_role  TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS approved_by TEXT;  -- human-readable approver name

-- Back-fill actor_name from users where still NULL
UPDATE audit_logs al
SET
  actor_name = TRIM(CONCAT(COALESCE(u.first_name,''),' ',COALESCE(u.last_name,''))),
  actor_role = u.role
FROM users u
WHERE al.user_id = u.id AND al.actor_name IS NULL;

-- ─── 7. Performance indices ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_loans_disbursement_method
  ON loans (disbursement_method) WHERE disbursement_method IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_force_pw_change
  ON users (force_password_change) WHERE force_password_change = TRUE;