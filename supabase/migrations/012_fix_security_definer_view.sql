-- supabase/migrations/012_fix_security_definer_view.sql
-- FIX: Remove SECURITY DEFINER from lender_loan_params view.
-- SECURITY DEFINER views bypass RLS of the querying user and run as the
-- view owner instead — this is flagged as a security risk.
-- Replacing with SECURITY INVOKER (the default) ensures the querying user's
-- own RLS policies apply when reading through the view.

-- Drop and recreate the view without SECURITY DEFINER.
-- The view body is preserved exactly; only the security property is changed.

DROP VIEW IF EXISTS public.lender_loan_params;

CREATE OR REPLACE VIEW public.lender_loan_params
  WITH (security_invoker = true)
AS
SELECT
  min_loan_amount,
  max_loan_amount,
  interest_rate,
  penalty_rate,
  penalty_grace_days
FROM system_settings
LIMIT 1;

-- Grant SELECT to authenticated users (needed for any direct use of the view).
GRANT SELECT ON public.lender_loan_params TO authenticated;
