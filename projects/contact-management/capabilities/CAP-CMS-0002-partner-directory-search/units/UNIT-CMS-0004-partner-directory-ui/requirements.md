---
id: UNIT-CMS-0004
slug: partner-directory-ui
project: CMS
capability: CAP-CMS-0002
title: Partner Directory UI
kind: frontend
target_repo: CMS-web
owner: "@MithunAcx"
engineering:
  frontend: { applicable: true }
  api:      { applicable: false }
created: 2026-08-18
updated: 2026-08-18
---

# Partner Directory UI

## Scope

The Directory/search landing screen: mode switcher, term/state/UW inputs, results
table/card view, and the "Add New Agency"/"Add New Brokerage" launch points. Consumes
UNIT-CMS-0003's `/search` contract as a closed shape; independently verifiable against
that contract once it exists.

**In scope:**
- Search-mode UX (segmented control), term/state/UW inputs, empty-state and result-count display
- Responsive table (desktop) / stacked-card (mobile) result rendering
- Launching the create flows owned by UNIT-CMS-0006 (navigation only, no form logic here)
- Opening a result row into the correct detail screen owned by UNIT-CMS-0006

**Out of scope:**
- Search query logic, ranking, or data access (UNIT-CMS-0003)
- The create-brokerage/create-agency forms themselves (UNIT-CMS-0006)
- Brokerage/agency/CGA detail screens (UNIT-CMS-0006)

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | The application's root/landing route renders the Directory/Search screen; no other route is the landing target. | CAP-CMS-0002/FR-AUTH-4 | Must |
| R2 | The Directory screen offers exactly six mutually exclusive search modes — By Brokerage, By Broker, By State (Broker), By Agency, By CGA, By State (Agent) — presented as a single-select control; selecting a mode never leaves a prior mode's inputs applied to the new mode's query. | CAP-CMS-0002/FR-SEARCH-1, A1 | Must |
| R3 | For a name/keyword mode (By Brokerage, By Broker, By Agency, By CGA), submitting a search with an empty term is blocked client-side and shows an inline validation message; no request is sent to UNIT-CMS-0003. | CAP-CMS-0002/FR-SEARCH-3 | Must |
| R4 | For a state mode (By State (Broker), By State (Agent)), the screen runs the search from the selected state alone, with no term required. | CAP-CMS-0002/FR-SEARCH-3 | Must |
| R5 | An Assigned Underwriter filter is presented as a dropdown populated from UNIT-CMS-0003's `assigned-uws` lookup; selecting a value immediately runs a By Brokerage-shaped query scoped to that underwriter, independent of the six-mode switcher's current selection. | CAP-CMS-0002/FR-SEARCH-2, A2 | Must |
| R6 | Each search mode renders its result columns exactly as specified in the capability's mode table (e.g. By Brokerage shows Brokerage, Address, Assigned UW, State; By Broker shows First, Last, Brokerage, Title/Type, Email, Disabled flag), sourced from the response item shape UNIT-CMS-0003 returns for that mode. | CAP-CMS-0002/FR-SEARCH-1, A1 | Must |
| R7 | In By Broker results, the Email column renders as a `mailto:` link and an Active/Disabled indicator is shown per row, driven by the disabled flag in the response item. | CAP-CMS-0002/FR-SEARCH-5 | Must |
| R8 | A result set with zero items shows a "No records to display" empty state instead of an empty table/card list. | CAP-CMS-0002/FR-SEARCH-4 | Must |
| R9 | Every non-empty result set displays the total result count sourced from the response's total field, not the number of items currently rendered on the page. | CAP-CMS-0002/FR-SEARCH-4 | Must |
| R10 | Selecting a result row navigates to the detail screen appropriate to that row's mode (Brokerage Detail for By Brokerage/By Broker/By State (Broker); Agency Detail for By Agency/By State (Agent); CGA Detail for By CGA), passing the entity id from the result item. | CAP-CMS-0002/FR-SEARCH-1, A1 | Must |
| R11 | The Directory screen offers "Add New Agency" and "Add New Brokerage" launch points that navigate to the create flows owned outside this unit; this unit performs no create-form logic and calls no create API. | CAP-CMS-0002/FR-SEARCH-6 | Must |
| R12 | Result sets are paginated using UNIT-CMS-0003's `page`/`size`/`total` response fields; this unit never filters, sorts, or truncates results itself — every filter is expressed as a request parameter to UNIT-CMS-0003. | CAP-CMS-0002/FR-SEARCH-7, API-1, A3 | Must |
| R13 | On a viewport at or above the desktop breakpoint, results render as a table; below it, results render as stacked cards carrying the same fields and the same row-open behaviour (R10). | CAP-CMS-0002/FR-SEARCH-8 | Must |

## Behaviour detail

**R2 — mode switching.** Changing mode clears the term/state input and any in-flight
request for the previous mode; it does not clear the Assigned Underwriter filter,
which is an independent control (R5).

