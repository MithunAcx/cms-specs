-- UNIT-CMS-0011 — Legacy Data ETL
-- Target: PostgreSQL 18 (projects/contact-management/stack.md)
--
-- Forward-only migration 0002. Creates `migration_log` — the shared entity
-- CAP-CMS-0006's capability design (XD-0002) fixes as owned and solely written
-- by UNIT-CMS-0011, with UNIT-CMS-0011 also exposing the write path
-- UNIT-CMS-0012 uses to record its own outcomes (never by writing this table
-- through any other path). See UNIT-CMS-0011/decisions/ADR-0001 for why this is
-- a shared storage contract rather than a network API between the two units.
--
-- Append-only by design (requirements.md R20 — this table is this unit's own
-- audit record): no `updated_at` column, and no UPDATE or DELETE grant is ever
-- issued against it from either unit's write path.
--
-- No destructive statement shares this migration with an additive one.

CREATE TYPE migration_log_outcome AS ENUM ('migrated', 'skipped', 'failed');

CREATE TYPE migration_log_processed_by AS ENUM ('legacy-data-etl', 'cga-reconciliation');

CREATE TABLE migration_log (
    id              uuid                        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       uuid                        NOT NULL,
    source_table    text                        NOT NULL,
    source_id       text                        NOT NULL,
    outcome         migration_log_outcome       NOT NULL,
    -- Closed set of reason codes (design.md, Cross-cutting § error model). Never
    -- free text that could carry personal data (requirements.md R22).
    reason          text,
    -- Resolves the newly-created target-schema record's id, so a later phase
    -- can look up a parent's new id here rather than re-querying the target
    -- schema by legacy key. Additive to the fields CAP-CMS-0006's capability
    -- design fixed as shared (design.md, Data model) — nullable because a
    -- `skipped`/`failed` outcome has no target record to point at.
    target_id       text,
    processed_by    migration_log_processed_by NOT NULL,
    processed_at    timestamptz                NOT NULL DEFAULT now(),
    CONSTRAINT pk_migration_log PRIMARY KEY (id),
    -- Enforces "exactly one MigrationLog row per source record" (requirements.md
    -- R9) and is the storage-level idempotency/concurrency guarantee design.md's
    -- "State and idempotency" and "Concurrency matrix" sections rely on — a
    -- second insert attempt for the same (tenant_id, source_table, source_id) is
    -- rejected by the store, never merely discouraged by application logic.
    CONSTRAINT uq_migration_log_source UNIQUE (tenant_id, source_table, source_id),
    CONSTRAINT chk_migration_log_reason_required CHECK (
        (outcome = 'migrated') OR (reason IS NOT NULL)
    ),
    CONSTRAINT chk_migration_log_target_id_only_when_migrated CHECK (
        (outcome = 'migrated' AND target_id IS NOT NULL)
        OR (outcome <> 'migrated' AND target_id IS NULL)
    )
);

COMMENT ON TABLE migration_log IS
    'Sole record of every migration outcome across UNIT-CMS-0011 and
     UNIT-CMS-0012 (XD-0002). UNIT-CMS-0011 is the only writer of this table;
     UNIT-CMS-0012 records outcomes only via the write path UNIT-CMS-0011
     exposes (ADR-0001), never a direct write of its own against this schema.
     Satisfies R9, R10, R15, R20.';

CREATE INDEX ix_migration_log_source_table ON migration_log (tenant_id, source_table);

ALTER TABLE migration_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_migration_log ON migration_log
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
