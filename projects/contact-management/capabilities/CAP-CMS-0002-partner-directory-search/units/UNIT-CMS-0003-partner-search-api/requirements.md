---
id: UNIT-CMS-0003
slug: partner-search-api
project: CMS
capability: CAP-CMS-0002
title: Partner Search API
kind: backend
target_repo: CMS-partner-directory-search
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-19
---

# Partner Search API

## Scope

The six-mode search contract (`GET /search`, per XD-0001) plus the assigned-underwriter
lookup, read-only against UNIT-CMS-0005's brokerage/agency/CGA data. Owns no entity of
its own — its seam is the read-only query boundary against another unit's schema, one
contract (`/search` and `/lookups/assigned-uws`), independently verifiable once that
schema exists.

**In scope:**
- The six search modes as query-parameter variants of one endpoint (XD-0001)
- The assigned-underwriter filter lookup
- Server-side pagination/filtering for all six modes

**Out of scope:**
- Writing to brokerage/agency/CGA data (UNIT-CMS-0005 owns it; this unit is read-only — XD-0002)
- The Directory screen's UI (UNIT-CMS-0004)
- Launching "Add New Agency"/"Add New Brokerage" (a UI navigation concern, UNIT-CMS-0004/UNIT-CMS-0006)

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | `GET /search?mode=brokerage&term=` returns brokerages whose name contains `term` (case-insensitive), with result columns Brokerage, Address (city/state/zip), Assigned UW, State. | CAP-CMS-0002/A1, FR-SEARCH-1 | P0 |
| R2 | `GET /search?mode=broker&term=` returns brokers whose person name contains `term` (case-insensitive), with result columns First, Last, Brokerage, Title/Type, Email, Disabled flag. | CAP-CMS-0002/A1, FR-SEARCH-1 | P0 |
| R3 | `GET /search?mode=state-broker&state=` returns brokerages located in `state`, with the same result columns as `mode=brokerage`. | CAP-CMS-0002/A1, FR-SEARCH-1 | P0 |
| R4 | `GET /search?mode=agency&term=` returns agencies whose agency name or address text contains `term` (case-insensitive), with result columns Agency, Address, Agent. | CAP-CMS-0002/A1, FR-SEARCH-1 | P0 |
| R5 | `GET /search?mode=cga&term=` returns CGAs whose agent name or address contains `term` (case-insensitive), with result columns CGA Agent, Address. | CAP-CMS-0002/A1, FR-SEARCH-1 | P0 |
| R6 | `GET /search?mode=state-agent&state=` returns agencies/agents located in `state`, with the same result columns as `mode=agency`. | CAP-CMS-0002/A1, FR-SEARCH-1 | P0 |
| R7 | Each item returned by `mode=brokerage`, `mode=state-broker`, `mode=broker` carries the identifier needed to open Brokerage Detail; each item from `mode=agency`, `mode=state-agent` carries the identifier needed to open Agency Detail; each item from `mode=cga` carries the identifier needed to open CGA Detail. | CAP-CMS-0002/A1, FR-SEARCH-1 | P0 |
| R8 | `GET /lookups/assigned-uws` returns the distinct set of underwriter values currently assigned to at least one brokerage, read live from UNIT-CMS-0005's data — `BAssignedUW` stays free text (capability.md, intake Q7), so this is a distinct-values read, not a managed lookup. | CAP-CMS-0002/A2, FR-SEARCH-2 | P0 |
| R9 | `GET /search?mode=brokerage&uw=` filters brokerage results to exactly the brokerages currently assigned to the named underwriter. | CAP-CMS-0002/A2, FR-SEARCH-2 | P0 |
| R10 | For `mode=brokerage`, `mode=broker`, `mode=agency`, `mode=cga` (the free-text modes), a request whose `term` is absent or empty is rejected with `400 term_required` before any query runs. | CAP-CMS-0002/A1, FR-SEARCH-3 | P0 |
| R11 | For `mode=state-broker` and `mode=state-agent`, `term` is not required — the request runs on `state` alone. | FR-SEARCH-3 | P0 |
| R12 | Every response includes a `total` count of matching records and a `next_cursor` for continuing the result set (`null` when no further results remain), whether the result set is empty, partial, or full. | CAP-CMS-0002/A1, FR-SEARCH-4 | P0 |
| R13 | An empty match set is a successful `200` response with `items: []`, `total: 0`, and `next_cursor: null` — never an error. | FR-SEARCH-4 | P1 |
| R14 | Every `broker` result item's status is represented by a single closed `disabled` boolean field — never a derived string the caller must parse. | FR-SEARCH-5 | P1 |
| R15 | Results are paginated via cursor-based `limit`/`cursor` query parameters (10-platform.md floor — no offset/page-number pagination); the query itself runs server-side (filtering, matching, and pagination are all evaluated by the API, never returned unfiltered for the client to narrow). | CAP-CMS-0002/A3, FR-SEARCH-7, API-1 | P0 |

