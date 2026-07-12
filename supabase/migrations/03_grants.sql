-- supabase/migrations/03_grants.sql
-- Run AFTER 01_schema.sql and 02_rls.sql.
-- Idempotent. Fixes: permission denied for schema public on service_role.
-- Safe to re-run on any existing deployment.

CREATE TABLE IF NOT EXISTS public.lender_info (
  id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID          NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  employer       TEXT,
  monthly_income NUMERIC(12,2),
  birthday       DATE,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_lender_info_user_id ON public.lender_info (user_id);

ALTER TABLE public.lender_info ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lender_info_service_role_full" ON public.lender_info;
DROP POLICY IF EXISTS "lender_info_select_own"        ON public.lender_info;
DROP POLICY IF EXISTS "lender_info_select_staff"      ON public.lender_info;
DROP POLICY IF EXISTS "lender_info_update_own"        ON public.lender_info;

CREATE POLICY "lender_info_service_role_full" ON public.lender_info
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "lender_info_select_own" ON public.lender_info
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "lender_info_select_staff" ON public.lender_info
  FOR SELECT TO authenticated USING (public.is_staff());

CREATE POLICY "lender_info_update_own" ON public.lender_info
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_updated_at'
      AND tgrelid = 'public.lender_info'::regclass
  ) THEN
    EXECUTE 'CREATE TRIGGER trg_updated_at BEFORE UPDATE ON public.lender_info
             FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()';
  END IF;
END;
$$;

GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;

GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, service_role, authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO service_role, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

GRANT SELECT ON public.lender_loan_params TO authenticated;