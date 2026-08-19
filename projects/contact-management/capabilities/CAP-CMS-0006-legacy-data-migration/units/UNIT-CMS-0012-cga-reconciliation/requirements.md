---
id: UNIT-CMS-0012
slug: cga-reconciliation
project: CMS
capability: CAP-CMS-0006
title: CGA Reconciliation
kind: data
target_repo: CMS-legacy-data-migration
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# CGA Reconciliation

## Scope

Identifies legacy `pp_agent` rows that are actually mis-inserted CGA records (the
legacy DR-1 bug) and reconciles them into UNIT-CMS-0005's `Cga` entity, linked to the
*new* (post-migration) agency id. Runs after UNIT-CMS-0011 has migrated agencies
(XD-0003); records its own outcomes only via UNIT-CMS-0011's logging contract, never by
writing `MigrationLog` directly (XD-0002).

**In scope:**
- A discovery pass over legacy `pp_agent` to identify CGA-shaped rows
- Reconciling identified rows into the new schema's `Cga` entity, linked to the new agency id
- Flagging ambiguous matches for manual review rather than auto-reconciling them
- Calling UNIT-CMS-0011's logging contract to record each outcome
- Producing a discovery/reconciliation summary report

**Out of scope:**
- General brokerage/agency/broker/agent/activity migration (UNIT-CMS-0011)
- Writing `MigrationLog` directly — this unit only calls UNIT-CMS-0011's logging contract
- Defining the `Cga` entity's schema (UNIT-CMS-0005 owns it)
- Any ongoing sync after cutover — this is a one-time job

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | The reconciliation pass does not start against a tenant's data until UNIT-CMS-0011 has recorded a completed agency-migration outcome for that tenant; starting earlier is rejected and logged as a blocked run, not silently skipped. | M2, XD-0003 | Must |
| R2 | The discovery pass reads every row of the legacy `pp_agent` table in scope and evaluates each against the CGA-shaped-row heuristic (matching on `cga_agt`-equivalent naming fields and address fields, per DR-1 / `database-specification.md` §10). | M2, A3 | Must |
| R3 | A `pp_agent` row that matches the heuristic with high confidence is reconciled into the new schema's `Cga` entity, populated from that row's fields, and linked to the `Cga.agencyId` of the corresponding agency's *new* (post-migration) id — never the legacy `pp_agency_id`. | M2, A3, XD-0003 | Must |
| R4 | A `pp_agent` row that matches the heuristic ambiguously (neither clearly CGA-shaped nor clearly a genuine agent row) is not auto-reconciled; it is flagged for manual review and excluded from the `Cga` entity until a reviewer resolves it. | M2, A3 | Must |
| R5 | A `pp_agent` row that does not match the heuristic at all is left untouched — it is a genuine agent row already covered by UNIT-CMS-0011's own migration — and is recorded as a `skipped` outcome, not silently ignored. | M2, A3 | Must |
| R6 | Every `pp_agent` row evaluated by the discovery pass (R2) produces exactly one outcome record — `migrated` (R3), `skipped` (R5), or `failed` — via UNIT-CMS-0011's logging contract, tagged `processedBy: cga-reconciliation`; this unit never writes `MigrationLog` directly. | M2, A3, XD-0002 | Must |
| R7 | On completion of the pass, a discovery/reconciliation summary is produced stating counts of rows evaluated, reconciled, flagged for manual review, skipped, and failed. | M2, A3 | Must |
| R8 | Re-running the reconciliation pass against a `pp_agent` row already reconciled into a `Cga` record does not create a second `Cga` record for that row; the row's outcome is re-recorded as the same `migrated` result against the same `Cga` record. | M2 | Must |
| R9 | A `pp_agent` row referencing an agency that UNIT-CMS-0011 has not migrated (no new agency id exists yet) is not reconciled; it is recorded as a `failed` outcome naming the missing-agency reason, and remains eligible for a later re-run once that agency exists. | M2, XD-0003 | Must |
| R10 | A `pp_agent` row previously flagged for manual review (R4) that is re-evaluated in a later run without having been resolved by a reviewer is flagged again, not silently dropped or auto-resolved. | M2, A3 | Must |
| R11 | If a manual reviewer resolves a flagged row as "is CGA", a subsequent run reconciles it per R3; if resolved as "is not CGA", a subsequent run records it as `skipped` and it is never flagged again. | M2, A3 | Must |
| R12 | A crash or interruption during the discovery/reconciliation pass leaves every row processed up to that point in its already-logged, correct outcome state; the pass is safely re-runnable from the start without duplicating `Cga` records (per R8) or outcome records for rows already logged. | M2 | Must |
| R13 | The pass runs to completion even if UNIT-CMS-0011's logging contract is unavailable for a given call attempt; that call is retried, and if it never succeeds for a given row the row's reconciliation outcome (`migrated`/`skipped`) still stands, but the missing log entry is surfaced in the summary (R7) as an unresolved logging gap rather than silently absent. | M2 | Must |
| R14 | Two concurrent invocations of the reconciliation pass against the same scope are not supported; a second invocation started while one is already running is rejected rather than allowed to process the same `pp_agent` rows concurrently. | M2 | Must |

