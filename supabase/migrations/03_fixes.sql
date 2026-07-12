-- supabase/migrations/03_fixes.sql
-- Run after 01_schema.sql and 02_rls.sql
-- Changes:
--   1. Add lender_info table (was missing — breaks lender registration)
--   2. Drop duplicate address column from rider_info (3NF: address lives in users)
--   3. Add RLS policies for lender_info
--   4. Seed one head_manager auth account
--   5. Grant realtime on lender_info

-- =============================================================================
-- 1. CREATE lender_info TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.lender_info (
  id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID          NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  employer        TEXT,
  monthly_income  NUMERIC(12,2),
  birthday        DATE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_lender_info_user_id ON public.lender_info (user_id);

DROP TRIGGER IF EXISTS trg_updated_at ON public.lender_info;
CREATE TRIGGER trg_updated_at
  BEFORE UPDATE ON public.lender_info
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- 2. FIX 3NF — Drop duplicate address from rider_info
--    address is already on public.users; rider_info.address is redundant
-- =============================================================================

ALTER TABLE public.rider_info DROP COLUMN IF EXISTS address;

-- =============================================================================
-- 3. RLS FOR lender_info
-- =============================================================================

ALTER TABLE public.lender_info ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lender_info_service_role_full" ON public.lender_info;
DROP POLICY IF EXISTS "lender_info_select_own"        ON public.lender_info;
DROP POLICY IF EXISTS "lender_info_insert_own"        ON public.lender_info;
DROP POLICY IF EXISTS "lender_info_update_own"        ON public.lender_info;
DROP POLICY IF EXISTS "lender_info_select_staff"      ON public.lender_info;

CREATE POLICY "lender_info_service_role_full" ON public.lender_info
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "lender_info_select_own" ON public.lender_info
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "lender_info_insert_own" ON public.lender_info
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "lender_info_update_own" ON public.lender_info
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "lender_info_select_staff" ON public.lender_info
  FOR SELECT TO authenticated USING (public.is_staff());

-- =============================================================================
-- 4. SEED — Head Manager account
--    Email   : admin@jireta.com
--    Password: JiretaAdmin@2024   (change immediately after first login)
-- =============================================================================

DO $$
DECLARE
  v_uid  UUID := 'aaaaaaaa-0000-0000-0000-000000000001'::UUID;
  v_email TEXT := 'admin@jireta.com';
BEGIN
  -- Auth user (handle_new_user trigger fires → inserts into public.users)
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    raw_app_meta_data,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    is_super_admin,
    is_sso_user,
    is_anonymous,
    created_at,
    updated_at
  )
  VALUES (
    v_uid,
    '00000000-0000-0000-0000-000000000000'::UUID,
    'authenticated',
    'authenticated',
    v_email,
    crypt('JiretaAdmin@2024', gen_salt('bf', 10)),
    NOW(),
    jsonb_build_object(
      'first_name',           'Head',
      'last_name',            'Manager',
      'role',                 'head_manager',
      'force_password_change', false
    ),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '', '', '', '',
    FALSE, FALSE, FALSE,
    NOW(), NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES (
    v_uid,
    v_uid,
    jsonb_build_object('sub', v_uid::TEXT, 'email', v_email),
    'email',
    v_email,
    NOW(), NOW(), NOW()
  )
  ON CONFLICT DO NOTHING;

  UPDATE public.users
  SET
    role                 = 'head_manager',
    force_password_change = FALSE,
    is_active            = TRUE,
    updated_at           = NOW()
  WHERE id = v_uid;

END $$;

-- =============================================================================
-- 5. REALTIME — publish lender_info
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'lender_info'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.lender_info;
  END IF;
END $$;