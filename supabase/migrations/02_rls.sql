-- =============================================================================
-- Jireta Loans & Credit Corp Inc.
-- 02_rls.sql — Row Level Security
--   ENABLE RLS · Policies · Storage buckets & policies · Grants
--
-- Consolidates all RLS from migrations 002, 007, 009, 010, 011, 017.
-- Run AFTER 01_schema.sql.
-- Idempotent: every policy uses DROP IF EXISTS before CREATE.
-- =============================================================================

-- =============================================================================
-- ENABLE RLS ON ALL TABLES
-- =============================================================================

ALTER TABLE public.users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_submissions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comakers               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_schedules      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_assignments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disbursement_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fcm_tokens             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_info             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trigger_error_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_codes              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_rate_limits       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_term_tiers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lender_info            ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- POLICIES
-- Convention: service_role has full access to every table.
--             Authenticated users only get what is explicitly granted.
--             All policy names are drop-then-create to be idempotent.
-- =============================================================================

-- ─── users ───────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "users_service_role_full"  ON public.users;
DROP POLICY IF EXISTS "users_select_own"          ON public.users;
DROP POLICY IF EXISTS "users_select_staff"        ON public.users;
DROP POLICY IF EXISTS "users_update_own"          ON public.users;
DROP POLICY IF EXISTS "users_update_hm"           ON public.users;

CREATE POLICY "users_service_role_full" ON public.users
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "users_select_own" ON public.users
  FOR SELECT TO authenticated USING (id = auth.uid());

CREATE POLICY "users_select_staff" ON public.users
  FOR SELECT TO authenticated USING (public.is_staff());

CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY "users_update_hm" ON public.users
  FOR UPDATE TO authenticated USING (public.is_head_manager());

-- ─── kyc_submissions ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "kyc_service_role_full" ON public.kyc_submissions;
DROP POLICY IF EXISTS "kyc_select_own"        ON public.kyc_submissions;
DROP POLICY IF EXISTS "kyc_select_staff"      ON public.kyc_submissions;
DROP POLICY IF EXISTS "kyc_insert_own"        ON public.kyc_submissions;
DROP POLICY IF EXISTS "kyc_update_staff"      ON public.kyc_submissions;

CREATE POLICY "kyc_service_role_full" ON public.kyc_submissions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "kyc_select_own" ON public.kyc_submissions
  FOR SELECT TO authenticated USING (lender_id = auth.uid());

CREATE POLICY "kyc_select_staff" ON public.kyc_submissions
  FOR SELECT TO authenticated USING (public.is_staff());

CREATE POLICY "kyc_insert_own" ON public.kyc_submissions
  FOR INSERT TO authenticated WITH CHECK (lender_id = auth.uid());

CREATE POLICY "kyc_update_staff" ON public.kyc_submissions
  FOR UPDATE TO authenticated USING (public.is_staff());

-- ─── loans ───────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "loans_service_role_full" ON public.loans;
DROP POLICY IF EXISTS "loans_select_own"        ON public.loans;
DROP POLICY IF EXISTS "loans_select_staff"      ON public.loans;
DROP POLICY IF EXISTS "loans_select_rider"      ON public.loans;

CREATE POLICY "loans_service_role_full" ON public.loans
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "loans_select_own" ON public.loans
  FOR SELECT TO authenticated USING (lender_id = auth.uid());

CREATE POLICY "loans_select_staff" ON public.loans
  FOR SELECT TO authenticated USING (public.is_staff());

CREATE POLICY "loans_select_rider" ON public.loans
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.rider_assignments ra
      WHERE ra.loan_id = loans.id AND ra.rider_id = auth.uid()
    )
  );

-- ─── comakers ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "comakers_service_role_full" ON public.comakers;
DROP POLICY IF EXISTS "comakers_select_own"        ON public.comakers;
DROP POLICY IF EXISTS "comakers_select_staff"      ON public.comakers;

CREATE POLICY "comakers_service_role_full" ON public.comakers
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "comakers_select_own" ON public.comakers
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.loans l
      WHERE l.id = comakers.loan_id AND l.lender_id = auth.uid()
    )
  );

CREATE POLICY "comakers_select_staff" ON public.comakers
  FOR SELECT TO authenticated USING (public.is_staff());

-- ─── payment_schedules ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "schedules_service_role_full" ON public.payment_schedules;
DROP POLICY IF EXISTS "schedules_select_own"        ON public.payment_schedules;
DROP POLICY IF EXISTS "schedules_select_staff"      ON public.payment_schedules;

CREATE POLICY "schedules_service_role_full" ON public.payment_schedules
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "schedules_select_own" ON public.payment_schedules
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.loans l
      WHERE l.id = payment_schedules.loan_id AND l.lender_id = auth.uid()
    )
  );

CREATE POLICY "schedules_select_staff" ON public.payment_schedules
  FOR SELECT TO authenticated USING (public.is_staff());