## Behaviour detail

**R1 — build-order gate.** UNIT-CMS-0011's completion signal for agency migration is
read from the shared `MigrationLog` (an agency-scoped `migrated` outcome exists for
every in-scope agency, or an explicit "agencies complete" marker UNIT-CMS-0011's own
design defines — that detail belongs to UNIT-CMS-0011's design, not here). This unit
only consumes that signal; it does not define it.

**R2 — heuristic.** The exact matching heuristic (field names, thresholds for "high
confidence" vs "ambiguous") is this unit's own design decision per the capability
design's handoff notes — recorded here as a requirement that a heuristic exists and is
applied consistently, not as the heuristic's internal logic.

**R4 — manual review.** "Flagged for manual review" means the row is recorded with a
distinguishable state that a human can act on later (R10, R11); this requirement does
not mandate a specific review tool or interface — none is in scope for this unit
(no frontend — see frontmatter).

**R8, R12 — idempotency key.** The idempotency key for "has this `pp_agent` row
already been reconciled" is the legacy row's own stable identifying key (its
`pp_agent` primary key), fixed before the pass runs and never derived from anything
computed during execution.

**R9 — ordering dependency.** This is the concrete failure case of the XD-0003
build-order dependency at the level of a single row rather than the whole pass: even
after the overall gate (R1) opens, an individual CGA-shaped row may reference an
agency UNIT-CMS-0011 has not yet reached within its own migration ordering.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R15 | availability | N/A — platform-floor row with no capability outcome behind it; this is an operator-run, one-time batch job with no uptime SLO, it either completes or is re-run. |
| R16 | latency | N/A — platform-floor row with no capability outcome behind it; no synchronous caller waits on this pass, runtime is bounded by throughput (R17) instead. |
| R17 | throughput | Serves M2 (a bounded, one-time reconciliation pass, not an open-ended job). The pass completes a full run over legacy `pp_agent` within the low-hundreds volume the capability constraints record (intake Q8: low hundreds of brokerages/agencies/CGAs) — no specific figure is stated beyond that bound, since no larger source data set exists. |
| R18 | surge | N/A — platform-floor row with no capability outcome behind it; a one-time job against a fixed, known-bounded legacy data set has no traffic to shed. |
| R19 | idempotency | Serves M2/A3 — reconciliation must not be double-counted or double-created for the completeness the measure demands. Re-running the pass (R8, R12) is idempotent per `pp_agent` row, keyed on that row's legacy primary key, fixed before the pass starts. |
| R20 | concurrency | Serves M2/A3 — a second concurrent run could double-process rows and corrupt the completeness count the measure reads. Only one invocation of the pass may run at a time (R14); enforced by the pass acquiring an exclusive run lock before processing any row, not by application-level convention alone. |
| R21 | rate limits | N/A — platform-floor row with no capability outcome behind it; no external caller invokes this unit, it is operator-triggered, not request-serving. |
| R22 | authorization | Platform-floor row (20-compliance.md / 10-platform.md authz baseline), not tied to M2/A3 directly. Only an operator with a migration-execution role may trigger the pass or resolve a flagged row's manual review; this is enforced the same way UNIT-CMS-0011's own execution is gated, since both are the same class of privileged, one-time cutover action. |
| R23 | tenant isolation | Platform-floor row (10-platform.md tenancy baseline), not tied to M2/A3 directly. Every `pp_agent` row and every `Cga` record it produces carries the tenant scope inherited from its source agency; the pass never reconciles a row into an agency belonging to a different tenant than the row's own legacy tenant scope. |
| R24 | audit | Serves A3 — the CGA-reconciliation pass's findings must be documented, whether or not rows are found; this is that documentation's durability guarantee. Every outcome (R6) is a durable, timestamped record in `MigrationLog` naming the source row, the outcome, and (for `failed`/`skipped`) a reason; immutability is enforced by `MigrationLog` being append-only, per UNIT-CMS-0011's ownership of that entity — this unit never updates or deletes a log row, only appends new ones (R11's "resolved" case appends a new outcome rather than rewriting the earlier one). |
| R25 | observability | Serves A3 — supports the documented-findings condition. The summary report (R7) plus the per-row `MigrationLog` entries are sufficient to diagnose "why wasn't row X reconciled" without a direct database query — the log entry names the row, the outcome, and the reason. |
| R26 | data classification | Platform-floor row (20-compliance.md personal-data baseline), not tied to M2/A3 directly. `pp_agent` CGA-shaped rows and the `Cga` records they produce carry personal data (name, phone, email, address) but no special-category data; none of it appears in the summary report or any log line beyond the source/target identifying keys already carried in `MigrationLog` per R24 — full field values are never logged. |
| R27 | retention and deletion | N/A for this unit specifically — `MigrationLog` retention is UNIT-CMS-0011's obligation as the entity's owner; reconciled `Cga` records inherit UNIT-CMS-0005's retention and erasure path as records now living in that schema. |
| R28 | migration and backfill | This unit *is* a migration/backfill job; it is reversible only by deleting the specific `Cga` records it created and is not intended to be reversed once cutover is declared complete — see Risks in `design.md`. |
| R29 | feature flag | N/A — this is an operator-triggered one-time job, not a running service with a runtime on/off switch. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| legacy `pp_agent` rows | Read | Source of the discovery pass; never written back to |
| `Cga` (UNIT-CMS-0005) | Write (create only) | This unit creates new `Cga` records for reconciled rows; it does not own the entity's schema |
| `MigrationLog` (UNIT-CMS-0011) | Write, via UNIT-CMS-0011's logging contract only | Never written directly by this unit (XD-0002) |
| Manual-review flag state | Owned | The record of which `pp_agent` rows are flagged and their resolution; this unit's own tracking, not part of `Cga` or `MigrationLog` |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0011 | contract | Must have migrated agencies first (XD-0003); this unit calls its logging contract rather than owning its own log |
| UNIT-CMS-0005 | schema | Reconciles into the `Cga` entity that unit defines |

