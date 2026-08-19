---
id: UNIT-CMS-0011
slug: legacy-data-etl
project: CMS
capability: CAP-CMS-0006
title: Legacy Data ETL
kind: data
target_repo: CMS-legacy-data-migration
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Legacy Data ETL

## Scope

One-time migration of active legacy brokerage/agency/broker/agent/activity/reference-
lookup records into UNIT-CMS-0005's clean-redesign schema (XD-0001). Owns and is the
sole writer of the `MigrationLog` entity (XD-0002), exposing a logging contract
UNIT-CMS-0012 calls rather than writing the table itself. An operator-run job, not a
request-serving service — its "contract" is the migration itself plus the log it
produces, independently verifiable via the validation report.

**In scope:**
- Migrating brokerages, agencies, brokers, agents, activity records, and reference lookups into the new schema
- Migrating existing (correctly-inserted) CGA records from the legacy CGA table
- Owning and writing the `MigrationLog` entity; exposing a logging call UNIT-CMS-0012 uses
- Producing a count/checksum validation report per source table

**Out of scope:**
- Defining the target schema (UNIT-CMS-0005 owns it)
- CGA reconciliation from `pp_agent` (UNIT-CMS-0012 — this unit does not scan for or fix mis-inserted CGA rows; it migrates only rows already present in the legacy CGA table)
- Any ongoing sync after cutover — this is a one-time job

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | Every active legacy brokerage record (the `used_by_app: true` columns of `PP_Brokerage`) is migrated into a `Brokerage` record in the target schema, with the legacy `History` flag mapped to a single `disabled` boolean. | CAP-CMS-0006/M1, A1 | must |
| R2 | Every active legacy broker record (`PP_BrokerEmployees`) is migrated into a `Broker` record linked to its already-migrated parent `Brokerage`. | CAP-CMS-0006/M1, A1 | must |
| R3 | Every active legacy agency record (`PP_Agency`) is migrated into an `Agency` record in the target schema, with the legacy `history` flag mapped to `disabled`. | CAP-CMS-0006/M1, A1 | must |
| R4 | Every active legacy agent record (`PP_Agent`) is migrated into an `Agent` record linked to its already-migrated parent `Agency`. | CAP-CMS-0006/M1, A1 | must |
| R5 | Every existing legacy CGA record (`PP_Agency_CGA`) is migrated into a `Cga` record linked to its parent `Agency`'s **new** (post-migration) id, with the legacy `Phone` value coerced from its stored numeric form to a string, and the legacy `Agency_ID` value (stored as text) resolved to the correct parent regardless of the type mismatch against `PP_Agent.Agency_ID`. | CAP-CMS-0006/M1, A1 | must |
| R6 | Every active legacy contact-activity record (`PP_TskData`) is migrated into an `Activity` record, preserving the original `UsrName` stamp, entered date, modified date, completed date, and follow-up date exactly as recorded — none of these are reinterpreted as the migration run's own execution time. | CAP-CMS-0006/M1, A2 | must |
| R7 | Every reference lookup value (states, broker types, agent types, broker statuses, task statuses) is migrated into the target schema's lookup tables with the same value set as its legacy source. | CAP-CMS-0006/M1, A4 | must |
| R8 | Migration order guarantees every agency is fully migrated (R3) before that agency's agents (R4), CGAs (R5), or activity records (R6) are attempted, and every brokerage (R1) before that brokerage's brokers (R2) or activity records (R6). | CAP-CMS-0006/M1, A1 — also XD-0003 (UNIT-CMS-0012 depends on agencies being migrated first) | must |
| R9 | For every source record in scope across R1–R7, exactly one `MigrationLog` row is written recording its outcome (`migrated`, `skipped`, or `failed`), the source table, the source record's identifying key, and — for `skipped`/`failed` — a reason. | CAP-CMS-0006/M1, A1, A3; XD-0002 | must |
| R10 | A logging call is exposed that UNIT-CMS-0012 uses to record its own outcomes into the same `MigrationLog`, tagged `processedBy: cga-reconciliation`; this unit is the only writer of the underlying store. | CAP-CMS-0006/M1; XD-0002 | must |
| R11 | A validation report is produced per source table, comparing the legacy source's record count and a field-level checksum against the count and content of the corresponding `migrated` `MigrationLog` rows, and surfacing any discrepancy. | CAP-CMS-0006/M1, A1 | must |

