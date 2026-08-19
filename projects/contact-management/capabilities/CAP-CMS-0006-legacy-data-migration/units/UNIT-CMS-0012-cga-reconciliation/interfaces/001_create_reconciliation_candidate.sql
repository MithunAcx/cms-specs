-- Target: PostgreSQL 18 (projects/contact-management/stack.md)
-- Unit: UNIT-CMS-0012 (CGA Reconciliation)
-- Forward-only migration. No destructive statement shares this migration with an
-- additive one (10-platform.md / 50-api-contracts.md).
--
-- Owns the ReconciliationCandidate entity from design.md's Data model section.
-- This is this unit's own tracking state for the discovery/reconciliation pass —
-- it is NOT the MigrationLog entity (owned solely by UNIT-CMS-0011, XD-0002) and
-- this unit never writes to that table directly.

-- Satisfies R8, R9, R10, R11, R12, R19: durable per-row processing state that
-- survives a crash and makes a re-run idempotent per legacy pp_agent row.
CREATE TABLE reconciliation_candidate (
    id                  uuid PRIMARY KEY,
    tenant_id           uuid NOT NULL,
    legacy_agent_id     text NOT NULL,
    status              text NOT NULL
                          CONSTRAINT reconciliation_candidate_status_check
                          CHECK (status IN ('pending', 'reconciled', 'skipped', 'flagged', 'failed')),
    resolution          text
                          CONSTRAINT reconciliation_candidate_resolution_check
                          CHECK (resolution IS NULL OR resolution IN ('is_cga', 'is_not_cga')),
    agency_id_new       uuid,
    cga_id              uuid,
    failure_reason      text,
    detected_at         timestamptz NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

-- Satisfies R8, R12, R19 (idempotency key): at most one candidate row per legacy
-- pp_agent row per tenant, enforced by the store rather than a check-then-insert
-- in application logic — this is what makes the idempotency walk in design.md
-- hold under a crash-and-retry, not only in the absence of one.
ALTER TABLE reconciliation_candidate
    ADD CONSTRAINT reconciliation_candidate_legacy_agent_unique
    UNIQUE (tenant_id, legacy_agent_id);

-- Satisfies R4, R10: candidates currently awaiting manual review.
CREATE INDEX reconciliation_candidate_status_idx
    ON reconciliation_candidate (tenant_id, status);

-- Satisfies R23 (tenant isolation): row-level security restricts every read and
-- write to the caller's own tenant, per stack.md's RLS mechanism — this is a
-- store-enforced guarantee, not an application-level filter, so a query that
-- forgets a WHERE clause still cannot cross a tenant boundary.
ALTER TABLE reconciliation_candidate ENABLE ROW LEVEL SECURITY;

CREATE POLICY reconciliation_candidate_tenant_isolation
    ON reconciliation_candidate
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- Satisfies R14, R20: at most one reconciliation run active at a time, enforced
-- by the store via an exclusivity constraint rather than an application-level
-- check-then-start (design.md § Concurrency matrix). A single active-run marker
-- row per tenant, guarded by the same unique constraint pattern.
CREATE TABLE reconciliation_run (
    id                  uuid PRIMARY KEY,
    tenant_id           uuid NOT NULL,
    status              text NOT NULL
                          CONSTRAINT reconciliation_run_status_check
                          CHECK (status IN ('running', 'completed', 'failed')),
    started_at          timestamptz NOT NULL,
    completed_at        timestamptz,
    evaluated_count     integer NOT NULL DEFAULT 0,
    reconciled_count    integer NOT NULL DEFAULT 0,
    flagged_count       integer NOT NULL DEFAULT 0,
    skipped_count       integer NOT NULL DEFAULT 0,
    failed_count        integer NOT NULL DEFAULT 0,
    logging_gap_count   integer NOT NULL DEFAULT 0,
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- Satisfies R14, R20: a unique partial index on (tenant_id) where status is
-- 'running' means the store itself rejects a second concurrent run for the same
-- tenant — the exclusivity is a storage-level constraint, not an application race.
CREATE UNIQUE INDEX reconciliation_run_one_active_per_tenant
    ON reconciliation_run (tenant_id)
    WHERE status = 'running';

ALTER TABLE reconciliation_run ENABLE ROW LEVEL SECURITY;

CREATE POLICY reconciliation_run_tenant_isolation
    ON reconciliation_run
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- No backfill: reconciliation_candidate and reconciliation_run are populated only
-- by this unit's own pass at cutover time, never by a historical data load.
