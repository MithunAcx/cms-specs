---
unit: UNIT-CMS-0012
updated: 2026-08-18
---

# Design — CGA Reconciliation

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

This unit is a bounded, operator-triggered data-quality pass, not a request-serving
service — it runs once (with re-runs tolerated, see State and idempotency) against a
known-bounded legacy data set. It is exposed through a small operator-facing API
(`engineering.api.applicable: true`, per its `kind: data`) rather than no API at all,
because two things genuinely need external triggering and inspection that a bare batch
process cannot provide on its own: starting/observing a run, and a human resolving an
ambiguous match (R4, R10, R11). The API is not a public or partner-facing surface — it
is the same class of privileged, operator-only surface UNIT-CMS-0011's own execution
trigger is, per R22.

The alternative considered was a pure fire-and-forget batch job with no queryable state
at all, discoverable only through `MigrationLog`. This was rejected because `MigrationLog`
belongs to UNIT-CMS-0011 (XD-0002) and is written only through its logging contract — it
has no concept of "flagged, awaiting manual review" as a *pending* state, only terminal
per-row outcomes. Manual review (R4/R10/R11) needs a place to live between "discovered"
and "logged as an outcome", and that place must be owned by this unit, not UNIT-CMS-0011.

The pass itself is a single logical sequence: confirm the build-order gate (R1), scan
`pp_agent` (R2), classify each row (R3/R4/R5), record a durable per-row processing state
of its own (idempotency, R8/R12), then hand every terminal outcome to UNIT-CMS-0011's
logging contract (R6) and produce a summary (R7).

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Gate checker | Confirms UNIT-CMS-0011 has completed agency migration before a run is allowed to start; re-checks per row for R9's per-agency case | R1, R9 |
| Discovery scanner | Reads legacy `pp_agent` rows in scope and applies the CGA-shaped-row heuristic (naming/address-field matching) to classify each as high-confidence, ambiguous, or not-CGA | R2 |
| Reconciliation writer | Creates the `Cga` record for a high-confidence match, linked to the agency's new id | R3 |
| Review flag manager | Records ambiguous rows as pending review, and applies a reviewer's resolution on a later run | R4, R10, R11 |
| Run coordinator | Enforces single-run-at-a-time, tracks per-row processing state for idempotent re-runs, retries the logging call | R8, R12, R13, R14, R20 |
| Outcome reporter | Calls UNIT-CMS-0011's logging contract per row outcome; produces the run summary | R6, R7, R25 |

## Flows

### Discovery and reconciliation pass — satisfies R1, R2, R3, R5, R6, R7, R9

1. An operator triggers a run.
2. The gate checker confirms UNIT-CMS-0011 has recorded agency-migration completion; if not, the run is rejected (failure path below).
3. The discovery scanner reads each in-scope `pp_agent` row not already in a terminal processing state from a prior run.
4. For each row, the heuristic classifies it:
   - high-confidence CGA-shaped → reconciliation writer creates the `Cga` record, linked to the row's agency's new id (requires that agency to already have a new id — R9).
   - not CGA-shaped → recorded as `skipped`.
   - ambiguous → review flag manager records it as pending review (see the manual-review flow).
5. Each terminal outcome (`migrated`, `skipped`, `failed`) is handed to the outcome reporter, which calls UNIT-CMS-0011's logging contract.
6. On completion, the outcome reporter produces the run summary (counts by outcome).

Failure paths:

| Step fails | Behaviour |
|---|---|
| Gate check (step 2) finds agency migration incomplete | Run is rejected before any row is processed; recorded as a blocked run, not a partial run (R1) |
| A row's target agency has no new id yet (step 4, high-confidence match) | That row is recorded `failed` with a missing-agency reason; it is not retried automatically, but remains eligible on a later run once the agency exists (R9) |
| The logging contract call (step 5) does not succeed after retry | The row's own outcome (reconciled/skipped) stands; the run summary surfaces the row as having an unresolved logging gap (R13) |
| The pass is interrupted (crash, timeout) mid-run | Rows already given a terminal processing state are untouched on the next run; unprocessed rows are picked up from where the scan left off (R12) |

### Manual review resolution — satisfies R4, R10, R11

1. A reviewer lists rows currently flagged pending review.
2. The reviewer resolves one as "is CGA" or "is not CGA".
3. The resolution is recorded against that row's processing state.
4. On the next discovery/reconciliation pass, a resolved row is processed per its resolution (reconciled or skipped, never re-flagged); an unresolved row is flagged again (R10).

Failure paths:

| Step fails | Behaviour |
|---|---|
| Reviewer attempts to resolve a row not currently in a pending-review state | Rejected — a row can only be resolved once, from pending-review; a second resolution attempt on an already-resolved row is rejected, not silently accepted |
| Resolution recorded but no further pass ever runs | The row remains resolved-but-unprocessed indefinitely; this is a valid, inspectable state, not a failure — the summary from the last pass that saw it as flagged still shows it as flagged until a pass processes the resolution |

