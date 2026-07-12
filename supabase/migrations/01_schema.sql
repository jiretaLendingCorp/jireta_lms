-- =============================================================================
-- Jireta Loans & Credit Corp Inc.
-- 01_schema.sql — Authoritative DDL
--   Tables · Indexes · Functions · Triggers · Views · Seed data
--
-- Consolidates migrations 001–017.
-- Safe to run on a blank database. All objects use IF NOT EXISTS / OR REPLACE.
-- Run this file first, then 02_rls.sql.
-- =============================================================================

-- ─── Extensions ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- TABLES  (dependency order — parent tables before child tables)
-- =============================================================================

-- ─── users ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id                    UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                 TEXT        NOT NULL UNIQUE,
  first_name            TEXT        NOT NULL,
  last_name             TEXT        NOT NULL,
  middle_name           TEXT,
  phone                 TEXT,
  address               TEXT,
  avatar_url            TEXT,
  role                  TEXT        NOT NULL
                          CHECK (role IN ('head_manager','employee','rider','lender')),
  force_password_change BOOLEAN     NOT NULL DEFAULT FALSE,
  is_active             BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_role                ON public.users (role);
CREATE INDEX IF NOT EXISTS idx_users_email               ON public.users (email);
CREATE INDEX IF NOT EXISTS idx_users_force_pw_change     ON public.users (force_password_change)
  WHERE force_password_change = TRUE;

