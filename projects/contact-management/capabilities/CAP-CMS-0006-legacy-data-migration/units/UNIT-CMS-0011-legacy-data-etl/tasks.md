---
unit: UNIT-CMS-0011
change: original
---

# Tasks — Legacy Data ETL

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate the staging-table schema types/bindings from `interfaces/0001_staging_tables.sql` — satisfies R1, R2, R3, R4, R5, R6, R7
- [ ] Generate the `migration_log` schema types/bindings from `interfaces/0002_migration_log.sql` — satisfies R9, R10, R15, R20
- [ ] Generate the shared entry-payload type from `interfaces/migration-log-entry.schema.json`, used by both this unit's own logging writes and UNIT-CMS-0012's logging call — satisfies R9, R10
- [ ] Generate the publisher binding and payload type for the `cms.migration.phase.completed` channel from `interfaces/asyncapi.yaml` — satisfies R8, R10
- [ ] Generate the validation-report type from `interfaces/validation-report.schema.json` — satisfies R11

## Data

Schema and migration tasks from `interfaces/*.sql`, plus any backfill the design
flagged as its own task.

- [ ] Apply migration `interfaces/0001_staging_tables.sql`, including its row-level security policies, against the target datastore — satisfies R1, R2, R3, R4, R5, R6, R7, R19
- [ ] Apply migration `interfaces/0002_migration_log.sql`, including its row-level security policy and the uniqueness constraint on `(tenant_id, source_table, source_id)` — satisfies R9, R15, R19, R20
- [ ] Load every in-scope legacy source table's `used_by_app: true` columns into the matching staging table, one time, keyed by the legacy record's own key — satisfies R1, R2, R3, R4, R5, R6, R7 (this is the migration's own backfill; it is reversible only by re-staging, never automatic — see design.md § Cross-cutting, migration/backfill)

## Implementation

- [ ] Implement the reference-lookup phase: map every staged lookup value into the target schema's lookup shape with the same value set as its legacy source, write it, and log its outcome — satisfies R7, R9
- [ ] Implement the brokerage transform-and-load step: map `disabled` from the legacy history-flag convention, write the target `Brokerage` record, and log its outcome — satisfies R1, R9
- [ ] Implement the broker transform-and-load step, resolving each broker's parent brokerage via that brokerage's `migration_log` row before writing, and log the outcome — satisfies R2, R8, R9
- [ ] Implement the phase controller's brokerage/broker completion check (every staged row across both tables has a terminal outcome) before advancing — satisfies R8
- [ ] Implement the agency transform-and-load step: map `disabled` from the legacy history-flag convention, write the target `Agency` record, and log its outcome — satisfies R3, R9
- [ ] Implement the phase controller's agency-only completion check and publish the `cms.migration.phase.completed` event for the agency phase once every agency row is terminal — satisfies R8, R10
- [ ] Implement the agent transform-and-load step, resolving each agent's parent agency via that agency's `migration_log` row before writing, and log the outcome — satisfies R4, R8, R9
- [ ] Implement the CGA transform-and-load step: coerce the staged legacy phone value to a string (or null with the defined note if unparseable), resolve the CGA's legacy `Agency_ID` value against the migrated agencies regardless of the source type mismatch, write the target `Cga` record linked to the new agency id, and log the outcome — satisfies R5, R8, R9
- [ ] Implement the phase controller's agent/CGA completion check before advancing — satisfies R8
- [ ] Implement the activity transform-and-load step: preserve `UsrName`, entered/modified/completed/follow-up dates exactly, convert timestamps to UTC per the assumed legacy time zone, resolve the polymorphic parent (brokerage or agency) via its `migration_log` row, write the target `Activity` record, and log the outcome — satisfies R6, R8, R9
- [ ] Implement the phase controller's activity-and-whole-run completion check — satisfies R8
- [ ] Implement the `migration_log` write path as a callable operation both this unit's own steps and UNIT-CMS-0012 invoke, rejecting a second write for an already-recorded `(source_table, source_id)` at the storage level — satisfies R9, R10, R15
- [ ] Implement the validation report generator: per source table, compare the staged count/checksum against `migrated` `migration_log` rows (via `targetId`), reporting `skipped`/`failed` counts separately and any unaccounted staged row as the headline finding — satisfies R11

## Validation and errors

- [ ] Reject and log `failed` with reason `unmapped_lookup_value` a staged lookup row with no valid target-schema mapping, without halting the rest of the phase — satisfies R7
- [ ] Reject and log `failed` with reason `unrecognized_history_value` a staged brokerage/agency row whose history-flag value is outside the two known legacy conventions, rather than guessing a boolean — satisfies R1, R3
- [ ] Log `skipped` with reason `parent_not_migrated` a broker, agent, CGA, or activity row whose parent brokerage/agency has no `migrated` `migration_log` row (missing or itself `failed`), without writing it as an orphan — satisfies R2, R4, R5, R6
- [ ] Log `failed` with reason `agency_id_unresolvable` a CGA row whose legacy `Agency_ID` cannot be resolved to any migrated agency after normalizing both the text and int forms — satisfies R5
- [ ] Log a CGA row `migrated` with `phone` null and a `phone_unparseable` note when the staged legacy phone value cannot be parsed to a string phone number — satisfies R5
- [ ] Log `failed` with reason `missing_required_date` an activity row missing a date field the target schema requires — satisfies R6
- [ ] Ensure no `migration_log` row is ever written with outcome `migrated` before its corresponding target-schema write is confirmed committed, so a crash between the two leaves the record safely re-attemptable — satisfies R9, R15
- [ ] Halt the run cleanly and report which source tables/records were not yet attempted when the target datastore becomes unreachable mid-run, without logging a `migrated` outcome for anything not yet confirmed — satisfies R9

## Observability

- [ ] Emit per-phase and per-run metrics: records staged/migrated/skipped/failed per source table, phase duration, run outcome — satisfies R21
- [ ] Emit structured log fields `sourceTable`, `sourceId`, outcome, reason code, run id, and phase name on every processed record, with no personal-data field ever included — satisfies R21, R22

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Brokerage transform-and-load; unrecognized_history_value handling |
| R2 | Broker transform-and-load; parent_not_migrated handling |
| R3 | Agency transform-and-load; unrecognized_history_value handling |
| R4 | Agent transform-and-load; parent_not_migrated handling |
| R5 | CGA transform-and-load; agency_id_unresolvable and phone_unparseable handling |
| R6 | Activity transform-and-load; missing_required_date and parent_not_migrated handling |
| R7 | Reference-lookup phase; unmapped_lookup_value handling |
| R8 | Phase controller completion checks (all four); agency-phase event publication |
| R9 | Every transform-and-load task's logging step; migration_log write path; crash-ordering and unreachable-target tasks |
| R10 | migration_log write path (shared with UNIT-CMS-0012); agency-phase event publication; asyncapi.yaml codegen |
| R11 | Validation report generator; validation-report.schema.json codegen |
| R12 | No task — N/A per requirements.md (no request-serving surface; nothing to build for an SLO that does not apply) |
| R13 | Data-loading and phase tasks' batching is sized to the compute runtime's own execution-time ceiling per design.md, not a separately built feature — no dedicated task beyond the phase implementation tasks above |
| R14 | No task — N/A per requirements.md (fixed, known-in-advance source volume; no surge behaviour to build) |
| R15 | migration_log write path; crash-ordering task |
| R16 | No task — N/A per requirements.md (single-instance run is an operational precondition, not something this unit builds); the migration_log uniqueness constraint (Data section) is the defensive backstop, already covered there |
| R17 | No task — N/A per requirements.md (no caller-facing rate limit on an internal batch process) |
| R18 | No task — N/A here; provisioning the dedicated migration-operator credential and retiring it after cutover is an operational/engineering-repo access-control step, not a build task this unit's own code performs |
| R19 | Staging-table and migration_log migration tasks (row-level security policies) |
| R20 | migration_log migration task (insert-only schema, retention); migration_log write path |
| R21 | Observability tasks (metrics, structured log fields) |
| R22 | Observability tasks (no personal-data field in logs); reason-code tasks (closed set, never free text) |
| R23 | No task — N/A here; target-schema retention/erasure is UNIT-CMS-0005's own build, not this unit's |
| R24 | Staging load task (labelled as this unit's own backfill, reversible only by re-staging) |
| R25 | No task — N/A per requirements.md (no feature-flag surface for a one-time operator-invoked job) |
