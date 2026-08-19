---
unit: UNIT-CMS-0011
updated: 2026-08-19
---

# Design — Legacy Data ETL

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

The migration runs as a sequence of ordered **phases**, one per legacy source table
group, each phase itself split into three stages: **stage** (a raw, one-time copy of
the legacy source's `used_by_app: true` columns into this project's own datastore),
**transform+load** (map the staged row into the target schema's shape and write it),
and **log** (record the outcome). Phases run in the dependency order R8 requires:
reference lookups first (nothing depends on them being absent), then brokerages
before brokers, then agencies before agents/CGAs/activity, then activity last (it
references both brokerages and agencies).

A phase advances to the next only once every staged row in it has a terminal
`MigrationLog` outcome — this is the mechanism behind R8's ordering guarantee and
behind XD-0003 (UNIT-CMS-0012 cannot start until the agency phase reports complete).
Because the compute model is serverless functions (`stack.md`), each phase is itself
processed in bounded batches sized to fit the runtime's own execution-time ceiling,
chained by the runtime's own scheduling/orchestration mechanism rather than by one
long-running process — this is what makes a crash mid-phase a resumable event rather
than a lost run.

**Alternative rejected:** a single pass reading directly from the legacy source and
writing straight into the target schema, with no staging step. Rejected because it
would make resumability depend on re-querying the legacy SQL Server for exactly the
rows not yet processed — a query the legacy schema's own defects (mixed `history`
conventions, no PK on `PP_Broker_Status`) make error-prone to express reliably — and
because it would make the validation report's count/checksum comparison (R11) race
against a live, possibly-still-changing legacy source instead of a frozen staged
snapshot. Staging first costs one extra copy of a low-hundreds/low-thousands dataset,
which is cheap at this volume (R13), in exchange for a stable, idempotent comparison
point.