**R3/R4 — term requirement per mode.** The required-term modes are By Brokerage, By
Broker, By Agency, By CGA. The state-only modes are By State (Broker), By State
(Agent), which additionally require a state to be selected before the search can run
— submitting either state mode with no state selected is blocked the same way R3
blocks an empty term, with a mode-appropriate inline message.

**R5 — Assigned Underwriter filter interaction.** Selecting an underwriter is treated
as its own search action: it supersedes whatever mode/term/state combination was
previously showing, and re-selecting the six-mode switcher afterwards returns to
mode-driven search. Only one of {mode search, UW filter} is active at a time.

**R6/R7 — result columns.** Column sets are closed and enumerated in the capability's
mode table; a mode is never rendered with an ad hoc column set. The Disabled flag
(R7) is a boolean surfaced by UNIT-CMS-0003; this unit never derives disabled status
from any other field.

**R9 — result count.** Where the API's `total` and the number of `items` in the
current page diverge (always true once results exceed one page), the total is what is
shown; a page-relative count ("showing 1-25") is permitted alongside it but the
capability-level count is always the API's `total`.

**R10 — deep link target resolution.** Mode determines detail-screen family
deterministically per R2's mode table; this unit holds no logic that infers the
target screen from the item shape alone, only from the mode that produced it.

## Failure-surface sweep