-- ─── trigger_error_logs ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.trigger_error_logs (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  trigger_name  TEXT        NOT NULL,
  error_message TEXT        NOT NULL,
  error_detail  TEXT,
  context_id    UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── loan_term_tiers ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.loan_term_tiers (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  tier_label          TEXT        NOT NULL UNIQUE,
  min_amount          NUMERIC(12,2) NOT NULL,
  max_amount          NUMERIC(12,2) NOT NULL,
  term_days           INTEGER     NOT NULL CHECK (term_days > 0),
  interest_rate       NUMERIC(5,4) NOT NULL DEFAULT 0.20
                        CHECK (interest_rate >= 0 AND interest_rate <= 1),
  penalty_rate        NUMERIC(5,4) NOT NULL DEFAULT 0.20
                        CHECK (penalty_rate >= 0 AND penalty_rate <= 1),
  penalty_grace_days  INTEGER     NOT NULL DEFAULT 30 CHECK (penalty_grace_days >= 0),
  is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ,
  CONSTRAINT chk_tier_amount_range CHECK (max_amount > min_amount)
);

CREATE INDEX IF NOT EXISTS idx_loan_term_tiers_active
  ON public.loan_term_tiers (is_active) WHERE is_active = TRUE;

-- ─── kyc_submissions ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.kyc_submissions (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  lender_id            UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status               TEXT        NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending','under_review','approved','rejected')),
  id_type              TEXT        NOT NULL,
  id_number_encrypted  TEXT        NOT NULL,
  id_front_url         TEXT,
  id_back_url          TEXT,
  selfie_url           TEXT,
  employer_encrypted   TEXT,
  monthly_income       NUMERIC(12,2),
  rejection_reason     TEXT,
  reviewed_by_id       UUID        REFERENCES public.users(id),
  reviewed_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_kyc_lender_id ON public.kyc_submissions (lender_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status    ON public.kyc_submissions (status);

-- ─── loans ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.loans (
  id                    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  lender_id             UUID        NOT NULL REFERENCES public.users(id),
  principal_amount      NUMERIC(12,2) NOT NULL
                          CHECK (principal_amount >= 3000 AND principal_amount <= 500000),
  interest_amount       NUMERIC(12,2) NOT NULL CHECK (interest_amount >= 0),
  total_payable         NUMERIC(12,2)
                          GENERATED ALWAYS AS (principal_amount + interest_amount) STORED,
  outstanding_balance   NUMERIC(12,2) NOT NULL,
  penalty_amount        NUMERIC(12,2) NOT NULL DEFAULT 0,
  has_penalty           BOOLEAN     NOT NULL DEFAULT FALSE,
  days_overdue          INTEGER,
  status                TEXT        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','under_review','approved','active','completed','rejected','defaulted')),
  preferred_frequency   TEXT        CHECK (preferred_frequency IN ('daily','weekly','monthly')),
  payment_frequency     TEXT        CHECK (payment_frequency IN ('daily','weekly','monthly')),
  term_days             INTEGER     CHECK (term_days > 0 AND term_days <= 365),
  installment_amount    NUMERIC(12,2),
  purpose               TEXT,
  rejection_reason      TEXT,
  approved_by_id        UUID        REFERENCES public.users(id),
  disbursed_by_id       UUID        REFERENCES public.users(id),
  approved_at           TIMESTAMPTZ,
  disbursed_at          TIMESTAMPTZ,
  maturity_date         TIMESTAMPTZ,
  closed_at             TIMESTAMPTZ,
  xendit_disbursement_id TEXT,
  disbursement_channel  TEXT,
  disbursement_method   TEXT
                          CHECK (disbursement_method IN ('cash','gcash','office') OR disbursement_method IS NULL),
  disbursement_meta     JSONB,
  tier_label            TEXT        REFERENCES public.loan_term_tiers(tier_label)
                          ON UPDATE CASCADE ON DELETE RESTRICT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_loans_lender_id        ON public.loans (lender_id);
CREATE INDEX IF NOT EXISTS idx_loans_status           ON public.loans (status);
CREATE INDEX IF NOT EXISTS idx_loans_maturity         ON public.loans (maturity_date);
CREATE INDEX IF NOT EXISTS idx_loans_tier_label       ON public.loans (tier_label);
CREATE INDEX IF NOT EXISTS idx_loans_pending_review   ON public.loans (created_at DESC)
  WHERE status IN ('pending','under_review');
CREATE INDEX IF NOT EXISTS idx_loans_active_maturity  ON public.loans (maturity_date)
  WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_loans_disbursement_method ON public.loans (disbursement_method)
  WHERE disbursement_method IS NOT NULL;

-- ─── comakers ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.comakers (
  id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id                 UUID        NOT NULL REFERENCES public.loans(id) ON DELETE CASCADE,
  first_name_encrypted    TEXT        NOT NULL,
  last_name_encrypted     TEXT        NOT NULL,
  middle_name_encrypted   TEXT,
  relationship            TEXT        NOT NULL,
  signature_url           TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comakers_loan_id ON public.comakers (loan_id);

-- ─── payment_schedules ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payment_schedules (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id             UUID        NOT NULL REFERENCES public.loans(id) ON DELETE CASCADE,
  installment_number  INTEGER     NOT NULL,
  amount_due          NUMERIC(12,2) NOT NULL,
  amount_paid         NUMERIC(12,2) NOT NULL DEFAULT 0,
  due_date            DATE        NOT NULL,
  paid_at             TIMESTAMPTZ,
  is_paid             BOOLEAN     NOT NULL DEFAULT FALSE,
  is_overdue          BOOLEAN     NOT NULL DEFAULT FALSE,
  reminder_sent_at    TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_schedule_loan_installment UNIQUE (loan_id, installment_number)
);

CREATE INDEX IF NOT EXISTS idx_schedules_loan_id       ON public.payment_schedules (loan_id);
CREATE INDEX IF NOT EXISTS idx_schedules_due_date      ON public.payment_schedules (due_date);
CREATE INDEX IF NOT EXISTS idx_schedules_reminder      ON public.payment_schedules (due_date, is_paid, reminder_sent_at);
CREATE INDEX IF NOT EXISTS idx_payment_schedules_loan_paid
  ON public.payment_schedules (loan_id, is_paid);
CREATE INDEX IF NOT EXISTS idx_payment_schedules_due_date_unpaid
  ON public.payment_schedules (due_date) WHERE is_paid = FALSE;

-- ─── payment_methods ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  method        TEXT        NOT NULL UNIQUE
                  CHECK (method IN ('gcash','maya','qr','cash','bank_transfer','office')),
  display_name  TEXT        NOT NULL,
  description   TEXT,
  is_enabled    BOOLEAN     NOT NULL DEFAULT TRUE,
  sort_order    INTEGER     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── payments ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payments (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id             UUID        NOT NULL REFERENCES public.loans(id),
  lender_id           UUID        NOT NULL REFERENCES public.users(id),
  amount              NUMERIC(12,2) NOT NULL,
  method              TEXT        NOT NULL REFERENCES public.payment_methods(method),
  status              TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','verified','rejected','reversed')),
  reference_number    TEXT,
  receipt_url         TEXT,
  notes               TEXT,
  rejection_reason    TEXT,
  verified_by_id      UUID        REFERENCES public.users(id),
  xendit_payment_id   TEXT,
  xendit_invoice_id   TEXT,
  xendit_external_id  TEXT,
  verified_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_loan_id             ON public.payments (loan_id);
CREATE INDEX IF NOT EXISTS idx_payments_lender_id           ON public.payments (lender_id);
CREATE INDEX IF NOT EXISTS idx_payments_status              ON public.payments (status);
CREATE INDEX IF NOT EXISTS idx_payments_xendit_external_id  ON public.payments (xendit_external_id);
CREATE INDEX IF NOT EXISTS idx_payments_reference_number    ON public.payments (reference_number);

-- ─── rider_assignments ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rider_assignments (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id             UUID        NOT NULL REFERENCES public.loans(id),
  rider_id            UUID        NOT NULL REFERENCES public.users(id),
  lender_id           UUID        NOT NULL REFERENCES public.users(id),
  payment_id          UUID        REFERENCES public.payments(id),
  amount_to_collect   NUMERIC(12,2) NOT NULL,
  amount_collected    NUMERIC(12,2),
  status              TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','in_progress','completed','failed','cancelled')),
  collection_date     DATE        NOT NULL,
  lender_address      TEXT,
  lender_lat          NUMERIC(10,7),
  lender_lng          NUMERIC(10,7),
  notes               TEXT,
  receipt_url         TEXT,
  failure_reason      TEXT,
  cancellation_reason TEXT,
  created_by          UUID        REFERENCES public.users(id),
  completed_at        TIMESTAMPTZ,
  assignment_type     TEXT        NOT NULL DEFAULT 'collection'
                        CHECK (assignment_type IN ('collection','credit_investigation')),
  ci_document_url     TEXT,
  ci_notes            TEXT,
  ci_completed_at     TIMESTAMPTZ,
  ci_verified_by      UUID        REFERENCES public.users(id),
  kyc_id              UUID        REFERENCES public.kyc_submissions(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_assignments_rider_id       ON public.rider_assignments (rider_id);
CREATE INDEX IF NOT EXISTS idx_assignments_lender_id      ON public.rider_assignments (lender_id);
CREATE INDEX IF NOT EXISTS idx_assignments_loan_id        ON public.rider_assignments (loan_id);
CREATE INDEX IF NOT EXISTS idx_assignments_status         ON public.rider_assignments (status);
CREATE INDEX IF NOT EXISTS idx_assignments_collection_date ON public.rider_assignments (collection_date);
CREATE INDEX IF NOT EXISTS idx_assignments_type           ON public.rider_assignments (assignment_type);
CREATE INDEX IF NOT EXISTS idx_rider_assignments_kyc_id   ON public.rider_assignments (kyc_id)
  WHERE kyc_id IS NOT NULL;

-- ─── disbursement_assignments ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.disbursement_assignments (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id     UUID        NOT NULL UNIQUE REFERENCES public.loans(id) ON DELETE CASCADE,
  rider_id    UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  status      TEXT        NOT NULL DEFAULT 'pending_assignment'
                CHECK (status IN ('pending_assignment','assigned','delivered','failed')),
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_disb_assign_status ON public.disbursement_assignments (status);
CREATE INDEX IF NOT EXISTS idx_disb_assign_rider  ON public.disbursement_assignments (rider_id)
  WHERE rider_id IS NOT NULL;

-- ─── notifications ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title         TEXT        NOT NULL,
  body          TEXT        NOT NULL,
  category      TEXT        NOT NULL DEFAULT 'general',
  is_read       BOOLEAN     NOT NULL DEFAULT FALSE,
  reference_id  UUID,
  metadata      JSONB,
  read_at       TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications (user_id, is_read);

-- ─── fcm_tokens ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token       TEXT        NOT NULL UNIQUE,
  platform    TEXT        CHECK (platform IN ('android','ios','web')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fcm_tokens_user_platform
  ON public.fcm_tokens (user_id, platform);

-- ─── system_settings ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.system_settings (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  min_loan_amount     NUMERIC(12,2) NOT NULL DEFAULT 3000,
  max_loan_amount     NUMERIC(12,2) NOT NULL DEFAULT 500000,
  interest_rate       NUMERIC(5,4)  NOT NULL DEFAULT 0.20,
  penalty_rate        NUMERIC(5,4)  NOT NULL DEFAULT 0.20,
  penalty_grace_days  INTEGER       NOT NULL DEFAULT 30,
  updated_at          TIMESTAMPTZ,
  updated_by          UUID        REFERENCES public.users(id)
);

-- ─── otp_codes ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  phone       TEXT        NOT NULL,
  otp_code    TEXT        NOT NULL,
  purpose     TEXT        NOT NULL DEFAULT 'password_reset'
                CHECK (purpose IN ('password_reset','phone_verification')),
  is_used     BOOLEAN     NOT NULL DEFAULT FALSE,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_phone_code  ON public.otp_codes (phone, otp_code);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at  ON public.otp_codes (expires_at);

-- ─── audit_logs ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES public.users(id),
  action      TEXT        NOT NULL,
  table_name  TEXT        NOT NULL,
  record_id   UUID,
  old_values  JSONB,
  new_values  JSONB,
  ip_address  INET,
  user_agent  TEXT,
  actor_name  TEXT,
  actor_role  TEXT,
  description TEXT,
  approved_by TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user_id    ON public.audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_table_name ON public.audit_logs (table_name);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON public.audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_actor_name ON public.audit_logs (actor_name);
CREATE INDEX IF NOT EXISTS idx_audit_action     ON public.audit_logs (action);

-- ─── reports ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reports (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  generated_by  UUID        NOT NULL REFERENCES public.users(id),
  report_type   TEXT        NOT NULL
                  CHECK (report_type IN ('loans','payments','users','collections','overdue')),
  date_from     DATE,
  date_to       DATE,
  filters       JSONB,
  row_count     INTEGER     NOT NULL DEFAULT 0,
  report_data   JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_generated_by ON public.reports (generated_by);
CREATE INDEX IF NOT EXISTS idx_reports_created_at   ON public.reports (created_at DESC);

-- ─── rider_info ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rider_info (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID        NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  address         TEXT,
  driver_license  TEXT,
  vehicle_info    TEXT,
  birthday        DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_rider_info_user_id ON public.rider_info (user_id);

-- ─── auth_rate_limits ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  identifier  TEXT        NOT NULL,
  attempt_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  action      TEXT        NOT NULL DEFAULT 'login'
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_identifier
  ON public.auth_rate_limits (identifier, attempt_at);

-- ─── user_sessions ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  device_info   TEXT,
  ip_address    TEXT,
  logged_in_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  logged_out_at TIMESTAMPTZ,
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions (user_id);

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- ─── set_updated_at ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ─── get_my_role ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT role FROM public.users WHERE id = auth.uid()
$$;

-- ─── is_staff ────────────────────────────────────────────────────────────────
-- Returns TRUE for active head_manager or employee accounts only.
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND role IN ('head_manager','employee')
      AND is_active = TRUE
  )
$$;

-- ─── is_head_manager ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_head_manager()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT role = 'head_manager' FROM public.users WHERE id = auth.uid()
$$;

-- ─── handle_new_user (auth trigger) ─────────────────────────────────────────
-- Authoritative version. Role defaults to 'lender' when absent (self-register
-- and Supabase Dashboard admin creates). Staff accounts always send role
-- explicitly via the user-create Edge Function.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_role     TEXT;
  v_force_pw BOOLEAN;
BEGIN
  v_role     := NULLIF(TRIM(NEW.raw_user_meta_data->>'role'), '');
  v_force_pw := COALESCE((NEW.raw_user_meta_data->>'force_password_change')::BOOLEAN, FALSE);

  IF v_role IS NULL THEN
    v_role := 'lender';
  END IF;

  IF v_role NOT IN ('head_manager','employee','rider','lender') THEN
    INSERT INTO public.trigger_error_logs (trigger_name, error_message, error_detail, context_id)
    VALUES ('handle_new_user', 'Rejected: invalid role: ' || v_role,
            NEW.raw_user_meta_data::TEXT, NEW.id);
    RAISE EXCEPTION 'invalid role: %', v_role;
  END IF;

  BEGIN
    INSERT INTO public.users (id, email, first_name, last_name, role, force_password_change)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'),''), split_part(NEW.email,'@',1)),
      COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'),''), ''),
      v_role,
      v_force_pw
    )
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.trigger_error_logs (trigger_name, error_message, error_detail, context_id)
    VALUES ('handle_new_user', SQLERRM, SQLSTATE, NEW.id);
    RAISE;
  END;

  RETURN NEW;
END;
$$;

-- ─── admin_reset_user_password ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_reset_user_password(p_user_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE public.users
  SET force_password_change = TRUE, updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- ─── populate_audit_actor ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.populate_audit_actor()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_first TEXT;
  v_last  TEXT;
  v_role  TEXT;
BEGIN
  SELECT first_name, last_name, role
  INTO   v_first, v_last, v_role
  FROM   public.users WHERE id = NEW.user_id;

  NEW.actor_name := TRIM(CONCAT(COALESCE(v_first,''), ' ', COALESCE(v_last,'')));
  NEW.actor_role := v_role;

  IF NEW.description IS NULL THEN
    NEW.description := INITCAP(REPLACE(NEW.action,'_',' '))
      || ' on ' || REPLACE(NEW.table_name,'_',' ')
      || CASE WHEN NEW.record_id IS NOT NULL
              THEN ' (' || LEFT(NEW.record_id::TEXT, 8) || ')'
              ELSE '' END;
  END IF;

  RETURN NEW;
END;
$$;

-- ─── prevent_role_escalation ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Direct role changes are not permitted. Use the admin Edge Function.';
  END IF;
  RETURN NEW;
END;
$$;

-- ─── prevent_audit_mutation ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.prevent_audit_mutation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RAISE EXCEPTION 'Audit logs are immutable and cannot be modified or deleted.';
END;
$$;

-- ─── get_loan_tier ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_loan_tier(p_amount NUMERIC)
RETURNS public.loan_term_tiers
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT * FROM public.loan_term_tiers
  WHERE  is_active = TRUE
    AND  p_amount >= min_amount
    AND  p_amount <= max_amount
  ORDER BY min_amount ASC
  LIMIT 1;
$$;

-- ─── update_overdue_schedules ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_overdue_schedules()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.payment_schedules
  SET    is_overdue = TRUE
  WHERE  is_paid = FALSE
    AND  due_date < CURRENT_DATE
    AND  is_overdue = FALSE;
END;
$$;

-- ─── cleanup_expired_otps ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.otp_codes
  WHERE expires_at < NOW() - INTERVAL '1 day'
     OR is_used = TRUE;
END;
$$;

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Auth user created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Audit actor auto-populate
DROP TRIGGER IF EXISTS trg_audit_actor ON public.audit_logs;
CREATE TRIGGER trg_audit_actor
  BEFORE INSERT ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.populate_audit_actor();

-- Audit immutability
DROP TRIGGER IF EXISTS trg_audit_immutable_upd ON public.audit_logs;
CREATE TRIGGER trg_audit_immutable_upd
  BEFORE UPDATE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_mutation();

DROP TRIGGER IF EXISTS trg_audit_immutable_del ON public.audit_logs;
CREATE TRIGGER trg_audit_immutable_del
  BEFORE DELETE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_mutation();

-- Role escalation guard
DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON public.users;
CREATE TRIGGER trg_prevent_role_escalation
  BEFORE UPDATE OF role ON public.users
  FOR EACH ROW
  WHEN (pg_trigger_depth() = 0)
  EXECUTE FUNCTION public.prevent_role_escalation();

-- updated_at on all mutable tables
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users','loans','kyc_submissions','rider_assignments',
    'system_settings','payments','rider_info',
    'loan_term_tiers','disbursement_assignments','fcm_tokens'
  ]
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_updated_at ON public.%I;
       CREATE TRIGGER trg_updated_at BEFORE UPDATE ON public.%I
       FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();',
      t, t
    );
  END LOOP;
END;
$$;

-- =============================================================================
-- VIEWS
-- =============================================================================

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
FROM public.system_settings
LIMIT 1;

-- =============================================================================
-- SEED DATA
-- =============================================================================

INSERT INTO public.system_settings (min_loan_amount, max_loan_amount, interest_rate, penalty_rate, penalty_grace_days)
VALUES (3000, 500000, 0.20, 0.20, 30)
ON CONFLICT DO NOTHING;

INSERT INTO public.payment_methods (method, display_name, description, is_enabled, sort_order) VALUES
  ('gcash',         'GCash',          'Pay via GCash',                        TRUE,  0),
  ('maya',          'Maya',           'Pay via Maya',                         TRUE,  1),
  ('qr',            'QR Payment',     'Scan QR code with GCash or Maya',      TRUE,  2),
  ('cash',          'Cash on Pickup', 'Rider collects cash at your location', TRUE,  3),
  ('bank_transfer', 'Bank Transfer',  'Transfer to our bank account',         FALSE, 4),
  ('office',        'Office Pickup',  'Pay at our office',                    FALSE, 5)
ON CONFLICT (method) DO NOTHING;

INSERT INTO public.loan_term_tiers
  (tier_label, min_amount, max_amount, term_days, interest_rate, penalty_rate, penalty_grace_days, is_active)
VALUES
  ('micro',   3000.00,     9999.99,   40,  0.2000, 0.2000, 30, TRUE),
  ('small',   10000.00,   49999.99,   60,  0.2000, 0.2000, 30, TRUE),
  ('medium',  50000.00,   99999.99,   80,  0.2000, 0.2000, 30, TRUE),
  ('large',   100000.00, 500000.00,  120,  0.2000, 0.2000, 30, TRUE)
ON CONFLICT (tier_label) DO UPDATE SET
  min_amount         = EXCLUDED.min_amount,
  max_amount         = EXCLUDED.max_amount,
  term_days          = EXCLUDED.term_days,
  interest_rate      = EXCLUDED.interest_rate,
  penalty_rate       = EXCLUDED.penalty_rate,
  penalty_grace_days = EXCLUDED.penalty_grace_days,
  is_active          = TRUE,
  updated_at         = NOW();