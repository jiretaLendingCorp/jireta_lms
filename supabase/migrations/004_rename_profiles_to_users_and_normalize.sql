-- supabase/migrations/004_rename_profiles_to_users_and_normalize.sql
-- Jireta Loans & Credit Corp Inc. — Rename `profiles` → `users` + 3NF cleanup
-- Execute AFTER 001_initial_schema.sql, 002_rls_policies.sql, and
-- 003_third_party_integration_columns.sql via Supabase Dashboard > SQL Editor.
--
-- This migration does two things:
--   1. Renames the `profiles` table (and everything namespaced after it) to
--      `users`, which is what it actually represents — every role
--      (head_manager, employee, rider, lender), not just "profile" data.
--   2. Removes redundant/derivable columns that violate normalization:
--      - `users.employer` / `users.monthly_income` duplicated data that
--        already lives (correctly, AES-256-GCM encrypted) on
--        `kyc_submissions`. Nothing in the codebase ever wrote to these
--        columns, so they were dead, unencrypted shadow copies of PII.
--      - `users.credit_score` had no writer anywhere in the system — a
--        "fact" with no functional dependency on anything, just an empty
--        column. Removed until a real credit-scoring feature owns it
--        (at which point it should be its own history table, not a single
--        mutable field on the user).
--      - `loans.total_payable` was an independently-stored value that's
--        100% derivable from `principal_amount + interest_amount` on the
--        same row — a transitive/derived-value redundancy. Converted to a
--        PostgreSQL GENERATED column so it can never drift out of sync.
--      - `payments.method` duplicated its own domain of valid values: once
--        in an inline CHECK constraint, and again as rows in the
--        `payment_methods` lookup table. Replaced the CHECK with a proper
--        FOREIGN KEY so the valid-values list is defined in exactly one
--        place.
--
-- NOT changed (deliberately, see explanation in chat): `outstanding_balance`
-- and `days_overdue` are intentionally-maintained running/point-in-time
-- snapshots (common, defensible denormalization for ledger-style data),
-- not redundant facts — leaving them as application/cron-maintained state.

-- ─── 1. Rename profiles → users ────────────────────────────────────────────
ALTER TABLE profiles RENAME TO users;

-- Cosmetic: rename the auto-generated constraint/index names that still say
-- "profiles" so \d users reads cleanly. If your live database happens to
-- have different auto-generated names, find them first with:
--   SELECT conname FROM pg_constraint WHERE conrelid = 'users'::regclass;
--   SELECT indexname FROM pg_indexes WHERE tablename = 'users';
ALTER TABLE users RENAME CONSTRAINT profiles_pkey TO users_pkey;
ALTER TABLE users RENAME CONSTRAINT profiles_email_key TO users_email_key;
ALTER TABLE users RENAME CONSTRAINT profiles_role_check TO users_role_check;

ALTER INDEX idx_profiles_role RENAME TO idx_users_role;
ALTER INDEX idx_profiles_email RENAME TO idx_users_email;

-- ─── 2. Drop redundant / dead PII columns from users ───────────────────────
-- employer + monthly_income belong on kyc_submissions (already encrypted /
-- captured there); credit_score has no current writer.
ALTER TABLE users
  DROP COLUMN IF EXISTS employer,
  DROP COLUMN IF EXISTS monthly_income,
  DROP COLUMN IF EXISTS credit_score;

-- ─── 3. Update trigger + helper functions to reference `users` ────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO users (id, email, first_name, last_name, role, force_password_change)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'first_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'lender'),
    FALSE
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
-- (Trigger `on_auth_user_created` already points at this function by name —
-- no need to recreate it.)

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM users WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role IN ('head_manager', 'employee') FROM users WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_head_manager()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role = 'head_manager' FROM users WHERE id = auth.uid()
$$;

-- ─── 4. Rename RLS policies to match the new table name ───────────────────
ALTER POLICY "profiles_select_own"  ON users RENAME TO "users_select_own";
ALTER POLICY "profiles_select_staff" ON users RENAME TO "users_select_staff";
ALTER POLICY "profiles_update_own"  ON users RENAME TO "users_update_own";
ALTER POLICY "profiles_update_hm"   ON users RENAME TO "users_update_hm";

-- ─── 5. loans.total_payable → generated column (3NF: drop derived value) ──
-- All edge functions already only ever READ total_payable (loan-apply was
-- updated to stop inserting it explicitly) — Postgres now computes it.
ALTER TABLE loans DROP COLUMN total_payable;
ALTER TABLE loans
  ADD COLUMN total_payable NUMERIC(12, 2)
  GENERATED ALWAYS AS (principal_amount + interest_amount) STORED;

-- ─── 6. payments.method → FK into payment_methods (3NF: single source of truth) ──
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_method_check;
ALTER TABLE payments
  ADD CONSTRAINT payments_method_fkey
  FOREIGN KEY (method) REFERENCES payment_methods(method);

-- ─── Verification ───────────────────────────────────────────────────────────
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public' AND table_name IN ('users', 'profiles');
-- -- should return only 'users'
--
-- SELECT column_name FROM information_schema.columns
-- WHERE table_name = 'users' AND column_name IN ('employer', 'monthly_income', 'credit_score');
-- -- should return no rows