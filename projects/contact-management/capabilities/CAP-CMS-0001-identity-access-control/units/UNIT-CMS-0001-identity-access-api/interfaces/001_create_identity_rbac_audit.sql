-- UNIT-CMS-0001 — Identity Access API
-- Target: PostgreSQL 18 (projects/contact-management/stack.md)
-- Forward-only migration. No destructive statement shares this file with an
-- additive one (50-api-contracts.md).
--
-- Tenant isolation: every table below carries tenant_id and a row-level
-- security policy scoped to it, per stack.md's RLS choice
-- (10-platform.md Tenancy; requirements.md R22).

-- Satisfies R1, R2, R3, R13, R22.
CREATE TABLE cms_user (
    id                UUID PRIMARY KEY,
    tenant_id         UUID NOT NULL,
    username          TEXT NOT NULL,        -- domain-prefix stripped (R2)
    display_name      TEXT NOT NULL,        -- first + last (R2) — personal data (R25)
    password_hash     TEXT NOT NULL,        -- memory-hard salted hash (design.md § Approach) — never logged (R25)
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_cms_user_tenant_username UNIQUE (tenant_id, username)
    -- Enforces requirements.md's "unique per tenant + stripped username" (R1) —
    -- a store-level uniqueness constraint, not an application check-then-insert,
    -- so a race between two concurrent signups for the same username cannot
    -- create two rows.
);

ALTER TABLE cms_user ENABLE ROW LEVEL SECURITY;
CREATE POLICY cms_user_tenant_isolation ON cms_user
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
    -- Enforces R22 — every read and write is scoped to the caller's own tenant
    -- by the store itself, never by an application-level filter alone.

-- Satisfies R3, XD-0002.
CREATE TABLE role_assignment (
    id                UUID PRIMARY KEY,
    tenant_id         UUID NOT NULL,
    user_id           UUID NOT NULL REFERENCES cms_user (id),
    role              TEXT NOT NULL CHECK (role IN ('viewer', 'editor', 'administrator')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_role_assignment_user UNIQUE (user_id)
    -- One role per user, enforced by the store (design.md § Data model).
);

ALTER TABLE role_assignment ENABLE ROW LEVEL SECURITY;
CREATE POLICY role_assignment_tenant_isolation ON role_assignment
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- Satisfies R4, R5, R19.
CREATE TABLE refresh_token (
    id                UUID PRIMARY KEY,
    tenant_id         UUID NOT NULL,
    user_id           UUID NOT NULL REFERENCES cms_user (id),
    token_hash        TEXT NOT NULL,        -- the presented token is never stored in clear (R25)
    predecessor_id    UUID NULL REFERENCES refresh_token (id),
    status            TEXT NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active', 'consumed', 'revoked', 'expired')),
    expires_at        TIMESTAMPTZ NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash)
    -- Access pattern: "consume this exact token, atomically, if and only if
    -- its status is still 'active'" is served by this unique lookup key plus
    -- a single conditional UPDATE (status = 'active' -> 'consumed' WHERE id = ?
    -- AND status = 'active'), which is what design.md's State and idempotency
    -- section names as the atomic consume-once operation enforcing R19 — never
    -- a read-then-write from application code, which would let two concurrent
    -- callers both observe 'active' and both succeed.
);

ALTER TABLE refresh_token ENABLE ROW LEVEL SECURITY;
CREATE POLICY refresh_token_tenant_isolation ON refresh_token
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

CREATE INDEX ix_refresh_token_user ON refresh_token (user_id);
-- Access pattern: "revoke every active refresh token for this user" (reuse
-- detection, design.md § Approach) — served by this index plus the status filter.

-- Satisfies R8, R9, R10, R22, R23. Append-only by design (XD-0003).
CREATE TABLE audit_log_entry (
    id                UUID PRIMARY KEY,
    tenant_id         UUID NOT NULL,
    actor             TEXT NOT NULL,        -- server-derived, never client-supplied (R10) — personal data (R25)
    occurred_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    entity_type       TEXT NOT NULL,
    entity_id         UUID NOT NULL,
    action            TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete')),
    metadata          JSONB NOT NULL DEFAULT '{}'::jsonb
    -- No updated_at column, deliberately (50-api-contracts.md) — this table is
    -- append-only (R23); a mutable-looking timestamp would imply a row can
    -- change after it is written, which the immutability guarantee below
    -- forbids.
);

ALTER TABLE audit_log_entry ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_log_entry_tenant_isolation ON audit_log_entry
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

CREATE INDEX ix_audit_log_entry_entity ON audit_log_entry (tenant_id, entity_type, entity_id);
-- Access pattern: GET /api/v1/audit-log?entityType=&entityId= (R8) — the
-- filtered, cursor-paginated read this index serves.

CREATE INDEX ix_audit_log_entry_occurred_at ON audit_log_entry (tenant_id, occurred_at);
-- Access pattern: cursor pagination ordered by occurrence time (10-platform.md
-- Pagination) when no entity filter is given.

-- Immutability (requirements.md R23; 20-compliance.md Audit): no UPDATE or
-- DELETE statement may ever be issued against audit_log_entry. This is
-- enforced by granting the application role INSERT and SELECT only on this
-- table — never UPDATE or DELETE — at provisioning time in the engineering
-- repo (stack.md's provisioning tool), not by an application-level
-- "don't call update" convention, which a future change could silently
-- violate. Recorded here as the requirement the grant must satisfy; the grant
-- statement itself belongs to the engineering repo's provisioning code, not to
-- this repo (50-api-contracts.md § Provisioning is not a contract).

-- Backfill: role_assignment is seeded once from the legacy SV_UserRights table
-- by UNIT-CMS-0011's ETL (requirements.md R27, AUTHZ-3). That backfill is a
-- task tracked in UNIT-CMS-0011's own tasks.md, not a statement in this
-- migration (50-api-contracts.md — "any backfill is a task, never part of the
-- contract").