## Behaviour detail

### R1–R7 — input class failures

| Condition | Result |
|---|---|
| A source row fails target-schema validation (missing a required field the new schema mandates, a value outside an enumerated lookup, a malformed email/phone that cannot be normalized) | The row is logged `failed` in `MigrationLog` with a specific reason; migration continues with the remaining rows in that source table — one bad row never halts the run. |
| A source row's legacy `History`/`history` flag holds a value outside the two known legacy conventions (`-1`/`0` int, or a recognized `char(10)` value) | The row is logged `failed` with reason `unrecognized_history_value` rather than guessed-coerced to a boolean; a guessed mapping risks silently flipping a record's disabled state. |
| A `PP_Agency_CGA` row's legacy `Phone` value cannot be parsed to a valid string phone number (e.g. a corrupted float) | The row is migrated with `phone` set to null and a `MigrationLog` note `phone_unparseable`, rather than failing the whole CGA record — phone is not identity-bearing for a CGA. |

### R2, R4, R5, R6 — referential integrity (input class)

| Condition | Result |
|---|---|
| A broker, agent, CGA, or activity row references a parent brokerage/agency that does not exist in the legacy source, or whose parent failed migration (R1/R3) | The child row is logged `skipped` in `MigrationLog` with reason `parent_not_migrated`; it is never migrated as an orphan (no parent reference) and never retried automatically. |

### R9, R15 — repetition class (idempotency)

| Condition | Result |
|---|---|
| The job is re-run after a prior partial or full run (planned retry, or recovery from a crash) | A source record already present in `MigrationLog` with outcome `migrated` is not migrated again and produces no duplicate target row or duplicate `MigrationLog` row — see R15 (idempotency key). |

### R1–R11 — partial failure class

| Condition | Result |
|---|---|
| The job process crashes after writing a record to the target schema but before writing its `MigrationLog` row | On restart, the job treats that source record as not-yet-migrated (absence of a `MigrationLog` row is the sole signal), re-attempts it, and the target write is itself idempotent per R15's key — this ordering (target write before log write) is a deliberate design constraint carried to `design.md`. |
| The target store becomes unreachable mid-run | The job halts cleanly, logs no `migrated` outcome for any record not yet confirmed committed, and reports which source tables/records were not yet attempted so a resumed run has a precise starting point. |

### R6 — time class

| Condition | Result |
|---|---|
| A legacy timestamp field (`inputDate`, `ModifiedDate`, `CompletedDate`, `FUDate`) carries no explicit timezone | It is interpreted per the labelled assumption below and converted to UTC RFC 3339 on write — never left ambiguous or silently treated as UTC without recording the assumption. |

### R1, R3 — state class

