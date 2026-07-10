
-- ─── Migration 008: Credit Investigation Assignment Type ──────────────────────
-- Adds assignment_type column to rider_assignments so riders can be assigned
-- for BOTH collection AND credit investigation visits.

ALTER TABLE rider_assignments
  ADD COLUMN IF NOT EXISTS assignment_type TEXT NOT NULL DEFAULT 'collection'
    CHECK (assignment_type IN ('collection', 'credit_investigation'));

-- Credit investigation specific columns
ALTER TABLE rider_assignments
  ADD COLUMN IF NOT EXISTS ci_document_url TEXT,
  ADD COLUMN IF NOT EXISTS ci_notes TEXT,
  ADD COLUMN IF NOT EXISTS ci_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ci_verified_by UUID REFERENCES users(id);

COMMENT ON COLUMN rider_assignments.assignment_type IS
  'collection = collect loan payment; credit_investigation = visit lender for CI and upload proof';
COMMENT ON COLUMN rider_assignments.ci_document_url IS
  'URL of the uploaded CI document/proof (stored in Supabase Storage via Edge Function)';
COMMENT ON COLUMN rider_assignments.ci_notes IS
  'Rider notes from credit investigation visit';

-- Index for filtering by type
CREATE INDEX IF NOT EXISTS idx_assignments_type ON rider_assignments(assignment_type);