-- ─── payment_methods ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "payment_methods_service_role_full" ON public.payment_methods;
DROP POLICY IF EXISTS "payment_methods_select_all"        ON public.payment_methods;
DROP POLICY IF EXISTS "payment_methods_manage_hm"         ON public.payment_methods;

CREATE POLICY "payment_methods_service_role_full" ON public.payment_methods
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "payment_methods_select_all" ON public.payment_methods
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

CREATE POLICY "payment_methods_manage_hm" ON public.payment_methods
  FOR ALL TO authenticated USING (public.is_head_manager());

-- ─── payments ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "payments_service_role_full" ON public.payments;
DROP POLICY IF EXISTS "payments_select_own"        ON public.payments;
DROP POLICY IF EXISTS "payments_select_staff"      ON public.payments;

CREATE POLICY "payments_service_role_full" ON public.payments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "payments_select_own" ON public.payments
  FOR SELECT TO authenticated USING (lender_id = auth.uid());

CREATE POLICY "payments_select_staff" ON public.payments
  FOR SELECT TO authenticated USING (public.is_staff());

-- ─── rider_assignments ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "assignments_service_role_full" ON public.rider_assignments;
DROP POLICY IF EXISTS "assignments_select_rider"      ON public.rider_assignments;
DROP POLICY IF EXISTS "assignments_select_lender"     ON public.rider_assignments;
DROP POLICY IF EXISTS "assignments_select_staff"      ON public.rider_assignments;
DROP POLICY IF EXISTS "assignments_manage_staff"      ON public.rider_assignments;

CREATE POLICY "assignments_service_role_full" ON public.rider_assignments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "assignments_select_rider" ON public.rider_assignments
  FOR SELECT TO authenticated USING (rider_id = auth.uid());

CREATE POLICY "assignments_select_lender" ON public.rider_assignments
  FOR SELECT TO authenticated USING (lender_id = auth.uid());

CREATE POLICY "assignments_select_staff" ON public.rider_assignments
  FOR SELECT TO authenticated USING (public.is_staff());

CREATE POLICY "assignments_manage_staff" ON public.rider_assignments
  FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

-- ─── disbursement_assignments ────────────────────────────────────────────────
DROP POLICY IF EXISTS "disb_assignments_service_role" ON public.disbursement_assignments;
DROP POLICY IF EXISTS "disb_assignments_staff_read"   ON public.disbursement_assignments;
DROP POLICY IF EXISTS "disb_assignments_rider_read"   ON public.disbursement_assignments;

CREATE POLICY "disb_assignments_service_role" ON public.disbursement_assignments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "disb_assignments_staff_read" ON public.disbursement_assignments
  FOR SELECT TO authenticated USING (public.is_staff());

CREATE POLICY "disb_assignments_rider_read" ON public.disbursement_assignments
  FOR SELECT TO authenticated USING (rider_id = auth.uid());

-- ─── notifications ───────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "notifications_service_role_full" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select_own"        ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_own"        ON public.notifications;

CREATE POLICY "notifications_service_role_full" ON public.notifications
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "notifications_select_own" ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "notifications_update_own" ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ─── fcm_tokens ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "fcm_service_role_full" ON public.fcm_tokens;
DROP POLICY IF EXISTS "fcm_select_own"        ON public.fcm_tokens;
DROP POLICY IF EXISTS "fcm_insert_own"        ON public.fcm_tokens;
DROP POLICY IF EXISTS "fcm_update_own"        ON public.fcm_tokens;
DROP POLICY IF EXISTS "fcm_delete_own"        ON public.fcm_tokens;

CREATE POLICY "fcm_service_role_full" ON public.fcm_tokens
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "fcm_select_own" ON public.fcm_tokens
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "fcm_insert_own" ON public.fcm_tokens
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_update_own" ON public.fcm_tokens
  FOR UPDATE TO authenticated USING (user_id = auth.uid());

CREATE POLICY "fcm_delete_own" ON public.fcm_tokens
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- ─── system_settings ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "settings_service_role_full" ON public.system_settings;
DROP POLICY IF EXISTS "settings_select_all"        ON public.system_settings;
DROP POLICY IF EXISTS "settings_update_hm"         ON public.system_settings;

CREATE POLICY "settings_service_role_full" ON public.system_settings
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "settings_select_all" ON public.system_settings
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

CREATE POLICY "settings_update_hm" ON public.system_settings
  FOR UPDATE TO authenticated USING (public.is_head_manager());

-- ─── audit_logs ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "audit_service_role_only" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_select_hm"         ON public.audit_logs;

CREATE POLICY "audit_service_role_only" ON public.audit_logs
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "audit_select_hm" ON public.audit_logs
  FOR SELECT TO authenticated USING (public.is_head_manager());

-- ─── reports ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "reports_service_role_full" ON public.reports;
DROP POLICY IF EXISTS "reports_staff_all"         ON public.reports;

