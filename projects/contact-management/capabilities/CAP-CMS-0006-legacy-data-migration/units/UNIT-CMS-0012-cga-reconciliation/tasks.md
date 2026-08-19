---
unit: UNIT-CMS-0012
change: original
---

# Tasks — CGA Reconciliation

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate server types/stubs from `interfaces/openapi.yaml` for the run-trigger, run-read, candidate-list, and candidate-resolution operations — satisfies R1, R4, R7, R9, R10, R11, R14, R20, R22, R25
- [ ] Generate the shared `Error` envelope type and the closed error-code enum from `interfaces/openapi.yaml` — satisfies R1, R4, R9, R14, R20, R22

## Data

Schema and migration tasks from `interfaces/*.sql`, plus any backfill the design
flagged as its own task.

- [ ] Apply the `reconciliation_candidate` table, its uniqueness constraint on (tenant, legacy agent id), and its status index from `interfaces/001_create_reconciliation_candidate.sql` — satisfies R8, R12, R19, R23
- [ ] Apply the `reconciliation_run` table and its one-active-run-per-tenant unique partial index from `interfaces/001_create_reconciliation_candidate.sql` — satisfies R14, R20
- [ ] Apply the row-level security policies on both tables from `interfaces/001_create_reconciliation_candidate.sql` — satisfies R23
- [ ] No backfill task — both tables are populated only by this unit's own pass at cutover, per the migration file's closing note

## Implementation

- [ ] Implement the gate checker that reads UNIT-CMS-0011's agency-migration completion signal before allowing a run to start — satisfies R1
- [ ] Implement run-start: reject with `agency_migration_incomplete` if the gate check fails, reject with `run_already_in_progress` if the store's one-active-run constraint is violated, otherwise create a `running` run record — satisfies R1, R14, R20
- [ ] Implement the discovery scanner that reads every in-scope legacy `pp_agent` row not already in a terminal (`reconciled`/`skipped`) processing state — satisfies R2, R8, R12
- [ ] Implement the CGA-shaped-row heuristic (naming and address-field matching per DR-1) producing a high-confidence, ambiguous, or not-CGA classification for each row — satisfies R2
- [ ] Implement candidate creation: on first sight of a legacy row, create its `reconciliation_candidate` row at `pending` before classification runs, so a crash between "seen" and "classified" leaves it at `pending` rather than absent — satisfies R8, R12
- [ ] Implement reconciliation of a high-confidence match: create the `Cga` record in UNIT-CMS-0005's schema, linked to the agency's new (post-migration) id, and set the candidate to `reconciled` — satisfies R3
- [ ] Implement the missing-agency case: when a high-confidence match's target agency has no new id yet, set the candidate to `failed` with a missing-agency reason, eligible for re-run once the agency exists — satisfies R9
- [ ] Implement the not-CGA case: set the candidate to `skipped` for a row the heuristic does not match — satisfies R5
- [ ] Implement the ambiguous-match case: set the candidate to `flagged` for manual review, and leave it `flagged` on a later run if still unresolved — satisfies R4, R10
- [ ] Implement candidate listing filtered by processing state, cursor-paginated — satisfies R4, R10, R25
- [ ] Implement resolution recording: accept `is_cga`/`is_not_cga` only from a `flagged` candidate, reject with `candidate_not_resolvable` otherwise, and apply the resolution on the next run (`reconciled` or `skipped`, never re-flagged) — satisfies R4, R11
- [ ] Implement the outcome reporter that calls UNIT-CMS-0011's logging contract for every terminal outcome (`migrated`/`skipped`/`failed`) tagged `processedBy: cga-reconciliation`, retrying on failure — satisfies R6, R13
- [ ] Implement retry accounting: if the logging call never succeeds for a row after retry, the row's own outcome still stands and the row is counted toward the run's logging-gap total — satisfies R13
- [ ] Implement run completion: mark the run `completed` once every in-scope row has reached a terminal or retry-eligible state, with its summary counts (evaluated, reconciled, flagged, skipped, failed, logging gaps) — satisfies R7
- [ ] Implement run-status read, returning `running` state before completion and the full summary once `completed` — satisfies R7, R25

## Validation and errors

- [ ] `unauthenticated` returned for a missing or invalid bearer token on every operation — satisfies R22
- [ ] `forbidden` returned when the caller's token lacks the migration-execution role on run-trigger and candidate-resolution operations — satisfies R22
- [ ] `run_already_in_progress` returned on a concurrent run-start attempt — satisfies R14, R20
- [ ] `agency_migration_incomplete` returned on a run-start attempt before UNIT-CMS-0011 signals agency migration complete — satisfies R1
- [ ] `invalid_request` returned for a malformed resolution value — satisfies R4, R11
- [ ] `candidate_not_resolvable` returned for a resolution attempt on a candidate not currently `flagged` — satisfies R4, R11
- [ ] `not_found` returned for an unknown run id or candidate id — satisfies R7, R4

