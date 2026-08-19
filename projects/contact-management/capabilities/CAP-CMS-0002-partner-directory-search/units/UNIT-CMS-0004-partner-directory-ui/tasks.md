---
unit: UNIT-CMS-0004
change: original
---

# Tasks — Partner Directory UI

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate a typed client from `interfaces/UNIT-CMS-0003.openapi.yaml`'s `searchPartners` operation, covering all six mode variants and the `400`/`401`/`403`/`429`/`500` responses — satisfies R2, R3, R4, R6, R10, R12
- [ ] Generate a typed client from `interfaces/UNIT-CMS-0003.openapi.yaml`'s `listAssignedUnderwriters` operation — satisfies R5
- [ ] Re-copy `interfaces/UNIT-CMS-0003.openapi.yaml` once UNIT-CMS-0003 authors its own `interfaces/openapi.yaml`, and regenerate the two clients above against it, confirming no shape drift — satisfies design.md's Risks row on this file, blocks nothing else in this unit

## Data

N/A — this unit owns no persistent data and applies no migration (requirements.md R39/R40; design.md Data model).

## Implementation

- [ ] Implement the search-input state with its four states (idle, loading, resolved, error) and the mode/term/state/UW-filter fields, per design.md's State and idempotency section — satisfies R2, R3, R4
- [ ] Implement the mode switcher: single-select control over the six modes, clearing the previous mode's term/state input on change — satisfies R2
- [ ] Implement client-side submission blocking for an empty/whitespace-only term on a term-required mode, and for no state selected on a state-required mode, each with its own inline validation message — satisfies R3, R4, R14
- [ ] Implement the request sequencer: a monotonic token per outbound request, attempted cancellation of the previous in-flight request, and discarding of any response whose token does not match the current one — satisfies R19, R20, R24, R31, R32
- [ ] Implement the Assigned Underwriter filter as an independent search path that supersedes the mode-driven search when a value is selected, going through the same request sequencer — satisfies R5
- [ ] Implement result rendering with the exact column set per mode from the capability's mode table, sourced only from the response item shape — satisfies R6
- [ ] Implement the By Broker mode's email column as a `mailto:` link and its Active/Disabled status indicator from the response's disabled flag — satisfies R7
- [ ] Implement the empty-result state ("No records to display") shown only when a resolved, non-stale response has zero items — satisfies R8
- [ ] Implement the result-count display sourced from the response's `total` field, never from the rendered item count — satisfies R9
- [ ] Implement the result-row navigator resolving the target detail-screen family from the current mode (Brokerage Detail / Agency Detail / CGA Detail) and navigating with the row's entity id, attempting navigation even if the target entity may since have changed — satisfies R10, R26
- [ ] Implement pagination against the response's `page`/`size`/`total` fields, issuing a new sequenced request per page change with no client-side filtering, sorting, or truncation — satisfies R12
- [ ] Implement the responsive layout: table rendering at the desktop breakpoint and stacked-card rendering below it, both sourced from the same result data and sharing the row-open behaviour — satisfies R13
- [ ] Implement a mismatched/missing field in a response item rendering as a visible placeholder rather than omitting the row or failing the render — satisfies R15
- [ ] Implement the session guard: block search-input rendering and any cached result display until an authenticated session is confirmed, redirecting to the authentication flow otherwise — satisfies R1, R16
- [ ] Implement the access-denied state for an authenticated session below the Viewer role, replacing the whole screen rather than showing an empty result set — satisfies R17
- [ ] Implement the create-launch group ("Add New Agency", "Add New Brokerage") rendered only for a session with the create-capable role, absent (not disabled) otherwise, navigating without an API call — satisfies R11, R18
- [ ] Implement re-authentication routing when a search attempt is made with an expired access token, preserving the pending search input to resume automatically after re-authentication — satisfies R25
- [ ] Implement the rate-limited state on a `429` response, surfacing the message and honouring the `Retry-After` value before any automatic retry, while always allowing a manual re-submit — satisfies R23
- [ ] Implement the recoverable-error state for a `5xx`/timeout/network failure, preserving the current search input and offering Retry — satisfies R21
- [ ] Implement the loading indicator shown once a request exceeds the loading-state threshold (requirements.md Assumptions) — satisfies R22
- [ ] Implement the terminal-error state (no further retry offered, points to support) triggered when the identical failing search has already been retried once in the session — satisfies design.md/ux states.md "error — terminal" row, no separate R-ID beyond R21's family
- [ ] Implement the partial state for the Assigned Underwriter lookup failing independently of the search path — dropdown shows an inline unavailable notice, mode search remains fully usable — satisfies ux/states.md "partial" row
- [ ] Implement the offline-on-load and offline-on-submit states per ux/states.md, including the offline-on-submit case folding into the recoverable-error family with an offline-specific message — satisfies R21 (offline variant)

## Validation and errors

- [ ] Surface the API's `validation_error` (400) response identically to the client-side blocked-submission case (same messaging family) — satisfies R3, R4
- [ ] Surface `unauthorized`/`forbidden` (401/403) by routing to re-authentication (401) or the access-denied state (403) respectively, never as a generic data error — satisfies R16, R17, R25
- [ ] Surface `rate_limited` (429) with the `Retry-After`-gated behaviour above — satisfies R23
- [ ] Surface any `5xx`/timeout/network failure as the recoverable-error state, distinct from the empty-result state — satisfies R21

## Observability

