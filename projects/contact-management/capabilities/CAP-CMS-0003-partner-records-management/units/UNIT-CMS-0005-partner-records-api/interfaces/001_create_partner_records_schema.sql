-- Target: PostgreSQL 18 (projects/contact-management/stack.md)
-- UNIT-CMS-0005 — Partner Records API storage contract.
-- Forward-only, numbered migration. No destructive statement shares this file
-- with an additive one (10-platform.md Storage).
--
-- Tenant isolation mechanism: row-level security (stack.md). Every table below
-- carries tenant_id and a policy scoping every row to the caller's own tenant,
-- read and write alike (10-platform.md Tenancy; requirements.md R43). The
-- session-scoped setting `app.tenant_id` is set once per request by the calling
-- service before any statement in this schema runs; its exact mechanism is an
-- engineering-repo concern, not this contract's.

-- ============================================================================
-- Brokerage (requirements.md R1-R5, R9-R10, R26-R29, R33-R34, R43-R47)
-- ============================================================================

CREATE TABLE brokerage (
    id                      uuid PRIMARY KEY,
    tenant_id               uuid NOT NULL,
    version                 bigint NOT NULL DEFAULT 1,           -- R26: optimistic concurrency (XD-0002)
    name                    text NOT NULL,
    address_line1           text NOT NULL,
    address_line2           text,
    address_city            text NOT NULL,
    address_state           text NOT NULL,
    address_zip             text NOT NULL,
    phone                   text NOT NULL,                        -- normalized digits, formatted at the API boundary (R4)
    fax                     text NOT NULL,
    tax_id                  text NOT NULL,                        -- FEIN; personal data (R46)
    assigned_underwriter    text NOT NULL,                         -- free text, not a managed lookup (capability.md non-goals)
    status                  text NOT NULL,                         -- must match an active broker_status.value
    contract_received_date  date NOT NULL,                         -- date-only, no time component (R34)
    disabled                boolean NOT NULL DEFAULT false,        -- XD-0003; not a terminal state (R33)
    account_code            text NOT NULL,                         -- server-assigned, read-only through the API (R5)
    accounting_contact_name text,
    accounting_address_line1 text,
    accounting_address_line2 text,
    accounting_address_city  text,
    accounting_address_state text,
    accounting_address_zip   text,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN brokerage.version IS
  'Compared and incremented in the same statement that applies an update — R26/R3/R10. Never a read-then-write in application code.';
COMMENT ON COLUMN brokerage.accounting_contact_name IS
  'Accounting/billing sub-resource (FR-BRK-8/9) shares this table''s own version rather than having one of its own — design.md § Approach; accepted trade-off in design.md § Risks.';

ALTER TABLE brokerage ENABLE ROW LEVEL SECURITY;
CREATE POLICY brokerage_tenant_isolation ON brokerage
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE UNIQUE INDEX ux_brokerage_tenant_account_code ON brokerage (tenant_id, account_code);

-- ============================================================================
-- Broker (requirements.md R6-R8, R26-R29, R43, R46-R47)
-- ============================================================================

CREATE TABLE broker (
    id            uuid PRIMARY KEY,
    tenant_id     uuid NOT NULL,
    brokerage_id  uuid NOT NULL REFERENCES brokerage (id),
    version       bigint NOT NULL DEFAULT 1,
    first_name    text NOT NULL,
    last_name     text NOT NULL,
    broker_type   text NOT NULL,                                  -- must match an active broker_type.value
    email         text NOT NULL,                                  -- personal data (R46)
    npn           text NOT NULL,                                  -- personal data (R46)
    disabled      boolean NOT NULL DEFAULT false,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE broker ENABLE ROW LEVEL SECURITY;
CREATE POLICY broker_tenant_isolation ON broker
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE INDEX ix_broker_brokerage_id ON broker (brokerage_id);

-- ============================================================================
-- Agency (requirements.md R11-R14, R26-R29, R33-R34, R43, R46-R47)
-- ============================================================================

CREATE TABLE agency (
    id                     uuid PRIMARY KEY,
    tenant_id              uuid NOT NULL,
    version                bigint NOT NULL DEFAULT 1,
    name                   text NOT NULL,
    address_line1          text NOT NULL,
    address_line2          text,
    address_city           text NOT NULL,
    address_state          text NOT NULL,
    address_zip            text NOT NULL,
    phone                  text NOT NULL,                          -- punctuation stripped on save (R14)
    agency_number          text NOT NULL,                           -- "G1 Agency ID"
    billing_contact        text NOT NULL,
    billing_contact_phone  text NOT NULL,
    notes                  text,
    high_potential         boolean NOT NULL DEFAULT false,
    premium_financing      boolean NOT NULL DEFAULT false,
    disabled               boolean NOT NULL DEFAULT false,          -- XD-0003; not a terminal state (R33)
    account_code           text NOT NULL,                           -- ADR-0001: per-tenant sequence, assigned at insert
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE agency ENABLE ROW LEVEL SECURITY;
CREATE POLICY agency_tenant_isolation ON agency
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE UNIQUE INDEX ux_agency_tenant_account_code ON agency (tenant_id, account_code);

-- Per-tenant atomic sequence backing agency.account_code (ADR-0001). The
-- generating service performs `UPDATE agency_account_code_counter
-- SET next_value = next_value + 1 WHERE tenant_id = $1 RETURNING next_value - 1`
-- in the same transaction as the agency INSERT — the row lock UPDATE takes is
-- the atomic construct that prevents two concurrent creates from allocating the
-- same code; it is enforced by the statement itself, not by application-level
-- read-then-write (design.md § Components — Account-code generator; ADR-0001).
CREATE TABLE agency_account_code_counter (
    tenant_id   uuid PRIMARY KEY,
    next_value  bigint NOT NULL DEFAULT 1
);

ALTER TABLE agency_account_code_counter ENABLE ROW LEVEL SECURITY;
CREATE POLICY agency_account_code_counter_tenant_isolation ON agency_account_code_counter
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

-- ============================================================================
-- Agent (requirements.md R15-R17, R26-R29, R43, R46-R47)
-- ============================================================================

CREATE TABLE agent (
    id          uuid PRIMARY KEY,
    tenant_id   uuid NOT NULL,
    agency_id   uuid NOT NULL REFERENCES agency (id),
    version     bigint NOT NULL DEFAULT 1,
    first_name  text NOT NULL,
    last_name   text NOT NULL,
    agent_type  text NOT NULL,                                     -- must match an active agent_type.value
    phone       text NOT NULL,
    email       text NOT NULL,                                     -- personal data (R46)
    npn         text NOT NULL,                                     -- personal data (R46)
    disabled    boolean NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE agent ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_tenant_isolation ON agent
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE INDEX ix_agent_agency_id ON agent (agency_id);

-- ============================================================================
-- Cga (requirements.md R18-R22, R26-R29, R43, R46-R47) — DR-1/DR-2/DR-6 corrected
-- ============================================================================

CREATE TABLE cga (
    id            uuid PRIMARY KEY,
    tenant_id     uuid NOT NULL,
    version       bigint NOT NULL DEFAULT 1,
    agent_name    text NOT NULL,
    address_line1 text NOT NULL,
    address_line2 text,
    address_city  text NOT NULL,
    address_state text NOT NULL,
    address_zip   text NOT NULL,
    email         text NOT NULL,                                   -- personal data (R46)
    phone         text NOT NULL,                                   -- string-typed end-to-end, never numeric (R21, DR-2)
    agency_id     uuid NOT NULL REFERENCES agency (id),            -- normalized to one representation at the API boundary regardless of caller input shape (R22, DR-6)
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cga IS
  'Writes land here exclusively — never in the agent table (DR-1 correction, CAP-CMS-0003/A2).';

ALTER TABLE cga ENABLE ROW LEVEL SECURITY;
CREATE POLICY cga_tenant_isolation ON cga
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE INDEX ix_cga_agency_id ON cga (agency_id);

-- ============================================================================
-- Reference lookups (requirements.md R23-R25, R26, R43)
-- One table per lookup type named in the Unified API Contract. Assumed
-- tenant-scoped per requirements.md's stated Assumption (open question #2) —
-- revisit the RLS policy below if that is answered otherwise.
-- ============================================================================

CREATE TABLE reference_lookup_state (
    tenant_id   uuid NOT NULL,
    value       text NOT NULL,
    label       text NOT NULL,
    version     bigint NOT NULL DEFAULT 1,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, value)
);
ALTER TABLE reference_lookup_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY reference_lookup_state_tenant_isolation ON reference_lookup_state
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE TABLE reference_lookup_broker_type (
    tenant_id   uuid NOT NULL,
    value       text NOT NULL,
    label       text NOT NULL,
    version     bigint NOT NULL DEFAULT 1,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, value)
);
ALTER TABLE reference_lookup_broker_type ENABLE ROW LEVEL SECURITY;
CREATE POLICY reference_lookup_broker_type_tenant_isolation ON reference_lookup_broker_type
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE TABLE reference_lookup_agent_type (
    tenant_id   uuid NOT NULL,
    value       text NOT NULL,
    label       text NOT NULL,
    version     bigint NOT NULL DEFAULT 1,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, value)
);
ALTER TABLE reference_lookup_agent_type ENABLE ROW LEVEL SECURITY;
CREATE POLICY reference_lookup_agent_type_tenant_isolation ON reference_lookup_agent_type
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

-- broker_status keeps Status_ID as the enforced logical key (R25, DR-7) — the
-- legacy table declared no primary key at all; this one always does.
CREATE TABLE reference_lookup_broker_status (
    tenant_id   uuid NOT NULL,
    status_id   integer NOT NULL,
    value       text NOT NULL,
    label       text NOT NULL,
    version     bigint NOT NULL DEFAULT 1,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, value),
    CONSTRAINT ux_broker_status_status_id UNIQUE (tenant_id, status_id)
);
ALTER TABLE reference_lookup_broker_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY reference_lookup_broker_status_tenant_isolation ON reference_lookup_broker_status
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

-- ============================================================================
-- Audit trail (requirements.md R44, R47) — append-only by construction.
-- No updated_at column: a column that could change would imply the table is
-- mutable, and the whole point is that it is not (50-api-contracts.md).
-- Immutability is enforced by granting this table's application role INSERT
-- only — no UPDATE, no DELETE — not by application logic (R44).
-- ============================================================================

CREATE TABLE partner_records_audit (
    id                uuid PRIMARY KEY,
    tenant_id         uuid NOT NULL,
    entity_type       text NOT NULL,       -- 'brokerage' | 'broker' | 'agency' | 'agent' | 'cga' | lookup type
    entity_id         text NOT NULL,
    operation         text NOT NULL,       -- 'create' | 'update' | 'disable'
    actor             text NOT NULL,       -- caller identity; never a raw personal-data field beyond what identifies the actor
    old_version       bigint,
    new_version       bigint NOT NULL,
    occurred_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE partner_records_audit ENABLE ROW LEVEL SECURITY;
CREATE POLICY partner_records_audit_tenant_isolation ON partner_records_audit
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

COMMENT ON TABLE partner_records_audit IS
  'Retention: 7 years (20-compliance.md, R44). Redaction of a broker/agent''s personal fields (R47) leaves this table''s own historical rows unchanged, per the same severance approach applied to the owning entity tables.';

-- Backfill of any pre-existing data is a task for CAP-CMS-0006/UNIT-CMS-0011,
-- never part of this or any future migration in this file (R48).