## Data model

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| ReconciliationCandidate (owned by this unit) | legacy `pp_agent` row's own identifying key | current processing state (`pending` \| `reconciled` \| `skipped` \| `flagged` \| `failed`), the review resolution if any, the `Cga` id it produced (if reconciled) | Retained for the life of the migration cutover record; not a business entity, so it follows the same audit-adjacent retention as `MigrationLog` rather than a subject's own data lifecycle |
| Cga (UNIT-CMS-0005; this unit creates rows only) | UNIT-CMS-0005's own key | Populated from the matched `pp_agent` row's fields; `agencyId` set to the agency's new (post-migration) id | Owned by UNIT-CMS-0005 |
| MigrationLog (UNIT-CMS-0011; written only via its logging contract) | UNIT-CMS-0011's own key | `processedBy: cga-reconciliation` | Owned by UNIT-CMS-0011 |

**Constraint that carries a requirement:** exactly one `ReconciliationCandidate` row
exists per legacy `pp_agent` row in scope, enforced by a uniqueness constraint on that
row's legacy identifying key rather than by application-level check-then-insert — this
is what makes the idempotency walk below hold under a crash-and-retry rather than only
in the absence of one.

## Contracts

What this unit exposes, as a row naming the file that will hold it under
`interfaces/`. It also **consumes** one contract it does not own and therefore does
not table here: UNIT-CMS-0011's outcome-logging contract (R6, R13, R24), whose shape
and file live in UNIT-CMS-0011's own `interfaces/` once that unit designs it — see
Risks below for the sequencing this creates.

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Trigger and observe a reconciliation run; list and resolve flagged candidates | sync HTTP | `interfaces/openapi.yaml` | R1, R4, R7, R9, R10, R11, R14, R22 |
| `ReconciliationCandidate` and run-lock storage contract | storage | `interfaces/001_create_reconciliation_candidate.sql` | R8, R12, R14, R19, R20, R23 |

## State and idempotency

**State machine — `ReconciliationCandidate`:**

```
pending → reconciled          (high-confidence match, agency exists)
pending → skipped             (not CGA-shaped)
pending → failed              (agency not yet migrated — R9)
pending → flagged             (ambiguous match)
flagged → flagged             (re-evaluated, still unresolved — R10)
flagged → reconciled          (reviewer resolved "is CGA")
flagged → skipped             (reviewer resolved "is not CGA")
failed  → reconciled|skipped|failed   (re-run, once the missing agency exists)
```

Terminal states: `reconciled`, `skipped`. `failed` and `flagged` are retry-eligible,
not terminal — this is the asynchronous-work state the design must not lose: a row
sitting in `failed` or `flagged` is normal mid-cutover, not an error state to alarm on
by itself.

**Invariant:** every in-scope `pp_agent` row has exactly one current
`ReconciliationCandidate` state at all times, and never zero. Enforced by the
uniqueness constraint above plus the run coordinator creating the `pending` row for a
never-seen legacy row **before** classification runs, in the same unit of work — so a
crash between "row seen" and "row classified" leaves it at `pending`, never absent.

**Idempotency walk** — every path that could reconcile a row into a `Cga` record:

