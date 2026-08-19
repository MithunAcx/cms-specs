-- UNIT-CMS-0011 — Legacy Data ETL
-- Target: PostgreSQL 18 (projects/contact-management/stack.md)
--
-- Forward-only migration 0001. Creates one staging table per legacy source table
-- in scope for this unit's migration (requirements.md R1-R7, R11). Each staging
-- table is a bounded, one-time raw copy of the legacy source's `used_by_app: true`
-- columns (requirements/cms-data-schema.yaml) — never the `used_by_app: false`
-- columns, which are out of scope for both the running application and this
-- migration.
--
-- Append-only by design: a staging table is populated once per migration run and
-- never updated afterward, so none of these tables carries an `updated_at` column
-- — a mutable-looking column would misstate that intent (50-api-contracts.md,
-- Storage contracts).
--
-- Tenant isolation: this deployment is single-tenant at go-live
-- (requirements.md Assumptions). Every table still carries `tenant_id` and an
-- RLS policy scoped to it, so the mechanism is identical to every other unit's
-- and needs no future rework if a second tenant is ever onboarded.
--
-- No destructive statement shares this migration with an additive one.

-- =====================================================================
-- Reference lookup staging tables — satisfies R7
-- =====================================================================

CREATE TABLE stg_lookup_state (
    tenant_id           uuid        NOT NULL,
    legacy_state_id     integer     NOT NULL,
    state_name          text        NOT NULL,
    staged_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_lookup_state PRIMARY KEY (tenant_id, legacy_state_id)
);
COMMENT ON TABLE stg_lookup_state IS
    'Raw staged copy of legacy PP_States (used_by_app columns only). Satisfies R7.';

CREATE TABLE stg_lookup_broker_type (
    tenant_id           uuid        NOT NULL,
    legacy_broker_type_id integer   NOT NULL,
    broker_type_name    text        NOT NULL,
    staged_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_lookup_broker_type PRIMARY KEY (tenant_id, legacy_broker_type_id)
);
COMMENT ON TABLE stg_lookup_broker_type IS
    'Raw staged copy of legacy PP_BrokerType. Satisfies R7.';

CREATE TABLE stg_lookup_agent_type (
    tenant_id           uuid        NOT NULL,
    legacy_agent_type_id integer    NOT NULL,
    agent_type_name     text        NOT NULL,
    staged_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_lookup_agent_type PRIMARY KEY (tenant_id, legacy_agent_type_id)
);
COMMENT ON TABLE stg_lookup_agent_type IS
    'Raw staged copy of legacy PP_AgentType. Satisfies R7.';

CREATE TABLE stg_lookup_broker_status (
    tenant_id           uuid        NOT NULL,
    -- Legacy PP_Broker_Status declares no PK constraint (DR-7); the logical key
    -- (Status_ID) is enforced here as a real primary key for the staged copy.
    legacy_status_id    integer     NOT NULL,
    status_name         text        NOT NULL,
    staged_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_lookup_broker_status PRIMARY KEY (tenant_id, legacy_status_id)
);
COMMENT ON TABLE stg_lookup_broker_status IS
    'Raw staged copy of legacy PP_Broker_Status, with a PK the legacy table itself lacks (DR-7). Satisfies R7.';

CREATE TABLE stg_lookup_task_status (
    tenant_id             uuid        NOT NULL,
    legacy_task_status_id integer     NOT NULL,
    task_status_name      text        NOT NULL,
    task_type_id          integer,
    order_by              integer,
    staged_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_lookup_task_status PRIMARY KEY (tenant_id, legacy_task_status_id)
);
COMMENT ON TABLE stg_lookup_task_status IS
    'Raw staged copy of legacy PP_TskStatus. Satisfies R7.';

-- =====================================================================
-- Brokerage / broker staging tables — satisfies R1, R2
-- =====================================================================

CREATE TABLE stg_brokerage (
    tenant_id               uuid        NOT NULL,
    legacy_producer_number  integer     NOT NULL,
    brokerage_name          text,
    address_line1           text,
    address_line2           text,
    city                    text,
    state                   text,
    zip                     text,
    phone_number            text,
    fax_number              text,
    tax_id                  text,
    assigned_uw             text,
    legacy_status_id        integer,
    history_flag_raw        text,       -- raw legacy value; DR-3 coercion happens in transform, not here
    contract_received_date  date,
    account_code            text,
    accounting_add_name     text,
    accounting_address      text,
    accounting_city         text,
    accounting_state_id     integer,
    accounting_zip          text,
    staged_at               timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_brokerage PRIMARY KEY (tenant_id, legacy_producer_number)
);
COMMENT ON TABLE stg_brokerage IS
    'Raw staged copy of legacy PP_Brokerage (used_by_app columns only). Satisfies R1.';

CREATE TABLE stg_broker (
    tenant_id                uuid        NOT NULL,
    legacy_employee_number   integer     NOT NULL,
    legacy_producer_number   integer     NOT NULL,  -- FK to stg_brokerage, resolved at transform time
    first_name               text,
    last_name                text,
    history_flag_raw         text,
    legacy_broker_type_id    integer,
    email                    text,
    broker_npn               text,
    staged_at                timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_broker PRIMARY KEY (tenant_id, legacy_employee_number)
);
COMMENT ON TABLE stg_broker IS
    'Raw staged copy of legacy PP_BrokerEmployees. Satisfies R2.';

