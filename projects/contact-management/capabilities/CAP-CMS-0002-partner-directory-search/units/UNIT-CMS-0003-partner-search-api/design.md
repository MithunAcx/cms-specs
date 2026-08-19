---
unit: UNIT-CMS-0003
updated: 2026-08-18
---

# Design — Partner Search API

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

One `GET /search` endpoint family whose `mode` parameter selects which of UNIT-CMS-0005's
entities is matched and which predicate is applied (XD-0001), plus one small lookup
endpoint for the assigned-underwriter filter. Both are pure, synchronous, read-only
queries against UNIT-CMS-0005's schema, executed under that schema's row-level-security
policy (PostgreSQL, per `stack.md`) so tenant isolation is enforced by the store rather
than by this unit's own logic. There is no local datastore, no cache, and no write path:
this unit computes nothing that outlives one request, so there is no state machine to
design and no idempotency key to derive beyond "every operation is a `GET`".

The six modes share one endpoint rather than six, per XD-0001 — the alternative (one
endpoint per mode) was rejected at capability-design level and is not reopened here; it
would give UNIT-CMS-0004 six near-identical clients instead of one, and would duplicate
the shared pagination/error/auth handling six times for no behavioural difference. Within
that one endpoint, this design's own choice is that `mode` selects a **predicate and a
result projection**, not a different resource: the request/response envelope (pagination,
error shape, auth) is identical across all six modes, and only the matched columns and
the matched entity vary. The alternative considered — one broad "search everything"
predicate returning a union of entity types — was rejected because Appendix A's six modes
have materially different result columns and different backing semantics (e.g., "By
State" runs with no free-text term at all); collapsing them into one heterogeneous result
shape would push mode-discrimination logic onto every caller instead of resolving it once
here.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Mode validator | Confirms `mode` is one of the six closed values, and confirms the parameter shape required by that mode (`term` vs. `state`) is present before any query runs | R10, R11 |
| Predicate resolver | Maps `mode` to the entity and match predicate: name/person/address substring match, or state equality match, per Appendix A | R1–R7 |
| Assigned-UW filter | Applies an exact-match filter on `BAssignedUW` when `uw` is supplied on `mode=brokerage` | R9 |
| UW lookup reader | Reads the distinct set of non-null `BAssignedUW` values currently in use | R8 |
| Result assembler | Projects matched rows to the result columns for the active mode, attaches the detail-screen identifier, and builds the `{ items, total, page, size }` envelope | R7, R12, R13, R14, R15 |
| Tenant-isolation boundary | Ensures every query above runs under UNIT-CMS-0005's row-level-security policy — no query path in this unit bypasses it | R24 |

## Flows

### GET /search — brokerage-family modes (`mode=brokerage`, `mode=state-broker`) — satisfies R1, R3, R7, R9, R10, R11, R12, R13

1. Caller sends `GET /search?mode=brokerage&term=&uw=&page=&size=` (or `mode=state-broker&state=`) with a bearer token.
2. Mode validator confirms `mode` is a recognised value and that the mode's required
   parameter (`term` for `brokerage`, `state` for `state-broker`) is present and non-empty.
3. Predicate resolver runs a case-insensitive substring match on brokerage name
   (`mode=brokerage`) or an equality match on brokerage state (`mode=state-broker`),
   scoped by UNIT-CMS-0005's row-level-security policy.
4. If `uw` is supplied (`mode=brokerage` only), Assigned-UW filter narrows the matched
   set to brokerages whose `BAssignedUW` exactly equals `uw`.
5. Result assembler projects each row to Brokerage, Address (city/state/zip), Assigned
   UW, State, plus the brokerage id, and builds the paginated envelope.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 1 — no/invalid token | `401` |
| 2 — `mode=brokerage` with empty/absent `term` | `400 term_required` |
| 2 — `mode=state-broker` with absent `state` | `400 state_required` |
| 2 — `mode` outside the six-value enum | `400 invalid_request` |
| 2 — `state` not a recognised code | `400 invalid_request` |
| 3 — no matching rows | `200` with `items: []`, `total: 0` — success, not an error (R13) |
| 4 — `uw` value has no assigned brokerage | `200` with `items: []`, `total: 0` — success, not an error |

### GET /search — broker mode (`mode=broker`) — satisfies R2, R7, R10, R14

1. Caller sends `GET /search?mode=broker&term=`.
2. Mode validator confirms `term` is present and non-empty.
3. Predicate resolver runs a case-insensitive substring match on the broker person
   name, scoped by the row-level-security policy.
4. Result assembler projects each row to First, Last, Brokerage, Title/Type, Email, and
   a closed `disabled` boolean, plus the owning brokerage's id (for Brokerage Detail).

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — empty/absent `term` | `400 term_required` |
| 3 — no matching rows | `200` with `items: []`, `total: 0` |

### GET /search — agency-family and CGA modes (`mode=agency`, `mode=state-agent`, `mode=cga`) — satisfies R4, R5, R6, R7, R10, R11

1. Caller sends `GET /search?mode=agency&term=` (or `mode=state-agent&state=`, or
   `mode=cga&term=`).
2. Mode validator confirms the mode's required parameter is present.
3. Predicate resolver runs the mode-specific match: agency name/address substring
   (`agency`), agency/agent state equality (`state-agent`), or CGA agent name/address
   substring (`cga`) — scoped by the row-level-security policy.
4. Result assembler projects to Agency, Address, Agent (for `agency`/`state-agent`) or
   CGA Agent, Address (for `cga`), plus the detail-screen identifier (Agency Detail or
   CGA Detail respectively).

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — `mode=agency`/`cga` with empty/absent `term` | `400 term_required` |
| 2 — `mode=state-agent` with absent `state` | `400 state_required` |
| 3 — no matching rows | `200` with `items: []`, `total: 0` |

### GET /lookups/assigned-uws — satisfies R8

1. Caller sends `GET /lookups/assigned-uws` with a bearer token.
2. UW lookup reader reads the distinct non-null `BAssignedUW` values across brokerages
   currently assigned at least one, scoped by the row-level-security policy.
3. Response returns the full set, unpaginated (bounded by the small-scale constraint —
   low hundreds of brokerages).

Failure paths:

| Step fails | Behaviour |
|---|---|
| 1 — no/invalid token | `401` |
| 2 — no brokerage currently has an assigned UW | `200` with `[]` — success, not an error |

## Data model

This unit owns no persistent entity — see `requirements.md` § Data. Every read is
against UNIT-CMS-0005's schema; the fields it depends on (brokerage name/address/state/
assigned-UW, broker name/title/email/disabled, agency/agent name/address/state, CGA agent
name/address) are that unit's own to define in its `interfaces/`, not restated here.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| — (none owned) | — | — | — |

