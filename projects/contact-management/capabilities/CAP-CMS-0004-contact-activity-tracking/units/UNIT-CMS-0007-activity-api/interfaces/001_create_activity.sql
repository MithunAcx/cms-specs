-- UNIT-CMS-0007 — Activity API
-- Target: PostgreSQL 18 (per projects/contact-management/stack.md)
-- Forward-only migration. No destructive statement shares this migration with an
-- additive one (10-platform.md Storage).

-- Owns the polymorphic Activity entity (XD-0001 of CAP-CMS-0004's capability-design.md):
-- one table serves both agency activity and brokerage activity via parent_type/parent_id,
-- rather than two nullable FK columns as the legacy PP_TskData table did.

CREATE TABLE activity (
    id              uuid            NOT NULL DEFAULT gen_random_uuid(),  -- UUIDv7 per 10-platform.md; generation function is an engineering-repo concern
    tenant_id       uuid            NOT NULL,
    parent_type     text            NOT NULL,
    parent_id       uuid            NOT NULL,
    status_id       integer         NOT NULL,
    note            text            NOT NULL,
    follow_up_date  date            NOT NULL,
    entered_date    timestamptz     NOT NULL,   -- server-derived at creation (R3) — never accepted from a caller
    completed       boolean         NOT NULL DEFAULT false,
    completed_date  timestamptz     NULL,       -- server-set only when completed flips true (R7); server-cleared when it flips false (R8)
    user_name       text            NOT NULL,   -- server-derived from the authenticated caller (R2, XD-0003) — never accepted from a caller
    created_at      timestamptz     NOT NULL DEFAULT now(),
    updated_at      timestamptz     NOT NULL DEFAULT now(),
    deleted_at      timestamptz     NULL,       -- soft-delete marker (XD-0002); a non-null value means the row is logically deleted but is never physically removed

    CONSTRAINT pk_activity PRIMARY KEY (id),
    CONSTRAINT ck_activity_parent_type CHECK (parent_type IN ('agency', 'brokerage')),
    -- Invariant: a completed entry always has a non-null completed_date, and a
    -- non-completed entry always has a null one (design.md State machine). Enforced
    -- here, not left to application code, so a write that forgets to pair the two
    -- fields is rejected by the store rather than silently producing an inconsistent row.
    CONSTRAINT ck_activity_completed_date CHECK (
        (completed = false AND completed_date IS NULL)
        OR (completed = true AND completed_date IS NOT NULL)
    )
);

-- Index serving the follow-up/open-item sort (FR-ACT-5, requirements.md R4/R5): list
-- queries always filter by tenant_id + parent_type + parent_id, exclude deleted rows,
-- and sort by follow_up_date — this index covers exactly that access pattern.
CREATE INDEX ix_activity_parent_followup ON activity (tenant_id, parent_type, parent_id, follow_up_date)
    WHERE deleted_at IS NULL;

-- Index serving the completed/open filter (R5) alongside the same parent scope.
CREATE INDEX ix_activity_parent_completed ON activity (tenant_id, parent_type, parent_id, completed)
    WHERE deleted_at IS NULL;

-- Tenant isolation (10-platform.md Tenancy; requirements.md R21): enforced by the store
-- via row-level security, not by application-level WHERE clauses alone. Every operation,
-- including a read, is scoped to the caller's own tenant_id.
ALTER TABLE activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY activity_tenant_isolation ON activity
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
-- The session-variable mechanism used to set app.current_tenant_id per connection/request
-- is an engineering-repo concern (per stack.md's RLS choice); this contract only requires
-- that every session have it set before any query against this table executes.

COMMENT ON TABLE activity IS
    'Owned by UNIT-CMS-0007. Polymorphic activity/follow-up log against an agency or '
    'brokerage (opaque parent_id, owned by UNIT-CMS-0005). Soft-delete only — no '
    'application code path may issue a physical DELETE against this table (XD-0002, '
    'capability CAP-CMS-0004 non-goals).';

COMMENT ON COLUMN activity.deleted_at IS
    'Soft-delete marker (XD-0002). Non-null means logically deleted. No row is ever '
    'physically removed from this table.';

COMMENT ON COLUMN activity.note IS
    'Personal data by default (requirements.md R24) — never exposed in a log line, '
    'metric label, or error message. Erasure path: sever this field''s content in '
    'place (replace with a redaction marker) while retaining the row and its '
    'timestamps/user_name for audit continuity (requirements.md R25).';

-- Backfill of legacy PP_TskData rows into this schema is owned by CAP-CMS-0006
-- (Legacy Data Migration) and is a task there, not part of this migration
-- (requirements.md R26).