- [ ] Emit client-side telemetry per search: mode, latency, result count, and error class (none/validation/dependency-down/rate-limited); confirm no search term, email, or other field value is ever included — satisfies R37, R38

## Tests

- [ ] Unit tests for every mode's required-input validation (term-required and state-required modes), including the whitespace-only-term case — satisfies R3, R4, R14
- [ ] Unit tests for the request sequencer's token discard behaviour: overlapping requests from mode change, term change, page change, and UW-filter selection, including a slow-then-fast response ordering case — satisfies R19, R20, R24
- [ ] Unit tests for each mode's column rendering against the capability's mode table, including the By Broker mailto/status-indicator case — satisfies R6, R7
- [ ] Unit tests for the empty-state and result-count display, including the total-vs-page-item-count divergence case — satisfies R8, R9
- [ ] Unit tests for the row navigator's mode-to-detail-screen-family mapping, all six modes — satisfies R10
- [ ] Unit tests for the responsive table/card layout switch at the desktop breakpoint — satisfies R13
- [ ] Unit tests for the session guard's unauthenticated, below-Viewer, and expired-token-mid-flow branches — satisfies R1, R16, R17, R25
- [ ] Unit tests for the create-launch group's role-gated presence/absence — satisfies R11, R18
- [ ] Unit tests for the recoverable-error, terminal-error, and rate-limited states, including the Retry-After gate — satisfies R21, R23
- [ ] Unit tests for the offline-on-load and offline-on-submit states — satisfies ux/states.md offline rows
- [ ] Unit tests for the Assigned Underwriter filter's independent search path and its partial-failure (lookup-unavailable) state — satisfies R5, ux/states.md partial row
- [ ] Contract tests generated from `interfaces/UNIT-CMS-0003.openapi.yaml` pass against a mock server for both operations — satisfies R2, R3, R4, R5, R6, R7, R9, R10, R12
- [ ] Accessibility tests: keyboard map (mode switcher roving tabindex, arrow-key navigation, Esc on the UW dropdown), focus order including focus-after-error and focus-after-terminal-outcome, and status-badge greyscale legibility — satisfies R7 (status indicator), ux/a11y.md in full

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Implementation — session guard; Tests — session guard branches |
| R2 | Contracts and generated code — searchPartners client; Implementation — search-input state, mode switcher; Tests — contract tests |
| R3 | Implementation — client-side validation blocking; Validation and errors — validation_error surfacing; Tests — required-input validation |
| R4 | Same as R3 |
| R5 | Contracts and generated code — listAssignedUnderwriters client; Implementation — UW filter; Tests — UW filter tests |
| R6 | Implementation — result rendering; Tests — mode column rendering; Tests — contract tests |
| R7 | Implementation — By Broker mailto/status; Tests — mode column rendering; Tests — accessibility (status badge) |
| R8 | Implementation — empty-result state; Tests — empty-state/result-count |
| R9 | Implementation — result-count display; Tests — empty-state/result-count |
| R10 | Implementation — result-row navigator; Tests — row navigator mapping |
| R11 | Implementation — create-launch group; Tests — create-launch role gating |
| R12 | Implementation — pagination; Tests — contract tests |
| R13 | Implementation — responsive layout; Tests — responsive layout switch |
| R14 | Implementation — client-side validation blocking; Tests — required-input validation |
| R15 | Implementation — mismatched-field placeholder |
| R16 | Implementation — session guard; Tests — session guard branches |
| R17 | Implementation — access-denied state; Tests — session guard branches |
| R18 | Implementation — create-launch group; Tests — create-launch role gating |
| R19 | Implementation — request sequencer; Tests — request sequencer token discard |
| R20 | Same as R19 |
| R21 | Implementation — recoverable-error state; Validation and errors — 5xx/timeout surfacing; Tests — recoverable/terminal/rate-limited states |
| R22 | Implementation — loading indicator |
| R23 | Implementation — rate-limited state; Validation and errors — rate_limited surfacing; Tests — recoverable/terminal/rate-limited states |
| R24 | Implementation — request sequencer; Tests — request sequencer token discard |
| R25 | Implementation — re-authentication routing; Validation and errors — 401/403 surfacing; Tests — session guard branches |
| R26 | Implementation — result-row navigator |
| R27 | N/A design-level NFR — no discrete build task beyond the session/error handling above, which is what makes the bounded-availability statement true |
| R28 | Tests — request sequencer and loading-indicator tests exercise the latency budget in the target test environment; no separate implementation task, since R28 is a measured outcome of the implementation tasks above, not a feature |
| R29 | N/A — a load figure to test against, not a build task; exercised by the load-test referenced in capability.md M1, owned outside this unit's build checklist |
| R30 | Implementation — rate-limited state (this unit's only surge behaviour is honouring Retry-After, already tasked under R23) |
| R31 | Implementation — request sequencer (idempotency is a property of using only GET, already covered by the sequencer task) |
| R32 | Implementation — request sequencer |
| R33 | Implementation — rate-limited state |
| R34 | Implementation — session guard, access-denied state |
| R35 | Implementation — session guard (no tenant identifier ever handled — covered by not having a task that introduces one; verified by the session-guard tests) |
| R36 | N/A per requirements.md — no writes exist to audit, no task needed |
| R37 | Observability — client-side telemetry task |
| R38 | Observability — client-side telemetry task (exclusion of personal data) |
| R39 | N/A — no persistent client-side store to build |
| R40 | N/A — greenfield, no migration |
| R41 | N/A — no feature flag planned |