**Alternative rejected for the `MigrationLog` contract (UNIT-CMS-0012 hand-off):** a
network API between the two units. Rejected because both units are one-time,
operator-run jobs in the same `target_repo`, never invoked concurrently (XD-0003
guarantees UNIT-CMS-0012 starts only after this unit's agency phase completes), and
introducing a live API for a caller that runs once adds an availability dependency
neither job needs. See `decisions/ADR-0001`.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Phase controller | Sequences phases in dependency order; advances a phase only once every staged row in it has a terminal log outcome; publishes the phase-completion signal | R8, R10 |
| Stager | Copies the legacy source's in-scope columns for one phase into a staging table, once, keyed by the legacy record's own key | R1–R7 (upstream of), R11 |
| Mapper/normalizer | Transforms a staged row into the target schema's shape; applies the domain-intent coercions carried forward from DR-2 (CGA phone → string), DR-3 (history flag → `disabled` boolean), DR-6 (CGA `Agency_ID` type reconciliation) | R1–R7 |
| Loader | Writes a transformed row into the target schema, resolving parent references to the parent's already-migrated target id | R1–R6, R8 |
| Logger | Writes the terminal `MigrationLog` row for a processed record; exposes the same write path as the logging call UNIT-CMS-0012 invokes | R9, R10, R20 |
| Validator | Produces the per-source-table count/checksum validation report once a phase (or the whole run) reaches completion | R11 |

## Flows

### Reference lookup migration — satisfies R7, R9

1. Stager copies every legacy reference-lookup source (states, broker types, agent
   types, broker statuses, task statuses) into its staging table.
2. Mapper/normalizer produces one target-schema lookup value per staged row, value
   set preserved as-is (no domain-intent coercion needed for lookups).
3. Loader writes each value into the target schema's lookup tables.
4. Logger writes one `MigrationLog` row per staged lookup value, outcome `migrated`.
5. Phase controller marks the lookup phase complete once every staged row has a
   terminal outcome, and advances to the brokerage phase.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 — a legacy lookup value has no valid mapping to a target enum member | Logged `failed`, reason `unmapped_lookup_value`; the phase still advances once every other staged row in it is terminal — a bad lookup value does not block brokerages/agencies. |
| Step 3 — target write rejected (e.g. a duplicate value the target schema's own uniqueness rule rejects) | Logged `failed`, reason cites the rejection; not retried automatically within the same run. |

### Brokerage and broker migration — satisfies R1, R2, R8, R9

1. Stager copies every legacy brokerage row (`used_by_app: true` columns) into its
   staging table.
2. Mapper/normalizer maps each staged brokerage into the target `Brokerage` shape,
   converting `History` to `disabled`.
3. Loader writes each transformed brokerage into the target schema.
4. Logger writes one `MigrationLog` row per brokerage, `migrated` on success.
5. Stager copies every legacy broker row into its staging table.
6. Mapper/normalizer maps each staged broker into the target `Broker` shape,
   resolving `ProducerNumber` to its parent brokerage's **target** id via that
   brokerage's `MigrationLog` row.
7. Loader writes each transformed broker, linked to the resolved parent.
8. Logger writes one `MigrationLog` row per broker.
9. Phase controller marks the brokerage/broker phase complete once every staged row
   across both source tables has a terminal outcome.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 — brokerage row fails target validation (e.g. an unmappable required field) | Logged `failed`; not written to the target schema; every broker referencing it is later logged `skipped`, reason `parent_not_migrated` (step 6). |
| Step 3 — target write rejected mid-batch | Rows already committed keep their `migrated` log rows; rows not yet attempted remain unlogged and are picked up by the next run (idempotency walk, below) — no row is logged `migrated` before its target write is confirmed. |
| Step 6 — broker references a `ProducerNumber` with no corresponding `MigrationLog` row at all (never staged, or staging skipped it) | Logged `skipped`, reason `parent_not_migrated` — treated identically to an explicitly-failed parent, since from the broker's perspective the absence is indistinguishable from a failure. |

### Agency, agent, and CGA migration — satisfies R3, R4, R5, R8, R9

1. Stager copies every legacy agency row into its staging table.
2. Mapper/normalizer maps each into the target `Agency` shape (`history` → `disabled`).
3. Loader writes each transformed agency.
4. Logger writes one `MigrationLog` row per agency.
5. Phase controller confirms **every** agency row has a terminal outcome, then
   publishes the phase-completion signal that XD-0003 requires before UNIT-CMS-0012
   may run.
6. Stager copies every legacy agent row and every legacy CGA row into their own
   staging tables.
7. Mapper/normalizer maps each staged agent into the target `Agent` shape, resolving
   its parent agency via that agency's `MigrationLog` row; maps each staged CGA into
   the target `Cga` shape, coercing the legacy numeric `Phone` value to a string
   (falling back to null with a note if unparseable) and resolving the CGA's
   `Agency_ID` (stored as text in the legacy source) to the same parent agency,
   regardless of the type mismatch against the agent table's own `Agency_ID`.
8. Loader writes each transformed agent/CGA, linked to its resolved parent.
9. Logger writes one `MigrationLog` row per agent and per CGA.
10. Phase controller marks the agent/CGA phase complete once every staged row in both
    source tables has a terminal outcome.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 — agency row fails validation | Logged `failed`; every agent/CGA/activity row referencing it is later `skipped`, reason `parent_not_migrated`; the phase-completion signal in step 5 still fires once every *other* agency row is terminal — one failed agency does not block the signal UNIT-CMS-0012 waits on. |
| Step 7 — a CGA's `Agency_ID` cannot be resolved to any migrated agency (no match found after normalizing both the text and int forms) | Logged `failed`, reason `agency_id_unresolvable` — never guessed against the nearest match. |
| Step 7 — CGA `Phone` unparseable | Logged `migrated` with `phone` null and a note `phone_unparseable` — phone is not identity-bearing for a CGA, so the record is not held back over it (see requirements.md Behaviour detail). |

### Activity migration — satisfies R6, R8, R9

1. Stager copies every legacy activity row into its staging table.
2. Mapper/normalizer maps each into the target `Activity` shape, preserving
   `UsrName`, entered/modified/completed/follow-up dates exactly as recorded,
   converting each to UTC per the assumed legacy time zone (requirements.md
   Assumptions; revisited if Open question 1 is answered).
3. Loader writes each transformed activity, resolving its parent (brokerage or
   agency, by the record's own polymorphic parent reference) via that parent's
   `MigrationLog` row.
4. Logger writes one `MigrationLog` row per activity record.
5. Phase controller marks the activity phase — and the whole run — complete once
   every staged row across every phase has a terminal outcome.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 — a date field is missing where the target schema requires one (e.g. no `inputDate`) | Logged `failed`, reason `missing_required_date`; not written. |
| Step 3 — parent brokerage/agency not migrated | Logged `skipped`, reason `parent_not_migrated`. |

### CGA-reconciliation logging call — satisfies R10

1. UNIT-CMS-0012 identifies a `pp_agent` row it has reconciled into the target `Cga`
   entity.
2. UNIT-CMS-0012 invokes this unit's logging write path directly (see Contracts),
   supplying `sourceTable: pp_agent`, the legacy row's key, the outcome, and its own
   unit tag `processedBy: cga-reconciliation`.
3. Logger writes the row into the same `MigrationLog` store this unit owns.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 3 — a row already exists for that `(sourceTable, sourceId)` key | Rejected at the storage level (uniqueness constraint, see State and idempotency) rather than silently overwritten — UNIT-CMS-0012 must treat this as "already recorded," not retry with a different outcome. |

### Validation report — satisfies R11

1. Once a phase (or the full run) reaches `completed`, the Validator compares, per
   legacy source table: the row count and a field-level checksum of the staged
   snapshot against the count and content of that table's `migrated` `MigrationLog`
   rows (plus `skipped`/`failed` counts, reported separately, never folded into the
   "migrated" figure).
2. Any discrepancy — a staged row with no terminal `MigrationLog` row at all — is
   surfaced as the report's headline finding, since it represents a row the phase
   controller's own completion check should never have permitted through.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 1 run against a phase not yet `completed` | The report is labelled against its actual (incomplete) state rather than presented as a final figure. |

## Data model

Entities, keys, relationships, ownership, retention. The machine-readable form
lives in `interfaces/*.sql` and `interfaces/*.schema.json`.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| MigrationLog | `(sourceTable, sourceId)` unique; own identifier | `outcome`, `reason`, `processedBy`, `processedAt` (capability-level shape, XD-0002) — extended at this unit's own design level with one additive field, `targetId`, nullable: the newly-created target-schema record's id, needed so a later phase can resolve a parent by reading this unit's own log rather than re-querying the target schema by legacy key (which the target schema has no reason to retain). This extends, and does not alter or remove, the fields the capability design fixed as shared. | 7 years, insert-only (R20) |
| Staging tables (one per legacy source table in scope: brokerage, broker, agency, agent, CGA, activity, and each reference lookup) | the legacy source's own key, copied as-is | A bounded, one-time raw copy of the `used_by_app: true` columns only — never the columns marked `used_by_app: false` in `cms-data-schema.yaml`, which are out of scope for both the app and this migration. | Retained through cutover and the validation report's sign-off, then dropped — an operational/infra step, not a requirement this unit's own runtime behavior needs to enforce. |
| Brokerage, Broker, Agency, Agent, Cga, Activity, reference lookups (target) | target-schema id, owned by UNIT-CMS-0005 | Written by the Loader; shape fixed by CAP-CMS-0003's XD-0001 (clean domain model), XD-0003 (`disabled` boolean), XD-0004 (address shape) | Owned by UNIT-CMS-0005 — this unit writes, never retains its own copy of the business record beyond the staging table above. |

## Contracts

What this unit exposes and consumes. Each row must correspond to a file in
`interfaces/`.

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Staging tables (brokerage, broker, agency, agent, CGA, activity, reference lookups) | storage contract | `interfaces/0001_staging_tables.sql` | R1–R7, R11 |
| MigrationLog table | storage contract | `interfaces/0002_migration_log.sql` | R9, R10, R15, R20 |
| MigrationLog entry shape | data contract | `interfaces/migration-log-entry.schema.json` | R9, R10 |
| Phase-completion / ordering signal | async job contract | `interfaces/asyncapi.yaml` | R8, R10 (the XD-0003 signal UNIT-CMS-0012 waits on) |
| Validation report shape | data contract | `interfaces/validation-report.schema.json` | R11 |

## State and idempotency

**State machine — per source record.** `pending → staged → migrated` (terminal) |
`pending → staged → failed` (terminal) | `pending → staged → skipped` (terminal,
parent not migrated). Invariant: every staged record reaches **exactly one** terminal
outcome. Enforced by a uniqueness constraint on `MigrationLog`'s `(sourceTable,
sourceId)` — a second write attempt for the same key is rejected by the store, not by
an application-level check-then-insert, which is the guarantee a read-then-write
would silently lose under a retried or re-run job.

**State machine — per phase (run-level).** `not-started → in-progress → completed` |
`in-progress → halted` (dependency/target store unreachable) → resumes to
`in-progress`. Invariant: a phase reaches `completed` only when every one of its
staged records has a terminal outcome — checked by the Validator before the Phase
controller advances or publishes the phase-completion signal, never asserted by the
controller's own bookkeeping alone.

**Idempotency walk.** Every path that could perform a migration write, and what it
collapses to:

| Path | Collapses to |
|---|---|
| First attempt at a record | Target write, then `MigrationLog` write, in that order. |
| Job re-run after a full prior completion | Every `(sourceTable, sourceId)` already has a terminal `MigrationLog` row; the record is skipped without a second target write. |
| Job re-run after a crash mid-phase | Records with a terminal log row are skipped; records without one are re-attempted from scratch — safe because no `migrated` row is ever written before the target write is confirmed committed (see partial-failure behaviour above), so "no log row" reliably means "not yet durably done." |
| Two invocations of the same phase overlapping (accidental double-trigger; guarded against operationally, R16) | The `MigrationLog` uniqueness constraint accepts exactly one insert per key; the second invocation's write for the same key is rejected at the storage level, not merely discouraged by scheduling. |
| UNIT-CMS-0012's logging call arriving twice for the same `pp_agent` row (its own retry) | Same uniqueness constraint; UNIT-CMS-0012 is responsible for treating a rejection as "already recorded," per Flow "CGA-reconciliation logging call" above. |

The key `(sourceTable, sourceId)` is fixed before execution — it is the legacy
record's own identity, never anything computed during the run — so it satisfies the
requirement that an idempotency key depend only on values known in advance.

**Concurrency matrix.**

| Two things at once | Who wins / what holds |
|---|---|
| Two invocations process the same source record simultaneously | Storage-level uniqueness constraint on `MigrationLog(sourceTable, sourceId)` accepts one insert; the other is rejected — **enforced at the storage level**, not by application logic, since a read-then-write here would lose the guarantee under a race. |
| UNIT-CMS-0011's agency phase and UNIT-CMS-0012's reconciliation pass overlap in time (should never happen per XD-0003, modeled defensively) | UNIT-CMS-0012 must observe the agency's `MigrationLog` row as `migrated` before writing a `Cga` row referencing that agency's target id; the target schema's own referential-integrity constraint on the `Cga.agencyId` reference additionally rejects a write pointing at an id that does not yet exist, even if UNIT-CMS-0012's own check were skipped — **storage-level enforcement**, not application discipline alone. |
| A validation-report read arrives while a phase is still `in-progress` | The report is labelled against the phase's actual, incomplete state (see Flow "Validation report," failure path) rather than presenting a partial count as final. |

**Answers that can change.** N/A in the usual sense — the legacy source is read-only
and frozen for the duration of the migration window (an operational precondition,
requirements.md Assumptions), so no upstream answer about the past is revised
mid-run. The one residual case: if a legacy record is corrected in the source
*after* this unit has already logged it `migrated`, that correction is invisible to
this run. Re-processing it is not automatic — it requires a deliberate, scoped
re-run against that specific `(sourceTable, sourceId)` (clearing its log row under
change control) or a `ba-change-request` if the correction is material, never a
silent overwrite on the next full run.

**Event durability.** The phase-completion signal (the async contract UNIT-CMS-0012
waits on) is derived from, and only published after, the Validator's own confirmation
that every staged record in that phase has a durably-committed terminal
`MigrationLog` row — it is never emitted directly by in-flight processing code. A
crash between the last record's log write and the signal's publication simply leaves
the phase one confirmation check short of `completed`; the next scheduled check
re-evaluates from the (already durable) `MigrationLog` rows and publishes once the
condition is actually met, so the signal can be lost and safely re-derived, but it
can never be published for a state that was not truly reached.

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | This deployment is single-tenant at go-live (requirements.md Assumptions). Every operation — every staging, target, and `MigrationLog` write, **and** every read, including the Validator's own count/checksum queries against staging and `MigrationLog` (Flow "Validation report") and UNIT-CMS-0012's logging-call reads — is made under a credential with the store's row-level security context set to that one tenant identifier, so the RLS policy applies uniformly to `SELECT` as well as to writes, the same policy every other unit relies on (`stack.md`), with no read-path carve-out. |
| authn/authz | No end-user session ever calls this unit. It runs under a dedicated migration-operator credential (R18), distinct from any staff session and from UNIT-CMS-0005's own service credential, retired once cutover is accepted. UNIT-CMS-0012's logging call authenticates as its own service identity, authorized only to invoke the logging write path — never the staging or target write paths, which remain this unit's alone. |
| validation | Every mapped field is validated against the target schema's own constraints before the Loader writes it (R1–R7's failure tables); a value that fails is never written and never silently coerced, except the two named domain-intent coercions (DR-2 phone-to-string, DR-3 history-to-boolean) which are the point of the migration, not a validation shortcut. |
| error model | `MigrationLog.reason` carries a stable, closed set of reason codes (`unmapped_lookup_value`, `unrecognized_history_value`, `parent_not_migrated`, `agency_id_unresolvable`, `phone_unparseable`, `missing_required_date`, plus a generic `target_write_rejected` for anything the target schema's own constraints reject) — never free-form text that might carry personal data, per R22. |
| observability | Per-phase and per-run metrics: records staged/migrated/skipped/failed per source table, phase duration, run outcome. Structured log fields: `sourceTable`, `sourceId`, outcome, reason code, run id, phase name — never a personal-data field (R21). |
| performance | No p95/p99 — there is no synchronous caller (R12). Runtime budget is bounded by R13's volume assumption; each phase's batch size is chosen to fit the compute runtime's execution-time ceiling (`stack.md`'s serverless model), not to a fixed record count, so the design tolerates the "brokers/agents/activity volume unconfirmed" open question without a redesign. |
| migration/backfill | This unit **is** the migration (R24) — a one-time, non-reversible-in-place operation. Reversal is an infra-level restore of the target schema from a pre-migration snapshot, not an inverse job this unit runs. |
| feature flag | N/A — an operator-invoked one-time job has no "off" state distinct from "not yet run" (R25). |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Broker/agent/activity volumes are not separately quantified (Open question 2) | A runtime-budget estimate could be wrong by an order of magnitude | Batch sizing is bounded by the compute runtime's execution ceiling rather than a fixed record count (see Cross-cutting, performance), so an underestimate slows completion rather than breaking the design; accepting, not mitigating away, since the actual figure is outside this unit's control. |
| Legacy activity timestamp time zone is unconfirmed (Open question 1) | Follow-up/entered/completed dates could be off by the zone's offset (up to a day at boundaries) | Documented as a labelled assumption (requirements.md); the validation report's checksum comparison would surface a systematic date-field mismatch if the assumption is wrong, giving a detection path even before the question is formally answered. |
| CGA `Agency_ID` type mismatch (DR-6) produces an unresolvable reference for some rows | Those CGA records are `failed` rather than migrated, understating M1's completeness until resolved | Logged with a specific, distinguishable reason (`agency_id_unresolvable`) rather than silently dropped or guess-linked, so the validation report makes the gap visible and actionable rather than hidden inside a generic failure count. |
| Legacy source becomes unreachable mid-run (scheduled maintenance window overruns, network issue) | Migration stalls until the source is reachable again | Accepted — this is a scheduled, operator-supervised one-time job; a stall is visible in observability (phase duration) and resumable without data loss, per the idempotency walk. |

## Decisions

Anything consequential gets an ADR in `decisions/`. List them here.

| ADR | Decision |
|---|---|
| ADR-0001 | `MigrationLog` is a shared storage contract (a table both units write into directly, under a uniqueness constraint) rather than a network API between UNIT-CMS-0011 and UNIT-CMS-0012. |

## Requirement coverage

Every R-ID in `requirements.md` must appear here.

| R-ID | Covered by |
|------|-----------|
| R1 | Flow "Brokerage and broker migration," Data model |
| R2 | Flow "Brokerage and broker migration" |
| R3 | Flow "Agency, agent, and CGA migration" |
| R4 | Flow "Agency, agent, and CGA migration" |
| R5 | Flow "Agency, agent, and CGA migration" (CGA sub-steps) |
| R6 | Flow "Activity migration" |
| R7 | Flow "Reference lookup migration" |
| R8 | Approach (phase ordering); Flows "Brokerage and broker migration," "Agency, agent, and CGA migration," "Activity migration"; State and idempotency (per-phase state machine) |
| R9 | Every flow's Logger step; State and idempotency (per-record state machine, concurrency matrix) |
| R10 | Flow "CGA-reconciliation logging call"; Contracts (MigrationLog table + entry shape); ADR-0001 |
| R11 | Flow "Validation report"; Data model (staging tables) |
| R12 | Cross-cutting, performance |
| R13 | Cross-cutting, performance; Risks (volume risk) |
| R14 | Approach (fixed, known-in-advance source volume — no surge concept) |
| R15 | State and idempotency (idempotency walk, key derivation) |
| R16 | Concurrency matrix (defensive treatment despite the operational precondition) |
| R17 | Cross-cutting (no caller-facing rate limit; internal batch process) |
| R18 | Cross-cutting, authn/authz |
| R19 | Cross-cutting, tenant isolation |
| R20 | Data model (MigrationLog retention); Cross-cutting, error model |
| R21 | Cross-cutting, observability |
| R22 | Cross-cutting, error model (reason codes never carry personal data) |
| R23 | Data model (staging table retention through cutover only); Cross-cutting, migration/backfill |
| R24 | Cross-cutting, migration/backfill |
| R25 | Cross-cutting, feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