-- =====================================================================
-- Agency / agent / CGA staging tables — satisfies R3, R4, R5
-- =====================================================================

CREATE TABLE stg_agency (
    tenant_id            uuid        NOT NULL,
    legacy_agency_id     integer     NOT NULL,
    agency_name          text,
    address              text,
    city                 text,
    legacy_state_id      integer,
    zip                  text,
    phone                text,
    billing_contact      text,
    billing_contact_phone text,
    notes                text,
    agency_no            text,
    high_potential        boolean,
    premium_financing     boolean,
    history_flag_raw      text,
    account_code          text,
    staged_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_agency PRIMARY KEY (tenant_id, legacy_agency_id)
);
COMMENT ON TABLE stg_agency IS
    'Raw staged copy of legacy PP_Agency. Satisfies R3.';

CREATE TABLE stg_agent (
    tenant_id             uuid        NOT NULL,
    legacy_agent_id       integer     NOT NULL,
    first_name            text,
    last_name             text,
    legacy_agent_type_id  integer,
    phone                 text,
    email                 text,
    legacy_agency_id      integer,   -- PP_Agent.Agency_ID (int) — FK to stg_agency
    agent_npn             text,
    history_flag_raw      text,
    staged_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_agent PRIMARY KEY (tenant_id, legacy_agent_id)
);
COMMENT ON TABLE stg_agent IS
    'Raw staged copy of legacy PP_Agent. Satisfies R4.';

CREATE TABLE stg_agency_cga (
    tenant_id             uuid        NOT NULL,
    legacy_cga_id         integer     NOT NULL,
    cga_agent_name        text,
    address               text,
    city                  text,
    state                 text,
    zip                   text,
    email                 text,
    -- Legacy PP_Agency_CGA.Phone is typed `float` (DR-2). Staged as text,
    -- verbatim, so the transform step's parse-or-null decision (design.md,
    -- Flow "Agency, agent, and CGA migration") has the original value to work
    -- from rather than a value already lossily cast.
    phone_raw             text,
    -- Legacy PP_Agency_CGA.Agency_ID is nvarchar, unlike PP_Agent.Agency_ID
    -- (int) — DR-6. Staged as text; resolved against stg_agency at transform
    -- time regardless of the type mismatch.
    legacy_agency_id_raw  text,
    staged_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_agency_cga PRIMARY KEY (tenant_id, legacy_cga_id)
);
COMMENT ON TABLE stg_agency_cga IS
    'Raw staged copy of legacy PP_Agency_CGA. Satisfies R5.';

-- =====================================================================
-- Activity staging table — satisfies R6
-- =====================================================================

CREATE TABLE stg_activity (
    tenant_id              uuid        NOT NULL,
    legacy_tskdata_id      integer     NOT NULL,
    -- Polymorphic parent, mirroring the legacy source: exactly one of the two
    -- is populated per row.
    legacy_agency_id       integer,
    legacy_producer_number integer,
    legacy_task_status_id  integer,
    follow_up_date         date,
    note                   text,
    input_date             timestamptz,
    modified_date          timestamptz,
    completed_date         timestamptz,
    user_name              text,
    staged_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_stg_activity PRIMARY KEY (tenant_id, legacy_tskdata_id),
    CONSTRAINT chk_stg_activity_single_parent CHECK (
        (legacy_agency_id IS NOT NULL AND legacy_producer_number IS NULL)
        OR (legacy_agency_id IS NULL AND legacy_producer_number IS NOT NULL)
    )
);
COMMENT ON TABLE stg_activity IS
    'Raw staged copy of legacy PP_TskData. Satisfies R6. The single-parent check
     constraint mirrors the legacy source''s own polymorphic-parent convention —
     it does not invent a new rule, it enforces the one already implied by the
     source data never populating both parent columns at once.';

-- =====================================================================
-- Row-level security — one tenant today, same mechanism as every other unit
-- =====================================================================

ALTER TABLE stg_lookup_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_lookup_broker_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_lookup_agent_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_lookup_broker_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_lookup_task_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_brokerage ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_broker ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_agency ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_agent ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_agency_cga ENABLE ROW LEVEL SECURITY;
ALTER TABLE stg_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_stg_lookup_state ON stg_lookup_state
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_lookup_broker_type ON stg_lookup_broker_type
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_lookup_agent_type ON stg_lookup_agent_type
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_lookup_broker_status ON stg_lookup_broker_status
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_lookup_task_status ON stg_lookup_task_status
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_brokerage ON stg_brokerage
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_broker ON stg_broker
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_agency ON stg_agency
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_agent ON stg_agent
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_agency_cga ON stg_agency_cga
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
CREATE POLICY tenant_isolation_stg_activity ON stg_activity
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Any backfill of these tables from the legacy source is a task
-- (architect-unit-tasks), never part of this migration file.