## Behaviour detail

Per-requirement detail where a table row is not enough. Reference the R-ID.

### R1 / R3 / R7 — brokerage-family modes

**Given** a caller with `mode=brokerage` and a non-empty `term`,
**when** the term matches a brokerage name (case-insensitive substring),
**then** the response includes that brokerage's row with an id sufficient to open its
Brokerage Detail screen (owned by UNIT-CMS-0006).

`mode=state-broker` follows the identical result shape, replacing the name-match
predicate with a `state` equality match; no `term` is read for this mode even if
supplied.

Error cases:

| Condition | Result |
|---|---|
| `term` supplied for `mode=state-broker`/`mode=state-agent` | Ignored; the mode's own filter governs. Not an error. |
| `state` value not a recognised 2-letter code | `400 invalid_request` |

### R8 / R9 — assigned-underwriter lookup and filter

**Given** the underwriter lookup is called with no parameters,
**when** the read against UNIT-CMS-0005's brokerage data runs,
**then** the response is the distinct set of non-null `BAssignedUW` values currently in
use across brokerages, with no pagination (bounded by the small-scale constraint —
low hundreds of brokerages, capability.md Constraints).

Selecting one of those values as `uw` on `mode=brokerage` immediately narrows results to
exactly the brokerages carrying that value — an exact-match filter, not a substring
match, since `BAssignedUW` is free text and partial matches would silently include
unrelated underwriters sharing a substring.

Error cases:

| Condition | Result |
|---|---|
| `uw` value has no assigned brokerage (e.g., stale filter selection) | `200` with `items: []`, `total: 0` — not an error |

### R10 / R11 — term requirement per mode

Error cases:

