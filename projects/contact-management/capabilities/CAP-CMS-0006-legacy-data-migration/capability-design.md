---
capability: CAP-CMS-0006
title: Legacy Data Migration
project: CMS
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Legacy Data Migration — capability design

## Capability overview

**Capability:** CAP-CMS-0006 — Legacy Data Migration
**Outcome measures this design serves:** M1, M2
**Projected units:** 2

## Prospective units

| # | Prospective unit | Kind | Target repo | Owns | Serves |
|---|------------------|------|-------------|------|--------|
| U1 | legacy-data-etl | data | CMS-legacy-data-migration | MigrationLog entity (sole writer) | M1 |
| U2 | cga-reconciliation | data | CMS-legacy-data-migration | nothing of its own — appends to U1's MigrationLog via a shared logging contract | M2 |

No frontend unit is projected: this is a one-time, operator-run cutover, not an
end-user-facing capability.

## Cross-unit decisions (XD log)

| # | Decision | Rationale | Affects | Cited by |
|---|----------|-----------|---------|----------|
| XD-0001 | Both units write **into** CAP-CMS-0003's clean domain-model schema (its own XD-0001) — this capability defines no schema of its own for the migrated data, only for its own migration-tracking log | The target schema is settled by Partner Records Management; migration's job is populating it, not redefining it | U1, U2, and (cross-capability) CAP-CMS-0003 | _pending units_ |
| XD-0002 | U1 owns and is the sole writer of a `MigrationLog` entity, exposing a shared "record an outcome" logging contract; U2 calls that contract rather than writing the table itself, so both units' outcomes (`migrated`\|`skipped`\|`failed`, reason, timestamp) land in one log with exactly one owning unit | Gives M1 and M2 one common, queryable source for their validation reports, without two units writing the same table (a bad seam this design exists to catch before units are cut) | U1, U2 | _pending units_ |
| XD-0003 | U2 (CGA reconciliation) runs **after** U1 has migrated agencies, and reconciled CGA rows are linked to their agency's *new* (post-migration) id, never the legacy `pp_agency_id` | A reconciled CGA row needs a valid agency reference in the new schema, which does not exist until U1 has processed that agency | U1, U2 | _pending units_ |

## Shared database schema

`MigrationLog` is the one entity touched by both prospective units — **owned and
written solely by U1**; U2 appends to it only through U1's shared logging contract
(XD-0002), never by writing the table directly. This keeps exactly one owning unit per
entity while still letting both units' outcomes land in one queryable log.

### MigrationLog

| Field | Type | Nullable | Notes |
|-------|------|----------|-------|
| id | identifier | no | |
| sourceTable | string | no | the legacy table/entity type being migrated (e.g. `pp_brokerage`, `pp_agency_cga`) |
| sourceId | string | no | the legacy record's identifying key |
| outcome | enum(`migrated`, `skipped`, `failed`) | no | |
| reason | string | yes | populated for `skipped`/`failed`; null for a clean `migrated` row |
| processedBy | enum(`legacy-data-etl`, `cga-reconciliation`) | no | which unit's logging call produced this row — a provenance tag, not a second writer |
| processedAt | timestamp | no | |

**Constraints that carry a requirement:** every source record in scope (per M1's
baseline — all active legacy brokerage/agency/broker/agent/CGA/activity rows) must
produce exactly one `MigrationLog` row; a source record with zero rows is a gap the
validation report in § End-to-end flow diagrams below is built to catch.

## Unified API contract

Neither unit exposes an HTTP API — both are operator-run, one-time data jobs, not
request-serving services. There is no unified API contract to write for this capability.

## End-to-end flow diagrams

### Cutover sequence

```
U1 (legacy-data-etl)                                U2 (cga-reconciliation)
  |  migrate brokerages → CAP-CMS-0003 schema         |
  |  migrate agencies → CAP-CMS-0003 schema            |
  |  migrate brokers, agents, activity                 |
  |  write MigrationLog rows throughout                |
  |  (agencies fully migrated) ------------------------>|
  |                                                      |  scan legacy pp_agent for CGA-shaped rows (DR-1)
  |                                                      |  reconcile each into CAP-CMS-0003's Cga entity,
  |                                                      |  linked to the new agency id
  |                                                      |  write MigrationLog rows (processedBy: cga-reconciliation)
```

| Step | Unit | Touches |
|------|------|---------|
| Migrate core entities into the new schema | U1 | XD-0001 |
| Signal agencies are done (build-order gate) | U1 → U2 | XD-0003 |
| Identify and reconcile mis-inserted CGA rows | U2 | XD-0003 |
| Both log every outcome | U1, U2 | XD-0002 |

### Validation report

```
Operator                                MigrationLog (shared entity)
  |  query: count(source) vs count(MigrationLog rows) per sourceTable
  |------------------------------------------------------------------>|
  |  discrepancy → investigate before declaring cutover complete       |
  |<------------------------------------------------------------------|
```

| Step | Unit | Touches |
|------|------|---------|
| Reconcile source counts against `MigrationLog` | operator, reading U1+U2's shared log | XD-0002 |

## Build and sequencing order

| Order | Unit | Blocked by | Why |
|-------|------|------------|-----|
| 1 | U1 legacy-data-etl | CAP-CMS-0003's schema designed | Nothing to migrate into until the target schema exists |
| 2 | U2 cga-reconciliation | U1 has migrated agencies (XD-0003) | Reconciled CGA rows need a valid new-schema agency id |

## Handoff notes to unit design

### legacy-data-etl (U1)

**Inherits as fixed:**
- `XD-0001` — migrates into CAP-CMS-0003's schema, defines none of its own for business data
- `XD-0002` — owns the `MigrationLog` table and must expose a logging contract U2 calls

**Its own to decide:**
- Field-by-field legacy-to-new-schema mapping, batching/ordering within its own scope, rollback/retry behavior on partial failure
- The shape of the logging contract it exposes to U2 (in-process call, internal API, or queue)

### cga-reconciliation (U2)

**Inherits as fixed:**
- `XD-0001` — migrates into CAP-CMS-0003's schema
- `XD-0002` — records outcomes only via U1's logging contract, never by writing `MigrationLog` directly
- `XD-0003` — runs after U1's agency migration, links to new agency ids only

**Its own to decide:**
- The heuristic for identifying a CGA-shaped row inside legacy `pp_agent` (matching on `cga_agt`-equivalent naming and address fields, per `database-specification.md` §10's description of the bug), and how ambiguous matches are flagged for manual review rather than auto-reconciled

## Open questions

| # | Question | Owner | Blocks |
|---|----------|-------|--------|
| 1 | No count of how many `pp_agent` rows are actually CGA mis-inserts is known yet — `database-specification.md` flags the bug but does not quantify it. A discovery pass may be needed before U2's scope can be sized. | @MithunAcx | U2's `requirements.md` |

## Change log

| Date | Change | Units whose `design.md` must follow |
|------|--------|-------------------------------------|
