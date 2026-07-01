-- supabase/migrations/001_initial_schema.sql
-- Jireta Loans & Credit Corp Inc. — Full Database Schema
-- Execute via Supabase Dashboard > SQL Editor

-- ─── Extensions ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── Profiles ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id                    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                 TEXT NOT NULL UNIQUE,
  first_name            TEXT NOT NULL,
  last_name             TEXT NOT NULL,
  middle_name           TEXT,
  phone                 TEXT,
  address               TEXT,
  avatar_url            TEXT,
  role                  TEXT NOT NULL CHECK (role IN ('head_manager', 'employee', 'rider', 'lender')),
  force_password_change BOOLEAN NOT NULL DEFAULT FALSE,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  employer              TEXT,
  monthly_income        NUMERIC(12, 2),
  credit_score          NUMERIC(5, 2),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- ─── Auto-create profile on auth signup (lender self-register) ────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO profiles (id, email, first_name, last_name, role, force_password_change)
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── KYC Submissions ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kyc_submissions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lender_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status                TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
  id_type               TEXT NOT NULL,
  id_number_encrypted   TEXT NOT NULL,
  id_front_url          TEXT,
  id_back_url           TEXT,
  selfie_url            TEXT,
  employer_encrypted    TEXT,
  monthly_income        NUMERIC(12, 2),
  rejection_reason      TEXT,
  reviewed_by_id        UUID REFERENCES profiles(id),
  reviewed_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_kyc_lender_id ON kyc_submissions(lender_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status ON kyc_submissions(status);

-- ─── Loans ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS loans (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lender_id           UUID NOT NULL REFERENCES profiles(id),
  principal_amount    NUMERIC(12, 2) NOT NULL CHECK (principal_amount >= 3000 AND principal_amount <= 500000),
  interest_amount     NUMERIC(12, 2) NOT NULL,
  total_payable       NUMERIC(12, 2) NOT NULL,
  outstanding_balance NUMERIC(12, 2) NOT NULL,
  penalty_amount      NUMERIC(12, 2) NOT NULL DEFAULT 0,
  has_penalty         BOOLEAN NOT NULL DEFAULT FALSE,
  days_overdue        INTEGER,
  status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'under_review', 'approved', 'active', 'completed', 'rejected', 'defaulted')),
  preferred_frequency TEXT CHECK (preferred_frequency IN ('daily', 'weekly', 'monthly')),
  payment_frequency   TEXT CHECK (payment_frequency IN ('daily', 'weekly', 'monthly')),
  term_days           INTEGER CHECK (term_days > 0 AND term_days <= 365),
  installment_amount  NUMERIC(12, 2),
  purpose             TEXT,
  rejection_reason    TEXT,
  approved_by_id      UUID REFERENCES profiles(id),
  disbursed_by_id     UUID REFERENCES profiles(id),
  approved_at         TIMESTAMPTZ,
  disbursed_at        TIMESTAMPTZ,
  maturity_date       TIMESTAMPTZ,
  closed_at           TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_loans_lender_id ON loans(lender_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_loans_maturity ON loans(maturity_date);

-- ─── Co-makers ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comakers (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id                 UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  first_name_encrypted    TEXT NOT NULL,
  last_name_encrypted     TEXT NOT NULL,
  middle_name_encrypted   TEXT,
  relationship            TEXT NOT NULL,
  signature_url           TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comakers_loan_id ON comakers(loan_id);

-- ─── Payment Schedules ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_schedules (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id             UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  installment_number  INTEGER NOT NULL,
  amount_due          NUMERIC(12, 2) NOT NULL,
  amount_paid         NUMERIC(12, 2) NOT NULL DEFAULT 0,
  due_date            DATE NOT NULL,
  paid_at             TIMESTAMPTZ,
  is_paid             BOOLEAN NOT NULL DEFAULT FALSE,
  is_overdue          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_schedules_loan_id ON payment_schedules(loan_id);
CREATE INDEX IF NOT EXISTS idx_schedules_due_date ON payment_schedules(due_date);

-- ─── Payments ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id             UUID NOT NULL REFERENCES loans(id),
  lender_id           UUID NOT NULL REFERENCES profiles(id),
  amount              NUMERIC(12, 2) NOT NULL,
  method              TEXT NOT NULL CHECK (method IN ('gcash', 'maya', 'qr', 'cash', 'bank_transfer', 'office')),
  status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'verified', 'rejected', 'reversed')),
  reference_number    TEXT,
  receipt_url         TEXT,
  notes               TEXT,
  rejection_reason    TEXT,
  verified_by_id      UUID REFERENCES profiles(id),
  xendit_payment_id   TEXT,
  verified_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_loan_id ON payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_payments_lender_id ON payments(lender_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- ─── Rider Assignments ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rider_assignments (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id               UUID NOT NULL REFERENCES loans(id),
  rider_id              UUID NOT NULL REFERENCES profiles(id),
  lender_id             UUID NOT NULL REFERENCES profiles(id),
  payment_id            UUID REFERENCES payments(id),
  amount_to_collect     NUMERIC(12, 2) NOT NULL,
  amount_collected      NUMERIC(12, 2),
  status                TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'cancelled')),
  collection_date       DATE NOT NULL,
  lender_address        TEXT,
  lender_lat            NUMERIC(10, 7),
  lender_lng            NUMERIC(10, 7),
  notes                 TEXT,
  receipt_url           TEXT,
  failure_reason        TEXT,
  cancellation_reason   TEXT,
  created_by            UUID REFERENCES profiles(id),
  completed_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_assignments_rider_id ON rider_assignments(rider_id);
CREATE INDEX IF NOT EXISTS idx_assignments_lender_id ON rider_assignments(lender_id);
CREATE INDEX IF NOT EXISTS idx_assignments_status ON rider_assignments(status);
CREATE INDEX IF NOT EXISTS idx_assignments_collection_date ON rider_assignments(collection_date);

-- ─── Notifications ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  category      TEXT NOT NULL DEFAULT 'general',
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  reference_id  UUID,
  metadata      JSONB,
  read_at       TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- ─── FCM Push Tokens ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token       TEXT NOT NULL UNIQUE,
  platform    TEXT CHECK (platform IN ('android', 'ios', 'web')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fcm_tokens_user_platform ON fcm_tokens(user_id, platform);

-- ─── System Settings ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS system_settings (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  min_loan_amount     NUMERIC(12, 2) NOT NULL DEFAULT 3000,
  max_loan_amount     NUMERIC(12, 2) NOT NULL DEFAULT 500000,
  interest_rate       NUMERIC(5, 4) NOT NULL DEFAULT 0.20,
  penalty_rate        NUMERIC(5, 4) NOT NULL DEFAULT 0.20,
  penalty_grace_days  INTEGER NOT NULL DEFAULT 30,
  updated_at          TIMESTAMPTZ,
  updated_by          UUID REFERENCES profiles(id)
);

INSERT INTO system_settings (min_loan_amount, max_loan_amount, interest_rate, penalty_rate, penalty_grace_days)
VALUES (3000, 500000, 0.20, 0.20, 30)
ON CONFLICT DO NOTHING;

-- ─── Payment Methods ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_methods (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  method        TEXT NOT NULL UNIQUE CHECK (method IN ('gcash', 'maya', 'qr', 'cash', 'bank_transfer', 'office')),
  display_name  TEXT NOT NULL,
  description   TEXT,
  is_enabled    BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO payment_methods (method, display_name, description, is_enabled, sort_order) VALUES
  ('gcash',         'GCash',            'Pay via GCash through Xendit',           TRUE,  0),
  ('maya',          'Maya',             'Pay via Maya through Xendit',            TRUE,  1),
  ('qr',            'QR Payment',       'Scan QR code with GCash or Maya',        TRUE,  2),
  ('cash',          'Cash on Pickup',   'Rider collects cash at your location',   TRUE,  3),
  ('bank_transfer', 'Bank Transfer',    'Transfer to our bank account',           FALSE, 4),
  ('office',        'Office Pickup',    'Pay at our office',                      FALSE, 5)
ON CONFLICT (method) DO NOTHING;

-- ─── Audit Logs ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id),
  action      TEXT NOT NULL,
  table_name  TEXT NOT NULL,
  record_id   UUID,
  old_values  JSONB,
  new_values  JSONB,
  ip_address  INET,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_table_name ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs(created_at DESC);

-- Immutable: prevent UPDATE and DELETE on audit_logs
CREATE OR REPLACE RULE no_update_audit AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
CREATE OR REPLACE RULE no_delete_audit AS ON DELETE TO audit_logs DO INSTEAD NOTHING;

-- ─── Overdue schedule updater (runs via pg_cron or manual trigger) ─────────────
CREATE OR REPLACE FUNCTION update_overdue_schedules()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE payment_schedules
  SET is_overdue = TRUE
  WHERE is_paid = FALSE
    AND due_date < CURRENT_DATE
    AND is_overdue = FALSE;
END;
$$;