## Observability

- [ ] Emit a structured log entry per candidate outcome naming the candidate id, legacy row id, outcome, and reason (for `failed`/`skipped`), with no full field values from the source row — satisfies R24, R25, R26
- [ ] Emit the run summary as a structured, queryable record on completion, distinct from any single candidate's log entry — satisfies R7, R25
- [ ] Confirm no log line, metric label, or error message anywhere in this unit carries a personal-data field value from a `pp_agent` row or a `Cga` record beyond the identifying keys already carried in `MigrationLog` — satisfies R26

## Tests

- [ ] Unit tests for the gate checker: run rejected before agencies are migrated, run allowed once they are — satisfies R1
- [ ] Unit tests for the discovery/classification split: high-confidence, ambiguous, and not-CGA paths each produce the correct candidate status — satisfies R2, R3, R4, R5
- [ ] Unit tests for the missing-agency case (R9) and its later re-run once the agency exists
- [ ] Unit tests for the idempotency walk: clean re-run, crash-mid-classification re-run, and concurrent second invocation all collapse to a single `Cga` record and a single active run — satisfies R8, R12, R14, R19, R20
- [ ] Unit tests for manual review: flag → re-flag when unresolved (R10), flag → resolved → processed correctly on next run (R11), and a resolution attempt on an already-resolved or not-yet-flagged candidate rejected (R4, R11)
- [ ] Unit tests for the logging-contract retry path, including the case where it never succeeds and the row is counted as a logging gap — satisfies R6, R13
- [ ] Unit tests confirming tenant isolation on every read and write to `reconciliation_candidate` and `reconciliation_run` — satisfies R23
- [ ] Contract tests generated from `interfaces/openapi.yaml` pass for every operation and every enumerated error code
- [ ] Contract tests generated from `interfaces/001_create_reconciliation_candidate.sql` confirm the uniqueness and one-active-run constraints reject a duplicate insert rather than relying on application-level checks — satisfies R8, R12, R14, R19, R20

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Gate checker implementation; run-start implementation; `agency_migration_incomplete` validation task; gate-checker tests |
| R2 | Discovery scanner implementation; heuristic implementation; classification tests |
| R3 | High-confidence reconciliation implementation; classification tests |
| R4 | Ambiguous-match implementation; candidate listing; resolution recording; `invalid_request`/`candidate_not_resolvable` validation; manual-review tests |
| R5 | Not-CGA implementation; classification tests |
| R6 | Outcome reporter implementation; logging-contract retry tests |
| R7 | Run completion implementation; run-status read implementation; run summary observability task; `not_found` validation |
| R8 | Candidate-creation implementation; idempotency-walk tests; data-migration uniqueness task; contract tests on the uniqueness constraint |
| R9 | Missing-agency implementation; missing-agency tests |
| R10 | Ambiguous-match implementation; candidate listing; manual-review tests |
| R11 | Resolution recording implementation; `candidate_not_resolvable` validation; manual-review tests |
| R12 | Candidate-creation implementation; idempotency-walk tests; data-migration uniqueness task; contract tests on the uniqueness constraint |
| R13 | Retry-accounting implementation; logging-contract retry tests |
| R14 | Run-start implementation; `run_already_in_progress` validation; idempotency-walk tests; data-migration one-active-run task; contract tests on the run constraint |
| R15 | N/A per requirements.md — no task |
| R16 | N/A per requirements.md — no task |
| R17 | Covered implicitly by the discovery scanner reading the full in-scope table (implementation task); no dedicated performance task, per requirements.md's own bound |
| R18 | N/A per requirements.md — no task |
| R19 | Data-migration uniqueness task; idempotency-walk tests; contract tests on the uniqueness constraint |
| R20 | Run-start implementation; `run_already_in_progress` validation; data-migration one-active-run task; contract tests on the run constraint |
| R21 | N/A per requirements.md — no task (no external caller) |
| R22 | `unauthenticated`/`forbidden` validation tasks; authz tests implicit in contract tests |
| R23 | RLS-policy data task; tenant-isolation tests |
| R24 | Structured-log observability task |
| R25 | Candidate-listing implementation; run-status read implementation; structured-log and run-summary observability tasks |
| R26 | Structured-log observability task; personal-data confirmation observability task |
| R27 | N/A per requirements.md — no task (inherits UNIT-CMS-0011/UNIT-CMS-0005 retention obligations) |
| R28 | Covered by the unit's overall scope as a one-time migration job (Implementation section); no dedicated reversal task, per requirements.md and design.md Risks — reversal is out of scope once cutover is declared complete |
| R29 | N/A per requirements.md — no task |
