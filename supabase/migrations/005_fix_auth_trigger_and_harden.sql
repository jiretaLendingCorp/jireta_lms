-- supabase/migrations/005_fix_auth_trigger_and_harden.sql
-- Jireta Loans & Credit Corp Inc. — Fix "Database error creating new user"
-- + close out the profiles→users migration + harden triggers/RLS.
-- Execute AFTER 001–004 via Supabase Dashboard > SQL Editor.
--
-- WHY THIS MIGRATION EXISTS
-- ──────────────────────────
-- 004_rename_profiles_to_users_and_normalize.sql renamed `profiles` → `users`
-- at the DATABASE level and updated the trigger/helper functions to match —
-- but ~17 call sites across the Edge Functions layer (supabase/functions/**)
-- were still hardcoded to the old `profiles` table name. The single most
-- damaging one was `_shared/auth.ts`'s `requireAuth()`, which is called by
-- almost every protected endpoint — so once 004 was applied, every
-- authenticated API call in the app started failing with
-- "User profile not found" (403), and `user-create` was separately
-- duplicate-inserting into a table that no longer existed. Those Edge
-- Function files have been fixed directly (see the delivered zip).
--
-- Separately, the Supabase Dashboard's own "Create user" panel doesn't call
-- any Edge Function at all — it hits Auth's admin API directly, which only
-- fires the `on_auth_user_created` DB trigger. Any unhandled exception
-- inside that trigger makes GoTrue roll back the whole signup and report
-- the generic "Database error creating new user" you saw in the
-- screenshot. This migration makes that trigger defensive (it can never
-- block user creation again) and closes any remaining drift between
-- `profiles` and `users` idempotently, regardless of exactly how much of
-- 004 made it into the live database.
--
-- This script is SAFE TO RE-RUN — every step checks current state first.

-- ─── 1. Close out the profiles → users rename, if not already done ────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
    ALTER TABLE profiles RENAME TO users;
  END IF;
END $$;

-- Constraint / index names (cosmetic, but keeps \d users clean) — only
-- rename if the old name is still present.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_pkey') THEN
    ALTER TABLE users RENAME CONSTRAINT profiles_pkey TO users_pkey;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_email_key') THEN
    ALTER TABLE users RENAME CONSTRAINT profiles_email_key TO users_email_key;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_role_check') THEN
    ALTER TABLE users RENAME CONSTRAINT profiles_role_check TO users_role_check;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_profiles_role') THEN
    ALTER INDEX idx_profiles_role RENAME TO idx_users_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_profiles_email') THEN
    ALTER INDEX idx_profiles_email RENAME TO idx_users_email;
  END IF;
END $$;

-- Dead/redundant PII columns (safe no-op if 004 already dropped these).
ALTER TABLE users
  DROP COLUMN IF EXISTS employer,
  DROP COLUMN IF EXISTS monthly_income,
  DROP COLUMN IF EXISTS credit_score;

-- RLS policy names — only rename if still on the old name.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'profiles_select_own') THEN
    ALTER POLICY "profiles_select_own" ON users RENAME TO "users_select_own";
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'profiles_select_staff') THEN
    ALTER POLICY "profiles_select_staff" ON users RENAME TO "users_select_staff";
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'profiles_update_own') THEN
    ALTER POLICY "profiles_update_own" ON users RENAME TO "users_update_own";
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'profiles_update_hm') THEN
    ALTER POLICY "profiles_update_hm" ON users RENAME TO "users_update_hm";
  END IF;
END $$;

-- ─── 2. loans.total_payable → GENERATED column (only if not already) ──────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'loans'
      AND column_name = 'total_payable' AND is_generated = 'ALWAYS'
  ) THEN
    ALTER TABLE loans DROP COLUMN IF EXISTS total_payable;
    ALTER TABLE loans
      ADD COLUMN total_payable NUMERIC(12, 2)
      GENERATED ALWAYS AS (principal_amount + interest_amount) STORED;
  END IF;
END $$;

-- ─── 3. payments.method → FK into payment_methods (only if not already) ───
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payments_method_fkey') THEN
    ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_method_check;
    ALTER TABLE payments
      ADD CONSTRAINT payments_method_fkey
      FOREIGN KEY (method) REFERENCES payment_methods(method);
  END IF;
END $$;

-- ─── 4. Helper functions — recreate against `users`, harden search_path ───
-- SET search_path pins these SECURITY DEFINER functions to the public
-- schema so they can't be hijacked by a session-level search_path change.
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT role FROM users WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT role IN ('head_manager', 'employee') FROM users WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_head_manager()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT role = 'head_manager' FROM users WHERE id = auth.uid()
$$;

-- ─── 5. Trigger error log — visibility for anything the trigger swallows ──
CREATE TABLE IF NOT EXISTS trigger_error_logs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trigger_name  TEXT NOT NULL,
  error_message TEXT NOT NULL,
  error_detail  TEXT,
  context_id    UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE trigger_error_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trigger_error_logs_select_hm" ON trigger_error_logs;
CREATE POLICY "trigger_error_logs_select_hm"
  ON trigger_error_logs FOR SELECT
  USING (is_head_manager());
-- No INSERT policy for anon/authenticated — only the SECURITY DEFINER
-- trigger function (which bypasses RLS as its owner) writes here.

-- ─── 6. handle_new_user() — now defensive: can NEVER block user creation ──
-- This is the actual fix for "Database error creating new user". Any
-- exception (bad/missing metadata, a stale unique-email conflict, a future
-- schema change we forget to mirror here, etc.) is now caught and logged
-- to trigger_error_logs instead of aborting the auth.users INSERT that
-- GoTrue is trying to perform.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  BEGIN
    INSERT INTO users (id, email, first_name, last_name, role, force_password_change)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), split_part(NEW.email, '@', 1)),
      COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
      COALESCE(NEW.raw_user_meta_data->>'role', 'lender'),
      FALSE
    )
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO trigger_error_logs (trigger_name, error_message, error_detail, context_id)
    VALUES ('handle_new_user', SQLERRM, SQLSTATE, NEW.id);
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── Diagnostics — run these manually if anything still looks off ─────────
--
-- 1) Confirm only `users` exists (not `profiles`):
--   SELECT table_name FROM information_schema.tables
--   WHERE table_schema = 'public' AND table_name IN ('users', 'profiles');
--
-- 2) List every trigger on auth.users (should be exactly one row,
--    on_auth_user_created — if you see a second, older trigger left over
--    from earlier iterations, DROP TRIGGER IF EXISTS <name> ON auth.users;):
--   SELECT tgname, tgenabled FROM pg_trigger
--   WHERE tgrelid = 'auth.users'::regclass AND NOT tgisinternal;
--
-- 3) Check whether any signup attempts have been silently logged since
--    this migration was applied (should be empty in normal operation):
--   SELECT * FROM trigger_error_logs ORDER BY created_at DESC LIMIT 20;
--
-- 4) If "hd@gmail.com" specifically still won't create, check for a
--    leftover row with that email (can happen from earlier failed manual
--    testing) — this is the one case the trigger's ON CONFLICT DO NOTHING
--    can't fix, since the conflict there is on id, not email:
--   SELECT id, email, role, created_at FROM users WHERE email = 'hd@gmail.com';
--   -- If a row exists with no matching auth.users id, it's an orphan —
--   -- confirm via: SELECT id FROM auth.users WHERE email = 'hd@gmail.com';
--   -- then DELETE FROM users WHERE email = 'hd@gmail.com' AND id NOT IN
--   --   (SELECT id FROM auth.users);