## Contracts

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Partner search | sync HTTP | `interfaces/openapi.yaml` | R1–R7, R9–R15 |
| Assigned-UW lookup | sync HTTP | `interfaces/openapi.yaml` | R8 |

## State and idempotency

This unit holds no state and performs no write. Every operation is a `GET` over
UNIT-CMS-0005's current data, so there is no state machine, no idempotency key to
derive, and no replay concern: a retried or duplicated call re-reads the current answer
and has no cumulative effect (R20). Because the underlying entities are owned and mutated
by UNIT-CMS-0005, a search result reflects that unit's data as of the read instant — this
unit makes no promise about results remaining stable between two calls, and none is
needed, since nothing here decides anything based on a prior read.

## Concurrency matrix

| Scenario | Who wins / what holds |
|---|---|
| Two callers run the same search concurrently | Each gets an independent, consistent read; no shared mutable state exists in this unit to contend over (R21) |
| A write to a brokerage/broker/agency/CGA row lands in UNIT-CMS-0005 while a search is in flight | The search either observes the row before or after the write, per UNIT-CMS-0005's own transaction isolation — this unit imposes no additional locking, since a stale-by-one-write read is an acceptable outcome for a discretionary search, not a correctness violation |
| Two callers request the assigned-UW lookup while a brokerage's `BAssignedUW` is being edited concurrently | Same as above — each lookup reflects a consistent snapshot at its own read instant; no coordination is required across callers |