| Condition | Result |
|---|---|
| `mode=brokerage`/`broker`/`agency`/`cga` with `term` absent or empty string | `400 term_required` |
| `mode=state-broker`/`state-agent` with `state` absent | `400 state_required` |
| `mode` absent or outside the closed six-value enum | `400 invalid_request` |
| `cursor` supplied does not match the current request's `mode`/`term`/`state`/`uw` filter set (10-platform.md — a cursor is opaque and encodes the filter set it was issued for) | `400 cursor_invalid` |

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R16 | availability | This unit's own compute carries the platform default; it depends on UNIT-CMS-0005's schema being reachable — no separate SLO is stated beyond that dependency, since this unit is a pure read path over it. |
| R17 | latency | p95 ≤ 900 ms, p99 ≤ 2000 ms for `GET /search`, inclusive of serverless cold start (`stack.md`'s cold-start consequence) — supports NFR-PERF-1's ~1s first-results target (CAP-CMS-0002/M1). `GET /lookups/assigned-uws` p95 ≤ 500 ms given its small, bounded result set. |
| R18 | throughput | Peak figure: ≤15 requests/second, derived from intake Q8's "low hundreds of brokerages/agencies/CGAs, <50 concurrent staff" — ASSUMPTION, not a measured figure per rule 30-nfr-floor.md; revisit once real traffic is observed. |
| R19 | surge | At 2× peak (~30 rps), API Gateway throttling (`stack.md`) sheds excess requests with `429` + `Retry-After`; every request here is a discretionary read, so nothing is exempt from shedding. |
| R20 | idempotency | All operations in this unit are `GET`; inherently idempotent, no dedupe key required (R21, R22 below cover the observable consequence). |
| R21 | concurrency | Two concurrent callers running the same or different search queries each observe an independent, consistent read; neither call blocks on or is affected by the other, since no write path exists in this unit. |
| R22 | rate limits | Per caller and per this unit's endpoints, enforced by API Gateway throttling (`stack.md`); response is `429` with `Retry-After`, matching CAP-CMS-0002's shared error envelope. |
| R23 | authorization | Minimum role: Viewer, for every endpoint in this unit (R1–R9). No service-credential caller is defined; ownership rule is "the caller's own authenticated session, scoped to their own tenant." |
| R24 | tenant isolation | Every query in this unit runs under UNIT-CMS-0005's row-level-security policy (`stack.md`) — no query in this unit issues a raw read that bypasses RLS, on any of the six modes or the lookup, including a term/state value that happens to match another tenant's data. |
| R25 | audit | N/A — this unit performs no create/update/delete operation; CAP-CMS-0001/M3's audit-log obligation is scoped to mutating operations and does not apply to a read-only search surface. |
| R26 | observability | Metrics: request count and latency per `mode`, result-set size distribution, `400`/`429` rate. Structured log fields: caller id, tenant id, `mode`, whether `term`/`state`/`uw` was supplied (not their values, since a search term may itself contain personal data — see R27), result count. Trace span boundary: the query against UNIT-CMS-0005's data is its own span. |
| R27 | data classification | `term` (free-text search input) may contain a person's name (broker/agent search) — treated as personal data in transit; never logged verbatim, only "supplied: true/false" per R26. Result fields (brokerage/agency name, address, broker/agent name, email) are personal data, not special category — read-only pass-through of UNIT-CMS-0005's own classification, no new field is introduced here. |
| R28 | retention and deletion | N/A — this unit persists nothing of its own; retention and erasure for the underlying brokerage/agency/broker/agent/CGA data are UNIT-CMS-0005's obligation. |
| R29 | migration and backfill | N/A — greenfield unit, no data owned, nothing to migrate. |
| R30 | feature flag | N/A — no flagged rollout is planned for this unit. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Brokerage | Read | Owned by UNIT-CMS-0005; read for `mode=brokerage`/`state-broker` and the assigned-UW lookup |
| Broker | Read | Owned by UNIT-CMS-0005; read for `mode=broker` |
| Agency | Read | Owned by UNIT-CMS-0005; read for `mode=agency`/`state-agent` |
| Agent | Read | Owned by UNIT-CMS-0005; read for `mode=agency`/`state-agent` |
| CGA | Read | Owned by UNIT-CMS-0005; read for `mode=cga` |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth/RBAC — every search endpoint requires an authenticated Viewer-or-above request |
| UNIT-CMS-0005 | schema | Read-only queries against brokerage/agency/CGA data; this unit cannot be built until that schema exists (design-time dependency, capability-design "Build and sequencing order") |

## Assumptions

- Peak throughput of ≤15 rps (R18) is derived from intake Q8's qualitative "small scale" statement, not a measured figure. Revisit once real traffic is observed.
- No service-credential caller exists for this unit today (R23); only user-session callers are in scope.
- `state` values are validated against a closed 2-letter US state/territory code set; the exact enumeration is an `interfaces/` concern, not restated here.
- UNIT-CMS-0005's schema is assumed to expose the fields named in Appendix A's backing-read-model columns (brokerage name, address parts, assigned UW, broker name/title/email/disabled, agency/agent address text, CGA agent name/address) by the time this unit is built; if any field is missing there, this unit is blocked on UNIT-CMS-0005's design, not on its own.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
