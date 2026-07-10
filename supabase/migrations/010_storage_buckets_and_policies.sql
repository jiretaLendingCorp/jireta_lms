-- supabase/migrations/010_storage_buckets_and_policies.sql
-- BUG FIX: Storage buckets were commented out in 002_rls_policies.sql.
-- This migration creates all required buckets and their RLS policies.

-- ─── 1. Storage Buckets ────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars',   'avatars',   true,  5242880,  ARRAY['image/jpeg','image/png','image/webp']),
  ('kyc-docs',  'kyc-docs',  false, 10485760, ARRAY['image/jpeg','image/png','image/webp','application/pdf']),
  ('receipts',  'receipts',  false, 10485760, ARRAY['image/jpeg','image/png','image/webp','application/pdf']),
  ('signatures','signatures',false, 5242880,  ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public             = EXCLUDED.public,
  file_size_limit    = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ─── 2. Storage RLS Policies ──────────────────────────────────────────────
-- avatars: public read, authenticated write own folder only
CREATE POLICY "Public read avatars"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated upload own avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = 'profiles'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

CREATE POLICY "Authenticated update own avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Service role can do anything in avatars (for Edge Function uploads)
CREATE POLICY "Service role full access avatars"
  ON storage.objects FOR ALL
  TO service_role
  USING (bucket_id = 'avatars')
  WITH CHECK (bucket_id = 'avatars');

-- kyc-docs: service role only (Edge Function manages uploads)
CREATE POLICY "Service role full access kyc-docs"
  ON storage.objects FOR ALL
  TO service_role
  USING (bucket_id = 'kyc-docs')
  WITH CHECK (bucket_id = 'kyc-docs');

CREATE POLICY "Owner can read own kyc-docs"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'kyc-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- receipts: service role full, rider can read own
CREATE POLICY "Service role full access receipts"
  ON storage.objects FOR ALL
  TO service_role
  USING (bucket_id = 'receipts')
  WITH CHECK (bucket_id = 'receipts');

CREATE POLICY "Rider can read own receipts"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- signatures: service role full
CREATE POLICY "Service role full access signatures"
  ON storage.objects FOR ALL
  TO service_role
  USING (bucket_id = 'signatures')
  WITH CHECK (bucket_id = 'signatures');

CREATE POLICY "Owner can read own signature"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'signatures'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );