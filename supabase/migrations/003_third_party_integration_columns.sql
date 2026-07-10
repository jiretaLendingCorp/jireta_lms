-- supabase/migrations/003_third_party_integration_columns.sql
-- Adds columns required by the Xendit, Google Maps, and SMS OTP integrations.
-- Execute AFTER 001_initial_schema.sql and 002_rls_policies.sql.

-- ─── Payments: Xendit invoice tracking ────────────────────────────────────────
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS xendit_invoice_id  TEXT,
  ADD COLUMN IF NOT EXISTS xendit_external_id TEXT;

CREATE INDEX IF NOT EXISTS idx_payments_xendit_external_id ON payments(xendit_external_id);
CREATE INDEX IF NOT EXISTS idx_payments_reference_number ON payments(reference_number);

-- ─── Loans: Xendit disbursement tracking ──────────────────────────────────────
ALTER TABLE loans
  ADD COLUMN IF NOT EXISTS xendit_disbursement_id TEXT,
  ADD COLUMN IF NOT EXISTS disbursement_channel   TEXT;

-- ─── Payment Schedules: 2-day reminder de-duplication ─────────────────────────
ALTER TABLE payment_schedules
  ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_schedules_reminder ON payment_schedules(due_date, is_paid, reminder_sent_at);

-- ─── OTP Codes: SMS-based forgot-password flow ────────────────────────────────
CREATE TABLE IF NOT EXISTS otp_codes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  phone       TEXT NOT NULL,
  otp_code    TEXT NOT NULL,
  purpose     TEXT NOT NULL DEFAULT 'password_reset' CHECK (purpose IN ('password_reset', 'phone_verification')),
  is_used     BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_phone_code ON otp_codes(phone, otp_code);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON otp_codes(expires_at);

ALTER TABLE otp_codes ENABLE ROW LEVEL SECURITY;
-- No client-side policies: only the Edge Function service role reads/writes this table.

-- Auto-cleanup helper for expired/used OTPs (call periodically via cron if desired)
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM otp_codes
  WHERE expires_at < NOW() - INTERVAL '1 day'
     OR is_used = TRUE;
END;
$$;

-- ─── FCM Tokens: allow multiple platforms per user without unique-token clash ──
-- (idx_fcm_tokens_user_platform already enforces one token per user+platform
--  from 001_initial_schema.sql; fcm-register upserts on that conflict target.)