CREATE POLICY "reports_service_role_full" ON public.reports
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "reports_staff_all" ON public.reports
  FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

-- ─── rider_info ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "rider_info_service_role_full" ON public.rider_info;
DROP POLICY IF EXISTS "rider_info_select_own"        ON public.rider_info;

CREATE POLICY "rider_info_service_role_full" ON public.rider_info
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "rider_info_select_own" ON public.rider_info
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- ─── trigger_error_logs ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "trigger_error_logs_select_hm" ON public.trigger_error_logs;

CREATE POLICY "trigger_error_logs_select_hm" ON public.trigger_error_logs
  FOR SELECT TO authenticated USING (public.is_head_manager());

-- ─── otp_codes ───────────────────────────────────────────────────────────────
-- Service role only — Edge Functions manage OTPs exclusively.
DROP POLICY IF EXISTS "otp_service_role_only" ON public.otp_codes;

CREATE POLICY "otp_service_role_only" ON public.otp_codes
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ─── auth_rate_limits ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "rate_limits_service_role_only" ON public.auth_rate_limits;

CREATE POLICY "rate_limits_service_role_only" ON public.auth_rate_limits
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ─── user_sessions ───────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sessions_service_role_full" ON public.user_sessions;
DROP POLICY IF EXISTS "sessions_select_own"        ON public.user_sessions;

CREATE POLICY "sessions_service_role_full" ON public.user_sessions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "sessions_select_own" ON public.user_sessions
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- ─── loan_term_tiers ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "tiers_service_role_all"      ON public.loan_term_tiers;
DROP POLICY IF EXISTS "tiers_authenticated_read"    ON public.loan_term_tiers;

CREATE POLICY "tiers_service_role_all" ON public.loan_term_tiers
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "tiers_authenticated_read" ON public.loan_term_tiers
  FOR SELECT TO authenticated USING (true);

-- =============================================================================
-- STORAGE BUCKETS & POLICIES
-- =============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars',    'avatars',    true,  5242880,
    ARRAY['image/jpeg','image/png','image/webp']),
  ('kyc-docs',   'kyc-docs',   false, 10485760,
    ARRAY['image/jpeg','image/png','image/webp','application/pdf']),
  ('receipts',   'receipts',   false, 10485760,
    ARRAY['image/jpeg','image/png','image/webp','application/pdf']),
  ('signatures', 'signatures', false, 5242880,
    ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public             = EXCLUDED.public,
  file_size_limit    = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- avatars bucket
DROP POLICY IF EXISTS "avatars_public_read"          ON storage.objects;
DROP POLICY IF EXISTS "avatars_authenticated_upload"  ON storage.objects;
DROP POLICY IF EXISTS "avatars_authenticated_update"  ON storage.objects;
DROP POLICY IF EXISTS "avatars_service_role_full"     ON storage.objects;

CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'avatars');

CREATE POLICY "avatars_authenticated_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = 'profiles'   -- storage folder name, not table
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

CREATE POLICY "avatars_authenticated_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars'
    AND (storage.foldername(name))[2] = auth.uid()::text);

CREATE POLICY "avatars_service_role_full" ON storage.objects
  FOR ALL TO service_role
  USING (bucket_id = 'avatars') WITH CHECK (bucket_id = 'avatars');

-- kyc-docs bucket (service role + owner read)
DROP POLICY IF EXISTS "kyc_docs_service_role_full" ON storage.objects;
DROP POLICY IF EXISTS "kyc_docs_owner_read"        ON storage.objects;

CREATE POLICY "kyc_docs_service_role_full" ON storage.objects
  FOR ALL TO service_role
  USING (bucket_id = 'kyc-docs') WITH CHECK (bucket_id = 'kyc-docs');

CREATE POLICY "kyc_docs_owner_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'kyc-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text);

-- receipts bucket
DROP POLICY IF EXISTS "receipts_service_role_full" ON storage.objects;
DROP POLICY IF EXISTS "receipts_rider_read"        ON storage.objects;

CREATE POLICY "receipts_service_role_full" ON storage.objects
  FOR ALL TO service_role
  USING (bucket_id = 'receipts') WITH CHECK (bucket_id = 'receipts');

CREATE POLICY "receipts_rider_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text);

-- signatures bucket
DROP POLICY IF EXISTS "signatures_service_role_full" ON storage.objects;
DROP POLICY IF EXISTS "signatures_owner_read"        ON storage.objects;

CREATE POLICY "signatures_service_role_full" ON storage.objects
  FOR ALL TO service_role
  USING (bucket_id = 'signatures') WITH CHECK (bucket_id = 'signatures');

CREATE POLICY "signatures_owner_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'signatures'
    AND (storage.foldername(name))[1] = auth.uid()::text);

-- ─── lender_info ─────────────────────────────────────────────────────────────
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

-- =============================================================================
-- GRANTS
-- =============================================================================

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