## Assumptions

- The CGA-shaped-row heuristic can be expressed against fields already present on the legacy `pp_agent` row (naming pattern and address fields) without needing new source data — per the capability design's handoff notes to this unit. If the discovery pass finds this insufficient, that is a design-time finding for `architect-unit-design`, not a requirements gap.
- "Manual review" resolution (R11) is performed by a human operator outside this unit's own automation; no reviewer tooling is built by this unit (no frontend surface — `engineering.frontend.applicable: false`).
- The volume of `pp_agent` rows to scan is the same low-hundreds order of magnitude the capability's constraints record for brokerages/agencies/CGAs generally (intake Q8), since `pp_agent` is bounded by the same source system; no separate volume figure exists for this specific table.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | No count of how many `pp_agent` rows are actually CGA mis-inserts is known yet — a discovery pass may be needed before this unit's scope can be sized precisely (this does not block writing the requirements above, which are sized to "however many rows the heuristic finds," but it does bound how confidently R17's throughput claim can be checked before the pass first runs). | Confidence in R17 pre-run; not `design.md` | @MithunAcx | open — non-blocking |
| 2 | The exact heuristic thresholds distinguishing "high confidence CGA-shaped" (R3) from "ambiguous" (R4) are not specified in the source material beyond "matching on `cga_agt`-equivalent naming and address fields" (capability design handoff notes) — left to `architect-unit-design` to propose, since it is a design-level algorithm choice, not a requirement gap. | none — `design.md` proposes it | @MithunAcx | open — non-blocking |