| Path | What happens | Collapses to |
|---|---|---|
| First attempt, row not seen before | `ReconciliationCandidate` created at `pending`, classified, `Cga` created if matched | One `Cga` record |
| Re-run after a clean completion | Row's `ReconciliationCandidate` is already `reconciled`/`skipped`; re-processing is skipped, only the outcome log call may be re-attempted (R13) | Same `Cga` record, no duplicate |
| Re-run after a crash mid-classification | Row is `pending` (invariant above); re-classified from scratch, `Cga` creation is attempted once, guarded by the same uniqueness constraint keyed on the legacy row id — a second creation attempt for an id that already produced a `Cga` is rejected by the store, not re-created | Same `Cga` record, no duplicate |
| Two concurrent run invocations | Second invocation is rejected outright by the run lock (R14, R20) before it can process any row | No concurrent double-processing at all |
| Logging-contract call fails and is retried | The row's own state (`reconciled`/`skipped`) was already committed before the logging call; retrying the call re-sends the same outcome, which UNIT-CMS-0011's logging contract is responsible for deduplicating on its side (it is a `MigrationLog` writer concern, not this unit's) | One row outcome, logged at least once |

The idempotency key throughout is the legacy `pp_agent` row's own identifying key —
fixed before the pass starts, never derived from anything computed during
classification.

**Concurrency matrix:**

| Two things at once | Who wins |
|---|---|
| Two run triggers, same scope | Second is rejected; enforced by an exclusivity construct the store provides (an advisory-style lock), not by an application-level check-then-start, since that read-then-write would lose the guarantee under concurrency |
| A run in progress and a reviewer resolving a flagged row | Both proceed independently — resolution only updates a `flagged` row's resolution field, which the in-progress run does not touch unless it is currently processing that exact row; a row already picked up by the current run for processing is not affected by a resolution recorded mid-run, and is picked up on the *next* run instead |
| Two reviewers resolving the same flagged row | Enforced by the storage layer allowing exactly one resolution transition out of `flagged` per row — a second resolution attempt on an already-resolved row is rejected (see Manual review resolution failure path) |
| Reconciliation writer creating a `Cga` for a row, and something else creating a `Cga` for the same legacy row concurrently | Cannot arise in practice (only this unit creates `Cga` rows for `pp_agent` sources), but is guarded regardless by the same uniqueness constraint |

## Cross-cutting

| Concern | Decision |
|---|---|
| authn/authz | Every operation (trigger a run, list/resolve candidates) requires the same operator/migration-execution role as UNIT-CMS-0011's own execution trigger (R22); no other role may call this unit's API |
| validation | A resolution request must name an existing `pending`-or-`flagged` candidate and one of the two allowed resolutions; anything else is rejected with the platform's standard error envelope |
| errors | Standard `{ code, message, details[], trace_id }` envelope; a rejected concurrent run returns a distinguished code rather than a generic conflict, so an operator can tell "already running" from "your input is wrong" |
| observability | The run summary (R7) plus per-row `MigrationLog` entries are the two places an operator diagnoses a specific row's fate, without a direct query (R25) |
| performance | No latency budget applies to the batch pass itself; the triggering/listing API calls follow the platform's general latency floor for an operator tool, not a customer-facing SLO |
| migration/backfill | This unit is itself a one-time migration/backfill job (R28); reversible only by deleting the specific `Cga` rows it created, and not intended to be reversed once cutover is declared complete |
| feature flag | N/A — operator-triggered, no runtime on/off switch (R29) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The CGA-shaped-row heuristic's exact thresholds are undecided (open question 2 in `requirements.md`) | A poorly tuned heuristic either misses real CGA rows (M2 not met) or over-flags genuine agents for manual review, creating review-queue load nobody sized | State the heuristic's inputs and confidence tiers explicitly in the interface's request/response shapes so it can be tuned without a contract change; treat the first run's flagged-row count as the discovery data needed to close open question 1 |
| UNIT-CMS-0011's logging contract shape is not yet designed (its `design.md`/`interfaces/` are still outstanding at the time of this design) | This unit's outcome-reporter component and its retry behaviour (R13) are specified against the *logical* contract in `capability-design.md` (outcome, reason, `processedBy`, timestamp), not a finalized transport | Accepted, not mitigated further here — flagged for `architect-unit-interfaces` to confirm against UNIT-CMS-0011's actual contract once available, and for `ba-spec-validate` to catch as staleness (I11) if the two ever disagree |
| Volume of true CGA mis-inserts in `pp_agent` is unknown (capability's own open question) | The pass's summary counts and the manual-review queue size cannot be sized in advance | Accepted — the pass is designed to complete regardless of how many rows turn out to match (R17's bound is the whole `pp_agent` table's low-hundreds scale, not the CGA-match count specifically) |

## Decisions

No ADR raised. The one candidate — owning a `ReconciliationCandidate` tracking entity
in this unit rather than extending UNIT-CMS-0011's `MigrationLog` with a `pending`
outcome value — was decided in the Approach section above without a genuinely close
alternative: `MigrationLog` is explicitly XD-0002's single-writer, terminal-outcome log,
and overloading it with a non-terminal state would break that unit's own contract, not
just this one's. Not contested enough to warrant a separate record.

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Gate checker; Discovery and reconciliation pass flow, step 2 |
| R2 | Discovery scanner; Discovery and reconciliation pass flow, step 3 |
| R3 | Reconciliation writer; Discovery and reconciliation pass flow, step 4 |
| R4 | Review flag manager; Manual review resolution flow |
| R5 | Discovery and reconciliation pass flow, step 4 |
| R6 | Outcome reporter; Discovery and reconciliation pass flow, step 5 |
| R7 | Outcome reporter; Discovery and reconciliation pass flow, step 6 |
| R8 | State and idempotency — idempotency walk, rows 2 and 3 |
| R9 | Gate checker; Discovery and reconciliation pass flow, failure path table |
| R10 | Manual review resolution flow, step 4; State machine `flagged → flagged` |
| R11 | Manual review resolution flow, step 4; State machine `flagged → reconciled/skipped` |
| R12 | State and idempotency — invariant and idempotency walk, row 3 |
| R13 | Discovery and reconciliation pass flow, failure path table; idempotency walk, last row |
| R14 | Run coordinator; Concurrency matrix, row 1 |
| R15 | Cross-cutting — performance |
| R16 | Cross-cutting — performance |
| R17 | Risks — volume row |
| R18 | Cross-cutting — performance |
| R19 | State and idempotency — idempotency walk |
| R20 | Concurrency matrix, row 1 |
| R21 | Cross-cutting — authn/authz (no external caller) |
| R22 | Cross-cutting — authn/authz |
| R23 | Data model — `ReconciliationCandidate` and `Cga` inherit tenant scope; storage contract |
| R24 | Cross-cutting — observability; Contracts table (logging contract) |
| R25 | Cross-cutting — observability |
| R26 | Data model — field notes; storage contract carries no special-category data |
| R27 | Data model — retention notes |
| R28 | Cross-cutting — migration/backfill |
| R29 | Cross-cutting — feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