| Class | R-ID | Requirement |
|---|---|---|
| input | R14 | A search request is never sent with a term containing only whitespace; it is treated as empty for R3's validation. |
| input | R15 | A malformed or unexpected item shape in a search response (missing an expected column field) renders that field as a visible "—" placeholder rather than omitting the row or crashing the result list. |
| authorization | R16 | An unauthenticated session is redirected to the login flow before the Directory screen renders any search input or result; no cached result set from a prior session is shown. |
| authorization | R17 | A session authenticated below the minimum role for search (Viewer) is shown an explicit access-denied state on the Directory route, not a silently empty result set. |
| authorization | R18 | The "Add New Agency"/"Add New Brokerage" launch points (R11) are hidden, not merely disabled, for a session whose role does not carry the create permission on the target capability. |
| repetition | R19 | Submitting the same search twice in quick succession (double-click, double-submit) issues at most one request in flight per mode; a second identical submission while the first is pending is a no-op. |
| concurrency | R20 | Changing mode, term, state, or the UW filter while a previous search request is still in flight cancels or discards that request's result on arrival; only the response matching the current input state is ever rendered (no stale-result flash). |
| dependency | R21 | If UNIT-CMS-0003 is unreachable or returns a 5xx, the Directory screen shows a retryable error state distinct from the empty-result state (R8) and does not claim "No records to display". |
| dependency | R22 | If UNIT-CMS-0003 responds slower than the screen's loading-state threshold, a loading indicator is shown; the screen never appears frozen with no feedback. |
| dependency | R23 | If UNIT-CMS-0003 (or its gateway) returns `429`, the screen surfaces a rate-limited message and honours the `Retry-After` value before allowing an automatic retry; a manual re-submit by the user is always allowed. |
| ordering | R24 | Where two requests are in flight for different input states (R20's cancel case did not complete before a third change), only the response for the most recently issued request is rendered, keyed by a per-request sequence token generated client-side. |
| time | R25 | If the session's access token expires while the Directory screen is idle, the next search attempt re-triggers the authentication flow (R16) rather than sending a request that will be rejected and rendering that rejection as a data error. |
| state | R26 | If a result row's underlying entity was deleted or withdrawn between the search response and the row being opened, this unit still attempts the navigation (R10); handling a not-found detail screen is the destination screen's responsibility, not this unit's, and is out of scope here. |

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R27 | availability | This unit's own availability target is 99.5% during business hours (matches the Directory screen being the landing route, per FR-AUTH-4); it is bounded above by UNIT-CMS-0003's own availability, since every search is a synchronous call to it — no fallback data source exists. |
| R28 | latency | p95 ≤ 1.2s and p99 ≤ 2.5s from search submission to first rendered result row, measured client-side, at the confirmed small-scale volume (CAP-CMS-0002 Constraints — low hundreds of brokerages/agencies/CGAs, <50 concurrent staff). This budget is the ~1s API target (M1) plus rendering time; it explicitly accounts for UNIT-CMS-0003's serverless cold-start behaviour (`stack.md`), which is why p99 carries slack beyond p95. |
| R29 | throughput | Peak client-side concurrent search submissions: <50 concurrent staff (CAP-CMS-0002 Constraints, intake Q8). No load figure above this is assumed. |
| R30 | surge | At 2× the stated peak (~100 concurrent staff), this unit sheds nothing of its own — it has no server-side component to shed load from. Backpressure is entirely UNIT-CMS-0003's/its gateway's (429 handling per R23); this unit's only surge behaviour is to keep honouring `Retry-After` rather than hammering the API. |
| R31 | idempotency | All operations against UNIT-CMS-0003 from this unit are `GET` and inherently idempotent; this unit adds no idempotency key of its own. Client-side request de-duplication (R19) is a UX safeguard, not a correctness requirement. |
| R32 | concurrency | Covered by R20/R24 (stale-response discarding). No other concurrent-write concern exists — this unit performs no writes. |
| R33 | rate limits | This unit enforces no rate limit of its own; it observes and honours the `429`/`Retry-After` contract UNIT-CMS-0003's API Gateway produces (R23). |
| R34 | authorization | Minimum role to view the Directory screen and run any search mode is Viewer (per the unified API contract's Min role column); the create-launch points (R11) require the create-capable role, gated per R18. Role is read from the session established by UNIT-CMS-0001; this unit does not issue or validate tokens itself. |
| R35 | tenant isolation | This unit never accepts or transmits a tenant identifier as user input anywhere in the search UI; tenant scoping is carried entirely by the authenticated session's bearer token and enforced server-side (UNIT-CMS-0003's RLS-backed queries, `stack.md`). A request this unit cannot attach a valid session token to is never sent. |
| R36 | audit | N/A — this unit performs no writes and initiates no state change; search is a read-only view. Audit of who searched for what, if ever required, is a decision for UNIT-CMS-0003 (server-side), not this UI. |
| R37 | observability | Client-side telemetry records, per search: mode selected, response latency, result count, and error class (none/validation/dependency-down/rate-limited); no search term, email address, or other field value is included in any telemetry event or log line. |
| R38 | data classification | Broker/agent email addresses (R7) and person names (By Broker mode) are personal data; brokerage/agency names and business addresses are not personal data. No special-category data is displayed on this screen. Personal data appearing in the UI is never written to client-side analytics or persisted beyond the current page's in-memory state. |
| R39 | retention and deletion | N/A — this unit holds no persistent client-side store; results exist only in memory for the current page view and are discarded on navigation or reload. No erasure path is needed here; erasure of the underlying broker/agent record is UNIT-CMS-0003's/its data owner's concern. |
| R40 | migration and backfill | N/A — greenfield unit, no prior data to migrate. |
| R41 | feature flag | N/A — no feature flag is planned for this screen; it is the landing route (R1) and cannot be toggled off without leaving the application without a home screen. If one is added later, the off-state behaviour must be specified before it ships (change request). |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Brokerage search result | Read | Sourced from UNIT-CMS-0003's `/search?mode=brokerage\|state-broker`; not persisted by this unit beyond the current page view |
| Broker search result | Read | Sourced from `/search?mode=broker`; includes personal data (name, email) — see R38 |
| Agency search result | Read | Sourced from `/search?mode=agency\|state-agent` |
| CGA search result | Read | Sourced from `/search?mode=cga` |
| Assigned-underwriter list | Read | Sourced from `/lookups/assigned-uws`; free-text values, not a managed lookup (capability.md, intake Q7) |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth/session (login guard, role-aware display) |
| UNIT-CMS-0003 | contract | The `/search` and `/lookups/assigned-uws` endpoints this screen calls |
| UNIT-CMS-0006 | navigation | Opens into that unit's detail/create screens; does not call its API directly |

## Assumptions

- The desktop/mobile responsive breakpoint (R13) is a single named breakpoint consistent with the rest of the CMS-web application; the exact pixel value is a design.md/ux decision, not fixed here.
- The loading-state threshold referenced in R22 is assumed to be 300ms (a common perceptible-delay threshold) pending a project-wide UX standard; if one exists it supersedes this figure without a change request, since it does not change unit scope.
- "Business hours" in R27's availability window is assumed to follow the operating hours implied by intake Q8's staff-volume figure; no explicit hours were stated in capability.md or stack.md.
- UNIT-CMS-0006 is treated as the owner of Brokerage/Agency/CGA detail and create screens, matching this unit's own scaffolded scope and dependency table (capability.md's Dependencies section instead names CAP-CMS-0003 generically; UNIT-CMS-0006 is assumed to be that capability's frontend unit — flagged as an open question below since it is not yet confirmed in this repo).

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| Q1 | Is UNIT-CMS-0006 confirmed as CAP-CMS-0003's frontend unit (the actual owner of the Brokerage/Agency/CGA detail and create screens this unit navigates to)? | design.md's navigation/routing section | @MithunAcx | Open — proceeding on the assumption above |
| Q2 | Re-copy `interfaces/UNIT-CMS-0003.openapi.yaml` verbatim once UNIT-CMS-0003 authors its own `interfaces/openapi.yaml` (this unit's copy was constructed from capability-design.md instead, since UNIT-CMS-0003 had not yet authored one — a parallel, non-blocking unit) | `interfaces/UNIT-CMS-0003.openapi.yaml` becoming authoritative (`ba-spec-validate` I11) | @MithunAcx | Open — non-blocking; tracked as a tasks.md build task |