No case in this unit requires storage-level enforcement beyond what UNIT-CMS-0005's own
transactional store already provides for its writes — there is nothing here for this
unit's own logic to get wrong under concurrency, because it performs no write.

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | Every query in every flow above runs under UNIT-CMS-0005's row-level-security policy (PostgreSQL, per `stack.md`) — enforced by the store, not by an application-level tenant filter added per query (R24) |
| authn/authz | Bearer token validated per CAP-CMS-0001; minimum role Viewer for every endpoint (R23) |
| validation | `mode` restricted to the closed six-value enum; each mode's required parameter (`term` or `state`) checked before any query runs (R10, R11) |
| errors | Shared envelope `{ error: { code, message, details, trace_id } }`; `400 term_required`/`400 state_required`/`400 invalid_request` for malformed input, `401` for missing/invalid auth, `429` for gateway-enforced rate limiting |
| observability | Metrics: request count and latency per `mode`, result-set size distribution, `400`/`429` rate. Logs: caller id, tenant id, `mode`, whether `term`/`state`/`uw` was supplied (never the value), result count (R26). No search-term value or result-field value with personal-data classification ever appears in a log line (R27) |
| performance | `GET /search` p95 ≤ 900 ms / p99 ≤ 2000 ms inclusive of cold start; `GET /lookups/assigned-uws` p95 ≤ 500 ms (R17) |
| migration/backfill | N/A — greenfield, no data owned by this unit (R29) |
| feature flag | N/A — no flagged rollout planned (R30) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| This unit cannot be built or verified until UNIT-CMS-0005's schema is defined | Blocked start, not a design defect — capability-design's own sequencing already names this (order 1 depends on UNIT-CMS-0005's schema) | Tracked as a design-time dependency in `requirements.md`; no workaround attempted here, since building against a guessed schema would be rewritten once the real one lands |
| Free-text substring matching (`term`) across low-hundreds of rows may not meet the p95/p99 budget (R17) if UNIT-CMS-0005 has no supporting index for the matched columns | First-results latency (M1) missed under real data volume | Flag to UNIT-CMS-0005's design that this unit needs an index (or equivalent) on brokerage name, broker person name, agency/address text, and CGA agent name/address — named as a cross-unit coordination point, not something this unit can enforce unilaterally |
| `BAssignedUW` being free text (not a managed lookup) means the UW filter can silently miss brokerages if staff spell an underwriter's name inconsistently | A? filter that appears to work but returns an incomplete result set — the classic "search worked, but I know there are more" complaint | Recorded as an accepted limitation, not a defect of this unit — capability.md's non-goals explicitly keep `BAssignedUW` free text; if inconsistent spelling becomes a real problem, promoting it to a managed lookup is a change request against FR-SEARCH-2 |

## Decisions

No ADR raised for this unit. The one genuinely contested call — one endpoint family vs.
six — was already made and recorded at capability-design level (XD-0001) and is inherited
as fixed; this design does not reopen it.

| ADR | Decision |
|---|---|
| — | none |

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Flow: brokerage-family modes; Predicate resolver |
| R2 | Flow: broker mode; Predicate resolver |
| R3 | Flow: brokerage-family modes; Predicate resolver |
| R4 | Flow: agency-family/CGA modes; Predicate resolver |
| R5 | Flow: agency-family/CGA modes; Predicate resolver |
| R6 | Flow: agency-family/CGA modes; Predicate resolver |
| R7 | Result assembler; all three flows' step naming the detail-screen identifier |
| R8 | Flow: GET /lookups/assigned-uws; UW lookup reader |
| R9 | Flow: brokerage-family modes step 4; Assigned-UW filter |
| R10 | Mode validator; all three flows' failure tables |
| R11 | Mode validator; all three flows' failure tables |
| R12 | Result assembler |
| R13 | Flow: brokerage-family modes failure table; Result assembler |
| R14 | Flow: broker mode; Result assembler |
| R15 | Result assembler; Contracts |
| R16 | Cross-cutting → tenant isolation (this unit's own availability is bounded by, not separate from, UNIT-CMS-0005's) |
| R17 | Cross-cutting → performance |
| R18 | Contracts / capacity — inherited from `requirements.md`, no separate design section needed |
| R19 | Cross-cutting → errors (gateway-enforced `429`, not unit-designed) |
| R20 | State and idempotency |
| R21 | Concurrency matrix |
| R22 | Cross-cutting → errors (gateway-enforced) |
| R23 | Cross-cutting → authn/authz |
| R24 | Cross-cutting → tenant isolation; Tenant-isolation boundary component |
| R25 | N/A per `requirements.md` — no design section needed for a non-applicable NFR |
| R26 | Cross-cutting → observability |
| R27 | Cross-cutting → observability |
| R28 | N/A per `requirements.md` |
| R29 | Cross-cutting → migration/backfill |
| R30 | Cross-cutting → feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
