-- supabase/migrations/002_rls_policies.sql
-- Jireta Loans & Credit Corp Inc. — Row Level Security Policies
-- Execute AFTER 001_initial_schema.sql via Supabase Dashboard > SQL Editor

-- ─── Helper: get current user role ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role IN ('head_manager', 'employee') FROM profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_head_manager()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role = 'head_manager' FROM profiles WHERE id = auth.uid()
$$;

-- ─── Enable RLS on all tables ─────────────────────────────────────────────────
ALTER TABLE profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_submissions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans               ENABLE ROW LEVEL SECURITY;
ALTER TABLE comakers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_schedules   ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_assignments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE fcm_tokens          ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods     ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs          ENABLE ROW LEVEL SECURITY;

-- ─── Profiles ─────────────────────────────────────────────────────────────────
-- All authenticated users can view their own profile
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

-- Staff can view all profiles
CREATE POLICY "profiles_select_staff"
  ON profiles FOR SELECT
  USING (is_staff());

-- Users can update only their own profile (non-sensitive fields via RLS;
-- sensitive ops go through Edge Functions with service role)
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Head managers can update any profile
CREATE POLICY "profiles_update_hm"
  ON profiles FOR UPDATE
  USING (is_head_manager());

-- Edge Functions (service role) bypass RLS — insert handled by trigger
-- Direct client insert disabled; Edge Function service role handles creation

-- ─── KYC Submissions ──────────────────────────────────────────────────────────
-- Lenders see only their own KYC
CREATE POLICY "kyc_select_own"
  ON kyc_submissions FOR SELECT
  USING (lender_id = auth.uid());

-- Staff see all KYC submissions
CREATE POLICY "kyc_select_staff"
  ON kyc_submissions FOR SELECT
  USING (is_staff());

-- Lenders can insert their own KYC (via Edge Function service role only in prod)
CREATE POLICY "kyc_insert_own"
  ON kyc_submissions FOR INSERT
  WITH CHECK (lender_id = auth.uid());

-- Staff can update KYC status
CREATE POLICY "kyc_update_staff"
  ON kyc_submissions FOR UPDATE
  USING (is_staff());

-- ─── Loans ────────────────────────────────────────────────────────────────────
-- Lenders see only their own loans
CREATE POLICY "loans_select_own"
  ON loans FOR SELECT
  USING (lender_id = auth.uid());

-- Staff see all loans
CREATE POLICY "loans_select_staff"
  ON loans FOR SELECT
  USING (is_staff());

-- Riders see loans linked to their active assignments
CREATE POLICY "loans_select_rider"
  ON loans FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rider_assignments ra
      WHERE ra.loan_id = loans.id
        AND ra.rider_id = auth.uid()
    )
  );

-- Only Edge Functions (service role) insert/update loans
-- No direct client INSERT/UPDATE permitted

-- ─── Comakers ─────────────────────────────────────────────────────────────────
-- Lenders see co-maker on their own loans
CREATE POLICY "comakers_select_own"
  ON comakers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM loans l
      WHERE l.id = comakers.loan_id AND l.lender_id = auth.uid()
    )
  );

-- Staff see all co-makers
CREATE POLICY "comakers_select_staff"
  ON comakers FOR SELECT
  USING (is_staff());

-- ─── Payment Schedules ────────────────────────────────────────────────────────
-- Lenders see schedule for their own loans
CREATE POLICY "schedules_select_own"
  ON payment_schedules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM loans l
      WHERE l.id = payment_schedules.loan_id AND l.lender_id = auth.uid()
    )
  );

-- Staff see all schedules
CREATE POLICY "schedules_select_staff"
  ON payment_schedules FOR SELECT
  USING (is_staff());

-- ─── Payments ─────────────────────────────────────────────────────────────────
-- Lenders see only their own payments
CREATE POLICY "payments_select_own"
  ON payments FOR SELECT
  USING (lender_id = auth.uid());

-- Staff see all payments
CREATE POLICY "payments_select_staff"
  ON payments FOR SELECT
  USING (is_staff());

-- ─── Rider Assignments ────────────────────────────────────────────────────────
-- Riders see only their own assignments
CREATE POLICY "assignments_select_rider"
  ON rider_assignments FOR SELECT
  USING (rider_id = auth.uid());

-- Lenders see assignments for their loans (status tracking only)
CREATE POLICY "assignments_select_lender"
  ON rider_assignments FOR SELECT
  USING (lender_id = auth.uid());

-- Staff see all assignments
CREATE POLICY "assignments_select_staff"
  ON rider_assignments FOR SELECT
  USING (is_staff());

-- ─── Notifications ────────────────────────────────────────────────────────────
-- Users see only their own notifications
CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

-- Users can mark their own notifications as read
CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ─── FCM Tokens ───────────────────────────────────────────────────────────────
CREATE POLICY "fcm_tokens_select_own"
  ON fcm_tokens FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "fcm_tokens_insert_own"
  ON fcm_tokens FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_tokens_update_own"
  ON fcm_tokens FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "fcm_tokens_delete_own"
  ON fcm_tokens FOR DELETE
  USING (user_id = auth.uid());

-- ─── System Settings ──────────────────────────────────────────────────────────
-- All authenticated users can read settings (min/max loan amounts etc.)
CREATE POLICY "system_settings_select_all"
  ON system_settings FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Only head managers can update via Edge Functions (service role bypasses RLS)
CREATE POLICY "system_settings_update_hm"
  ON system_settings FOR UPDATE
  USING (is_head_manager());

-- ─── Payment Methods ──────────────────────────────────────────────────────────
-- All authenticated users can read enabled payment methods
CREATE POLICY "payment_methods_select_all"
  ON payment_methods FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Only head managers can manage payment methods
CREATE POLICY "payment_methods_all_hm"
  ON payment_methods FOR ALL
  USING (is_head_manager());

-- ─── Audit Logs ───────────────────────────────────────────────────────────────
-- Only head managers can read audit logs
CREATE POLICY "audit_logs_select_hm"
  ON audit_logs FOR SELECT
  USING (is_head_manager());

-- Only service role (Edge Functions) can insert audit logs
-- Direct client insert is blocked by not having an INSERT policy for anon/auth roles
-- The immutable rules in 001_initial_schema.sql block UPDATE and DELETE

-- ─── Storage bucket policies ──────────────────────────────────────────────────
-- Create storage buckets (run separately in Supabase dashboard if not using CLI)
-- INSERT INTO storage.buckets (id, name, public) VALUES
--   ('avatars',       'avatars',       true),
--   ('kyc-documents', 'kyc-documents', false),
--   ('receipts',      'receipts',      false),
--   ('signatures',    'signatures',    false)
-- ON CONFLICT (id) DO NOTHING;

-- Avatar bucket: authenticated users upload/update their own avatar
-- (Configure via Supabase Dashboard > Storage > avatars > Policies)
-- Recommended policy: allow authenticated users to SELECT all, INSERT/UPDATE/DELETE own path

-- ─── Grant service role bypass (already default in Supabase) ─────────────────
-- The service role key used in Edge Functions bypasses all RLS automatically.
-- Never expose the service role key to any client.

-- ─── Verification query ───────────────────────────────────────────────────────
-- Run this to verify RLS is enabled:
-- SELECT tablename, rowsecurity FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;