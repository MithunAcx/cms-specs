---
id: CAP-CMS-0006
slug: legacy-data-migration
project: CMS
title: Legacy Data Migration
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Legacy Data Migration

## Original ask

> **MIG-1** — The `PolicyPlus` schema is preserved; the new API cuts over to the same tables — no bulk data migration is required for go-live.
>
> **MIG-2** — Recommended (non-blocking) schema clean-ups, staged after parity is proven: convert `PP_Agency_CGA.Phone` from `float` to a string type (DR-2); normalize `history`/`History` flags to a single boolean convention (DR-3); add a primary key to `PP_Broker_Status` (DR-7); reconcile the dual insurer columns in `Web_Accounts` (DR-5); reconcile CGA `Agency_ID` typing (DR-6).
>
> **MIG-3** — A data-quality pass should identify CGA rows previously mis-inserted into `pp_agent` (DR-1) and reconcile them into `PP_Agency_CGA`.
>
> **MIG-4** — Reference lookups (`PP_States`, `PP_BrokerType`, `PP_AgentType`, `PP_Broker_Status`, `PP_TskStatus`) are used as-is.
>
> **Note on MIG-1:** this requirement's premise — reusing the same SQL Server tables —
> does not hold for this project, since the decided datastore is PostgreSQL, not the
> legacy `PolicyPlus` SQL Server database (see `stack.md`). A one-time ETL migration of
> existing brokerage/agency/CGA/activity/policy-reference data is therefore required at
> go-live, into the clean-redesign schema described in CAP-CMS-0003 (intake Q1/A1). MIG-2
> through MIG-4 are reframed accordingly: MIG-2's schema clean-ups are largely moot
> because the new schema is a clean redesign rather than a patched copy of the legacy
> one, but MIG-3's CGA-reconciliation is a live data-quality problem in the *data itself*
> (not the schema) and must be resolved as part of the cutover, and MIG-4's lookups still
> need to be carried over, just into the new schema's lookup tables rather than reused
> in place.

## Outcome measures

| # | Measure | Baseline | Target | How measured | From |
|---|---------|----------|--------|--------------|------|
| M1 | Active legacy brokerage/agency/broker/agent/CGA/activity records present and correct in the new PostgreSQL schema after cutover | 100% of active records currently in the legacy `PolicyPlus` tables (per `cms-data-schema.yaml`'s `used_by_app: true` columns) | 100% of active records migrated with referential integrity intact and zero data loss, verified by a record-count and field-level reconciliation report | Migration validation report comparing legacy source counts/checksums to migrated target counts/checksums | raw ask §11 (MIG-1, reframed) and MIG-4 — **not** a numbered intake `O<n>`; see Open questions |
| M2 | CGA rows historically mis-inserted into `pp_agent` (DR-1) | Unknown count — `database-specification.md` §10 flags the bug but does not quantify affected rows | 100% identified and reconciled into the new schema's CGA entity before cutover is considered complete | A data-quality pass against the legacy `pp_agent` table, cross-referenced against known CGA identifying fields (`cga_agt`, address) | raw ask §11 MIG-3 — **not** a numbered intake `O<n>`; see Open questions |

## Outcome-level acceptance

- A1. Every active brokerage, agency, broker, agent, and CGA record in the legacy system has a corresponding, field-complete record in the new PostgreSQL schema, reconciled by count and by spot-check.
- A2. Every contact-activity record is migrated with its original `UsrName` stamp, entered/modified/completed dates, and follow-up date intact.
- A3. The CGA-reconciliation pass (M2) is complete and its findings are documented, whether or not any mis-inserted rows are found.
- A4. Reference lookups (states, broker/agent types, broker statuses, task statuses) exist in the new schema with the same value sets as the legacy lookups (MIG-4).

## Non-goals

- Ongoing (post-cutover) data entry, editing, or the schema those records live in day-to-day — owned by CAP-CMS-0003 (Partner Records Management); this capability is the one-time cutover only, not a sync mechanism.
- The non-blocking schema clean-ups MIG-2 describes as staged *after* parity (float→string phone columns, mixed history-flag conventions, `Web_Accounts` dual insurer columns, CGA `Agency_ID` typing) — moot for this project, since the target schema is a clean redesign from the start (intake Q1/A1) rather than a patched copy of the legacy physical schema; there is no legacy physical schema being kept around to clean up.
- Ongoing replication or a live sync between the legacy `PolicyPlus` database and the new store — this is a one-time cutover; nothing here runs on an ongoing schedule.
- Migrating policy data (`PP_PolicyData`) — that data is never copied into this project's store at all; CAP-CMS-0005 reads it live from the system that owns it.

## Constraints

| Constraint | Source | Effect |
|---|---|---|
| One-time cutover, not an ongoing sync | intake Q1 | No recurring migration job is in scope; this is a bounded, one-shot deliverable |
| Small-scale volume: low hundreds of brokerages/agencies/CGAs | intake Q8 | Bounds the migration's expected runtime and validation-report size — this is not a large-scale ETL problem |
| Clean-redesign target schema (not a legacy mirror) | intake Q1/A1 | The migration must map legacy columns to the new domain model (raw ask §6.5), not copy them 1:1 |
| No special PII retention/residency requirement | intake Q9 | No bespoke handling needed for FEIN/NPN/phone/email/address fields during migration beyond standard care in transit and at rest |

## Decomposition rationale

Legacy Data Migration is kept as its own capability, separate from Partner Records
Management even though it populates that capability's schema, because it is a bounded,
one-time deliverable with its own acceptance criterion (every active record present and
correct after cutover) that is fundamentally different in kind from Partner Records
Management's ongoing CRUD outcome — a capability accepted once at go-live versus one
accepted on an ongoing basis is not the same domain, even though they touch the same
tables. Folding migration into Partner Records Management was rejected because it would
make that capability's acceptance depend on a one-time event (the cutover) rather than on
the durable behavior (CRUD correctness) it is meant to measure indefinitely. Treating
migration as a mere task inside Partner Records Management's own units, rather than a
capability, was also considered — but MIG-3's CGA-reconciliation data-quality problem is
substantial enough (an unknown number of historically mis-inserted rows requiring their
own identification pass) to need its own outcome measure and acceptance condition, which
a capability, not a task buried in another capability's unit, is what carries.

## Dependencies

| Direction | What | Why |
|---|---|---|
| upstream | Partner Records Management (CAP-CMS-0003) | The migration's target schema is defined there; migration cannot be designed until that schema is settled |
| upstream | Contact Activity & Follow-up Tracking (CAP-CMS-0004) | Activity records are migrated into that capability's schema, including the soft-delete convention it defines |

## Open questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| Q1 | M1 and M2 trace to the raw ask's §11 (MIG-1, reframed, and MIG-3) directly rather than to a numbered intake `O<n>` — the intake's candidate outcomes (O1–O6) did not include a migration-completeness outcome, even though Q1's answer commits this project to a real ETL migration. Should the intake be amended with addendum outcomes for migration completeness and CGA reconciliation, so this capability's measures cite `intake O<n>` the same way every other capability's do? | @MithunAcx | open — non-blocking, recorded for `ba-requirements-intake` to consider on its next pass |

<!-- GENERATED:units — do not hand-edit below. Written by pm-state-rollup. -->
## Units

<!-- /GENERATED:units -->