| Condition | Result |
|---|---|
| A legacy record's `History`/`history` flag is already set to the "disabled" value | The record is still migrated (it is in scope per the "active" baseline — see Assumptions), with `disabled: true` carried into the target schema; it is never excluded from the migration on account of being flagged disabled. |

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R12 | availability | N/A — this is a one-time, operator-run batch job, not a request-serving service; no ongoing SLO window applies. Its completion is bounded by R13 instead. |
| R13 | throughput / runtime budget | Peak source volume is low hundreds of records per entity type (brokerages, agencies, CGAs) per intake Q8 ("low hundreds of brokerages/agencies/CGAs, fewer than 50 concurrent staff users"; brokers/agents/activity volume is not separately quantified — see Assumptions). At this volume the full migration across all source tables is expected to complete within a single operator-scheduled maintenance window; there is no p95/p99 to state since there is no synchronous caller. This is what CAP-CMS-0006/M1's "100% of active records migrated … after cutover" depends on operationally — a run that cannot complete in its window is a run that has not delivered M1 by the cutover date. |
| R14 | surge | N/A — the source volume is fixed and known in advance (a one-time extract, not live traffic); there is no surge concept for a batch job that processes each source row exactly once. |
| R15 | idempotency | Every migration write is idempotent, keyed on `(sourceTable, sourceId)` — a value pair fixed before execution and never derived from anything the migration itself produces. Re-running the job against a `(sourceTable, sourceId)` already recorded `migrated` in `MigrationLog` is a no-op against the target schema. This is the `30-nfr-floor.md` idempotency floor obligation, independent of any single capability outcome measure, and is also what makes CAP-CMS-0006/M1's "zero data loss" achievable across a resumed run rather than only a single unbroken one. |
| R16 | concurrency | N/A — the job runs as a single instance to completion; no second concurrent instance may run against the same target schema in the same migration window (an operational precondition — see Assumptions), so no contended write exists to specify. |
| R17 | rate limits | N/A — an internal one-time batch process writing into its own project's datastore; no caller-facing rate limit applies. |
| R18 | authorization | The job runs under a dedicated migration-operator credential, distinct from any staff user session and from UNIT-CMS-0005's own API credentials; only that credential may invoke it, and it is retired once cutover is declared complete (CAP-CMS-0006 acceptance). This is the `30-nfr-floor.md` authorization floor obligation — a first-class requirement regardless of which outcome measure is in play, per this project's own G3 (RBAC is first-class). |
| R19 | tenant isolation | This deployment is single-tenant at go-live (see Assumptions); every migrated record is stamped with that one tenant identifier, and the row-level security policy (per `stack.md`) applies uniformly to every operation this unit performs on its own tables — staging writes, target writes, `MigrationLog` writes, **and** every read, including the validation report's own count/checksum queries — never only to writes. If a second tenant is ever onboarded, this unit's mapping (all legacy data belongs to one tenant) would need re-examination — flagged for that future case, not a gap today. This is the `10-platform.md` tenancy floor obligation, applied here even though only one tenant exists today, so no rework is needed if a second is ever onboarded. |
| R20 | audit | Every `MigrationLog` row **is** this unit's audit record for the migration event: what happened (outcome), when (`processedAt`), which unit produced it (`processedBy`), and the external reference (`sourceTable`/`sourceId`). Immutability is enforced by treating `MigrationLog` as insert-only — no update or delete path is exposed by the logging contract (R9, R10). Retention follows the 7-year financial/regulated-record floor (20-compliance.md), since the migration is the durable record of how brokerage/agency data entered the new system — this is also the evidence CAP-CMS-0006/A1's "reconciled by count and by spot-check" acceptance condition is checked against. |
| R21 | observability | Metrics: records processed/migrated/skipped/failed per source table, run duration, run outcome (complete/halted). Structured log fields: `sourceTable`, `sourceId`, outcome, reason (for non-`migrated` outcomes), run id. No personal data (names, emails, phone, FEIN, NPN) appears in any log line or metric label — only identifying keys and outcome codes (R22). This is the `30-nfr-floor.md` observability floor obligation, independent of any single capability outcome measure. |
| R22 | data classification | Personal data migrated: broker/agent first/last name, email, phone, NPN; brokerage/agency accounting contact name and phone; CGA agent name, address, email, phone; activity `UsrName` (an internal staff identifier, not a data subject). `BTax_ID` (FEIN) is a tax identifier — treated as personal data requiring the same never-logged handling as the rest, though not special-category (no health/biometric data exists anywhere in this migration's scope). None of these fields may appear in a log line, `MigrationLog.reason` text, metric label, or the validation report's discrepancy output — those carry only counts, keys, and outcome codes. This is the `20-compliance.md` personal-data floor obligation, independent of any single capability outcome measure. |
| R23 | retention and deletion | The migrated business records' retention is owned by UNIT-CMS-0005 (the schema owner), not this unit. This unit's own record — `MigrationLog` — is retained per R20 (7 years, insert-only). An erasure request against a data subject whose record was migrated is served by UNIT-CMS-0005's erasure path against the target schema; `MigrationLog` retains the outcome row (source table, source id, outcome, timestamp) with no personal-data fields to sever, since it never stored any. This is the `20-compliance.md` retention-versus-erasure floor obligation, independent of any single capability outcome measure. |
| R24 | migration and backfill | This unit **is** the migration; it is a one-time, non-reversible-in-place operation against a schema being populated for the first time (no prior target data to conflict with). It is not automatically reversible — undoing a bad run means restoring the target schema from a pre-migration snapshot (an operational/infra procedure outside this unit's own scope) rather than an inverse migration this unit runs. This row restates, as the floor table requires it be stated explicitly, the same fact R1–R11 already establish in service of CAP-CMS-0006/M1. |
| R25 | feature flag | N/A — an operator-invoked one-time job has no "off" state distinct from "not yet run"; there is no in-flight-work-on-toggle concern since nothing else depends on this job being live. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| MigrationLog | Owned (sole writer) | This unit's own tracking entity; UNIT-CMS-0012 appends through this unit's logging contract, never by writing the table directly (XD-0002). |
| Brokerage, Broker, Agency, Agent, Cga, Activity | Write (into UNIT-CMS-0005's schema) | This unit populates these entities but does not own their schema — UNIT-CMS-0005 does (XD-0001). |
| Reference lookups (states, broker types, agent types, broker statuses, task statuses) | Write (into UNIT-CMS-0005's schema) | Same ownership note as above. |
| Legacy source tables (`PP_Brokerage`, `PP_BrokerEmployees`, `PP_Agency`, `PP_Agent`, `PP_Agency_CGA`, `PP_TskData`, and the legacy reference lookup tables) | Read only | Read once, at migration time; never written back to. |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0005 | schema | Migration target — cannot run until that schema is designed and deployed. As of this writing UNIT-CMS-0005 is still `draft`; this unit's `design.md`/`interfaces/` proceed against the shape already fixed at capability level (CAP-CMS-0003's XD-0001–XD-0004), and will need reconciling against UNIT-CMS-0005's own `design.md`/`interfaces/` once authored — flagged as an open question below. |
| UNIT-CMS-0012 | contract | Consumes this unit's `MigrationLog` logging call; blocked from running its own reconciliation pass until this unit has migrated agencies (XD-0003). |
| Legacy `PolicyPlus` SQL Server database | external, read-only | Source of every record migrated. Availability window for the extract is an operational scheduling concern, not specified here. |

## Assumptions

- "Active" records, per CAP-CMS-0006/M1's baseline, means every extant legacy row in the `used_by_app: true` columns of the in-scope tables — not a subset filtered by the `History`/`history` disabled flag. A disabled legacy record is still migrated, with `disabled: true` carried forward (see R1/R3 state-class behaviour). This reading is confirmed by A4/A1's "every … record" phrasing and by there being no stated exclusion for disabled records; if the sponsor intended disabled/history records to be excluded from cutover, that is a change to M1's baseline, not this unit's requirements.
- Peak/expected volume for brokers, agents, and activity records is not separately stated in intake Q8 (only brokerages/agencies/CGAs were quantified as "low hundreds"). Assumed to be the same order of magnitude (low hundreds to low thousands, given each brokerage/agency typically has a handful of brokers/agents and an activity history), since nothing in the source material suggests otherwise. Flagged as an open question below for confirmation before `design.md` commits to a specific batching approach.
- This CMS deployment is single-tenant (the insurer Doxa) at go-live. Tenant isolation (R19) is satisfied by stamping one tenant identifier onto every migrated record rather than by any per-source-record tenant derivation, since the legacy system has no tenant concept of its own to migrate.
- Legacy timestamp fields with no explicit timezone are assumed to have been recorded in the legacy application server's local time zone; the actual zone is unresolved (see Open questions) and is needed before `design.md`/`interfaces/` can commit to a conversion rule.
- No concurrent write to the target schema's brokerage/agency/broker/agent/CGA/activity tables occurs during the migration window — this is an operational precondition (the target API is not yet live/accepting writes during cutover), not something this unit enforces itself.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | What time zone were legacy `PP_TskData` date/time columns (`inputDate`, `ModifiedDate`, `CompletedDate`, `FUDate`) recorded in? | R6's UTC-conversion rule in `design.md` | @MithunAcx | open — non-blocking; `design.md` will state the assumed zone as a labelled assumption if unanswered |
| 2 | Approximate legacy record counts for `PP_BrokerEmployees`, `PP_Agent`, and `PP_TskData` (brokers/agents/activity), not just brokerages/agencies/CGAs | R13's runtime-budget precision in `design.md` | @MithunAcx | open — non-blocking; the "low hundreds" order-of-magnitude assumption stands until corrected |
| 3 | CAP-CMS-0006's own open question 1 (M1/M2 not traced to a numbered intake `O<n>`) is inherited here unresolved — see `capability.md` Open questions | none for this unit; recorded for `ba-requirements-intake`'s next pass | @MithunAcx | open — non-blocking, per capability note |
