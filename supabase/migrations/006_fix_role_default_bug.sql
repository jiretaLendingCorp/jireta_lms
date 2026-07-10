-- supabase/migrations/006_fix_role_default_bug.sql
-- Jireta Loans & Credit Corp Inc. -- Fix "every new user becomes a lender"
-- Execute AFTER 001-005 via Supabase Dashboard > SQL Editor.
--
-- ROOT CAUSE
-- ----------
-- handle_new_user() (see 005) inserted new `users` rows with:
--   COALESCE(NEW.raw_user_meta_data->>'role', 'lender')
-- Any signup where raw_user_meta_data.role was missing/null therefore
-- silently became 'lender' -- with no error, no log, nothing. This affected
-- every role (head_manager, employee, rider), not just genuine lender
-- signups, whenever role was absent from the metadata at insert time.
--
-- FIX
-- ---
-- Remove the fallback. If role is missing, the trigger logs a detailed
-- row to trigger_error_logs (auditable by head managers) and re-raises,
-- which aborts the auth.users insert -- the account is never created in
-- a mislabeled state. Callers (user-create Edge Function, client-side
-- self-registration) are responsible for always sending role explicitly;
-- both already do this, so this only changes behavior for the broken
-- case where role silently went missing.
--
-- This script is SAFE TO RE-RUN.

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := NEW.raw_user_meta_data->>'role';

  IF v_role IS NULL OR TRIM(v_role) = '' THEN
    INSERT INTO trigger_error_logs (trigger_name, error_message, error_detail, context_id)
    VALUES (
      'handle_new_user',
      'Rejected: role missing from raw_user_meta_data at signup',
      NEW.raw_user_meta_data::TEXT,
      NEW.id
    );
    RAISE EXCEPTION 'role is required in user_metadata for account creation';
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
      COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
      v_role,
      COALESCE((NEW.raw_user_meta_data->>'force_password_change')::BOOLEAN, FALSE)
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

-- --- Diagnostics ----------------------------------------------------------
--
-- 1) Find every user that was silently mislabeled 'lender' by the old bug.
--    Review each manually against your real records before fixing:
--   SELECT id, email, first_name, last_name, role, created_at
--   FROM users WHERE role = 'lender' ORDER BY created_at;
--
-- 2) Once you've confirmed which rows are genuinely wrong, an admin
--    (head manager, via SQL editor -- this is a one-time manual data
--    repair, NOT something the app should ever do automatically) can fix
--    a specific account:
--   UPDATE users SET role = 'employee' WHERE id = '<uuid-of-affected-user>';
--
-- 3) Check trigger_error_logs for any signups that are now correctly
--    being rejected instead of silently mislabeled:
--   SELECT * FROM trigger_error_logs ORDER BY created_at DESC LIMIT 20;