-- supabase/migrations/015_fix_tiers_and_disbursement.sql
-- Fixes:
--   1. Ensure is_active = TRUE on seed rows (was omitted in migration 013,
--      causing get_loan_tier() to return NULL for all amounts).
--   2. All tiers get monthly installment support (micro tier 40 days → 2 months).
--   3. Add disbursement_method + disbursement_meta to loans table (Step 4 of apply).
--   4. Add force_password_change column to users (reset password flow).

-- ─── 1. Fix is_active on existing tier rows ───────────────────────────────────
UPDATE loan_term_tiers SET is_active = TRUE
WHERE tier_label IN ('micro', 'small', 'medium', 'large');

-- Ensure micro tier exists with correct range
INSERT INTO loan_term_tiers (tier_label, min_amount, max_amount, term_days, interest_rate, penalty_rate, penalty_grace_days, is_active)
VALUES ('micro', 3000.00, 9999.99, 40, 0.2000, 0.2000, 30, TRUE)
ON CONFLICT (tier_label) DO UPDATE SET
  is_active          = TRUE,
  min_amount         = EXCLUDED.min_amount,
  max_amount         = EXCLUDED.max_amount,
  term_days          = EXCLUDED.term_days,
  interest_rate      = EXCLUDED.interest_rate,
  penalty_rate       = EXCLUDED.penalty_rate,
  penalty_grace_days = EXCLUDED.penalty_grace_days,
  updated_at         = NOW();

-- ─── 2. Recreate get_loan_tier to also return monthly_installments ────────────
CREATE OR REPLACE FUNCTION get_loan_tier(p_amount NUMERIC)
RETURNS loan_term_tiers
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT *
  FROM   loan_term_tiers
  WHERE  is_active = TRUE
    AND  p_amount >= min_amount
    AND  p_amount <= max_amount
  ORDER BY min_amount ASC
  LIMIT 1;
$$;

-- ─── 3. Disbursement columns on loans ─────────────────────────────────────────
ALTER TABLE loans
  ADD COLUMN IF NOT EXISTS disbursement_method TEXT
    CONSTRAINT disbursement_method_check
    CHECK (disbursement_method IN ('cash', 'gcash', 'office') OR disbursement_method IS NULL),
  ADD COLUMN IF NOT EXISTS disbursement_meta  JSONB;

COMMENT ON COLUMN loans.disbursement_method IS
  'How the approved loan will be sent: cash=rider delivers, gcash=auto-transfer, office=lender picks up';
COMMENT ON COLUMN loans.disbursement_meta IS
  'Structured metadata: { gcash_name, gcash_number } for gcash; empty for cash/office';

-- ─── 4. Force-password-change on users ────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS force_password_change BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN users.force_password_change IS
  'When TRUE the app forces a password change screen before the user can proceed. '
  'Set by head_manager/employee via user-update/reset-password endpoint.';

-- RLS: lender/rider can read their own force_password_change via existing policy.
-- No additional policy needed because existing users SELECT policy covers it.