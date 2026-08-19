---
unit: UNIT-CMS-0004
updated: 2026-08-18
---

# Design — Partner Directory UI

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

This unit is a single screen with no persistent state of its own: it collects a
search input (a mode plus a term, a state, or an underwriter selection), issues one
read call to UNIT-CMS-0003, and renders the result. The whole design problem is
therefore not "how is data stored" but "how is a stream of user-driven input changes
reconciled against a stream of asynchronous responses without ever showing the wrong
one" — the classic race between the third-latest keystroke's response and the
latest one's.

The shape chosen is a **single search-input state machine** with a monotonic
per-input-change sequence token attached to every outbound request. Every response
carries that token back (client-side correlation, not a server contract change);
the screen renders a response only if its token matches the current sequence
number, and discards it otherwise. This satisfies R20/R24 without needing request
cancellation to actually succeed at the network layer — cancellation is attempted
as an optimization, but correctness never depends on it succeeding, only on the
token check at render time.

The alternative considered was **debounce-only** (delay every request by a fixed
window before firing, relying on the delay to prevent overlapping requests). This
was rejected: debounce reduces the *frequency* of races but does not eliminate them
— a slow response to an early request can still arrive after a fast response to a
later one, especially given the confirmed serverless cold-start behaviour
(`stack.md`), where the first invocation in a given period is disproportionately
slower than the rest. A design whose correctness depends on relative response
timing rather than an explicit token is exactly the kind of bug that appears only
under load and is expensive to diagnose later, so the token approach was chosen
even though it needs one more field in-memory. This is not contested enough to
warrant an ADR — it is the direct, non-alternative fix for a described failure
mode, not a hard call between two legitimate designs.

Search modes (R2) are treated as **one input state**, not six components — a single
"search input" concept with a `mode` field that determines which of `term` /
`state` is active and which is hidden, mirroring capability-design's XD-0001
decision to keep this a single query family rather than six independent flows on
the API side. The Assigned Underwriter filter (R5) is modelled as a **second,
independent input state** that supersedes the mode-driven one when active, per its
own behaviour detail in requirements.md — not a seventh mode, because selecting it
does not compose with mode/term/state the way the six modes compose with each
other.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Search input state | Holds the current mode, term, state, and UW-filter selection; the single source of truth for what the *next* request will ask | R2, R3, R4, R5 |
| Request sequencer | Assigns a monotonic token to every outbound request from the search input state; attempts to cancel the previous in-flight request; discards any response whose token is not the current one | R19, R20, R24 |
| Result renderer | Renders the response's items using the mode-specific column set, the count, and the empty/loading/error states | R6, R7, R8, R9, R13, R15, R21, R22 |
| Row navigator | Resolves a clicked row's mode to a detail-screen family and navigates with the row's entity id | R10, R26 |
| Create launcher | Renders the "Add New Agency"/"Add New Brokerage" entry points, gated on role | R11, R18 |
| Session guard | Confirms an authenticated session with sufficient role before the screen renders search input or results; redirects otherwise | R1, R16, R17, R25, R34 |
| Rate-limit handler | Recognizes a `429` from the search/lookup calls, surfaces the rate-limited state, and honours `Retry-After` before any automatic retry | R23 |

## Flows

### Run a search — satisfies R2, R3, R4, R6, R8, R9, R12, R19, R20, R24

1. User selects a mode (or the mode is already selected from a prior search) and
   enters a term or selects a state, per that mode's requirement (R3/R4).
2. User submits. The search input state is validated client-side (non-empty term
   for term-required modes, a selected state for state modes); an invalid
   submission stops here with an inline message and no request is sent.
3. The request sequencer increments the sequence token, attempts to cancel any
   request still in flight for the previous token, and issues one `GET` to
   UNIT-CMS-0003's `/search` endpoint with `mode`, `term`/`state`, `page=1`, and
   the default page size.
4. On response, the sequencer compares the response's originating token to the
   current token. A stale response (R20/R24) is discarded silently — no error is
   shown, since the user has already moved on.
5. A current-token response renders: items per mode's column set (R6), the empty
   state if zero items (R8), and the total count (R9).
6. Subsequent pages are requested the same way, incrementing `page` on the same
   mode/term/state and reusing the current sequence token's mode context (a new
   page request gets its own new token per step 3, since it is itself a new
   outbound request).

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 3 — UNIT-CMS-0003 unreachable / 5xx | R21: retryable error state shown, distinct from the empty-result state; the search input state is preserved so the user can retry without re-entering it |
| Step 3 — response slower than the loading threshold | R22: a loading indicator is shown; the screen does not appear frozen |
| Step 3 — `429` returned | R23: rate-limited message shown; the `Retry-After` value gates any automatic retry; a manual re-submit is always available regardless |
| Step 4 — response arrives after a newer request already superseded it | Discarded per R20/R24; the newer request's own response (or its own pending/loading state) is what the user sees |
| Step 3 — access token expired mid-request | R25: the call fails authorization; the screen routes to the session guard's re-authentication flow rather than rendering the 401 as a data error |

### Assigned Underwriter filter — satisfies R5

1. User selects an underwriter from the dropdown, populated at screen load (and on
   later refresh) from `/lookups/assigned-uws`.
2. Selecting a value runs the same "Run a search" flow above, with an implicit
   By-Brokerage-shaped request scoped to that underwriter — it goes through the
   same request sequencer and token discipline, so a UW-filter search and a
   mode-driven search racing each other resolve exactly like two mode searches
   racing each other (last token wins).
3. Returning to the six-mode switcher after a UW-filter search clears the UW
   selection's precedence; the mode switcher's own state (last mode/term/state
   used, if any) resumes.

Failure paths: identical to "Run a search" above — the UW filter is not a separate
request path, only a separate way of constructing the search input state.

### Open a result — satisfies R10, R26

1. User selects a row.
2. The row navigator resolves the target detail-screen family from the mode that
   produced the current result set (R10) — never from inspecting the row's own
   fields — and navigates using the row's entity id.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 — target entity was deleted/withdrawn since the search ran | Navigation still occurs (R26); the destination screen's own not-found handling applies. This unit has no way to detect staleness without a second round-trip that no requirement asks for, and adding one would be scope creep against capability.md's non-goals |

### Launch a create flow — satisfies R11, R18

1. User selects "Add New Agency" or "Add New Brokerage".
2. The create launcher checks the session's role before rendering the control at
   all (R18) — an insufficient role means the control is absent, not disabled.
3. Selecting it navigates to the external create flow; no request is made by this
   unit.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 — role check cannot be resolved (session guard has not yet confirmed the session) | The control renders only after the session guard resolves (R1/R16/R17); it is never shown speculatively then hidden |

## Data model

This unit owns no entity and holds no data beyond the current page view's
in-memory state (R39). The only "model" is the transient search input state and
the last rendered response, both discarded on navigation or reload.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| Search input state (transient, in-memory) | n/a — not persisted | mode, term, state, uw-filter, sequence token, page | Discarded on navigation/reload; never written to durable client storage |
| Last rendered result page (transient, in-memory) | n/a — not persisted | items (per mode shape), total, page, size | Same as above |

## Contracts

This unit exposes no API of its own (per capability-design.md, U2 owns "nothing of
its own"). It consumes UNIT-CMS-0003's two endpoints as a closed shape.

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| UNIT-CMS-0003 `/api/v1/search` (consumed, copy) | sync HTTP | `interfaces/UNIT-CMS-0003.openapi.yaml` | R2, R3, R4, R5, R6, R7, R9, R10, R12 |
| UNIT-CMS-0003 `/api/v1/lookups/assigned-uws` (consumed, copy) | sync HTTP | `interfaces/UNIT-CMS-0003.openapi.yaml` | R5 |

## State and idempotency

**State machine.** The search input state has four states: `idle` (no search run
yet — the initial landing state), `loading` (a request is in flight for the
current token), `resolved` (a current-token response was rendered, holding results
or the empty state), and `error` (a current-token response failed dependency-side
— R21/R23). Transitions: `idle → loading` on first submit; `loading → resolved` on
a matching-token success; `loading → error` on a matching-token failure;
`resolved|error → loading` on any new submit (mode change, term change, page
change, UW-filter select) that produces a new token. A stale (non-matching-token)
response or failure causes **no transition at all** — the state machine only ever
reacts to its own current token. This is the invariant: *the rendered state always
corresponds to the most recently issued request*, enforced by the token comparison
at response-handling time, not by hoping responses arrive in order.

**Idempotency walk.** Every call this unit makes is a `GET` (search, lookups) —
inherently side-effect-free and safe to issue any number of times. There is no
effect to collapse to "exactly once" here, because there is no effect: a duplicate
search fired by R19's double-submit guard does not have a wrong-outcome case the
way a write would, since two identical `GET`s produce two identical (or
token-discarded) reads, never a double-applied effect. R19's de-duplication is
therefore a UX/cost concern (avoid redundant network calls), not a correctness
requirement — stated as such in requirements.md R31.

**Concurrency matrix.**

| Two things at once | Who wins | Enforcement |
|---|---|---|
| Two search submissions from the same user (mode change then immediate term change) | The later-tokened request's response | Client-side token comparison — no storage-level construct applies, since this unit holds no store |
| A search response and a UW-filter response racing (user clicked the UW dropdown right after submitting a mode search) | The later-tokened response, regardless of which input path produced it | Same token mechanism — token is issued per request, not per input path |
| A slow (cold-start-affected) response arriving after a fast subsequent response | The fast (later-tokened) response already rendered; the slow one is discarded on arrival | Token comparison |
| Role check (create-launcher visibility) racing the session guard's own resolution | The role check never runs until the session guard has resolved | Sequencing: create-launcher rendering is gated behind session-guard completion, not parallel to it |

No case in this unit needs storage-level enforcement, because this unit performs
no writes and owns no store. That is a property of the unit's scope, not an
oversight.

**Answers that can change.** This unit never bases a decision on an upstream
answer about the past that could later be revised (e.g. a corrected search result)
— every response is treated as current-truth-at-render-time, and a later, fresher
response simply supersedes it via the same token mechanism. There is no "decision
already made" to re-evaluate, since this unit takes no action on a search result
beyond displaying it and navigating on click (R26 already covers the one case
where the underlying entity changed after render).

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | This unit never handles, stores, or transmits a tenant identifier; every request carries only the session's bearer token, and tenant scoping is enforced entirely server-side by UNIT-CMS-0003 under PostgreSQL row-level security (`stack.md`). Satisfies R35. |
| authn/authz | Session guard (component above) confirms an authenticated session before any search input renders (R16); role read from the same session gates the create launchers (R11/R18) and produces an explicit access-denied state for a below-Viewer role (R17), never a silently empty screen. No token issuance/validation logic lives here — that is UNIT-CMS-0001's contract. |
| validation | Client-side only, and non-authoritative: empty-term and no-state-selected checks (R3/R4) block submission before a request is sent, but UNIT-CMS-0003 remains the authority on request validity (e.g. its own `400` for a missing required term) — this unit's validation is a UX convenience, never a substitute for the API's own check. |
| errors | Dependency errors are surfaced per the failure tables above (retryable-error / rate-limited / loading) rather than as raw API error envelopes; the underlying `{ code, message, details[], trace_id }` envelope (10-platform.md) is available for support diagnosis via observability (below) but is not shown verbatim to the end user. |
| observability | Per-search client telemetry: mode, latency, result count, error class (R37) — no term, email, or other field value included, since a search term can itself be personal data (a person's name typed by the searcher). |
| performance | Latency budget (R28) is met by issuing exactly one request per search (no client-side fan-out across modes) and by the token/discard mechanism never blocking a new request on a prior one completing — a new submission fires immediately rather than queuing behind the in-flight one. |
| migration/backfill | N/A — greenfield unit, no prior client state to migrate (R40). |
| feature flag | N/A — no flag planned; this is the landing route and cannot be toggled off without leaving the application without a home screen (R41). |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| UNIT-CMS-0003's response item shape diverges per mode in a way this unit's column mapping (R6) does not anticipate | Wrong or missing columns rendered, discovered late | The copied contract file (`interfaces/UNIT-CMS-0003.openapi.yaml`) must be re-synced whenever UNIT-CMS-0003's own contract changes — flagged for `ba-spec-validate`'s I11 staleness check; no runtime mitigation exists on this side |
| Serverless cold starts on UNIT-CMS-0003 make R28's p99 budget tight under real traffic patterns rather than the load-test's synthetic ones | User-perceived slowness at the tail, discovered post-launch | Accepting — this unit's only lever is the loading-state (R22) and error-state (R21) UX; the underlying latency is UNIT-CMS-0003's/`stack.md`'s to own |
| UNIT-CMS-0006 (assumed detail/create owner, requirements.md Q1) turns out not to be the right unit ID | Navigation targets wrong routes | Mitigating — Q1 is an open, non-blocking question; the row navigator's mode-to-screen-family mapping is a single decision point, cheap to correct once Q1 resolves |
| Token-based stale-response discarding is a client-only safeguard; a developer reimplementing this unit on a different stack could omit it, believing debounce alone suffices | Reintroduces the exact race this design exists to prevent | Named explicitly in Approach and State/idempotency above, so the requirement (R20/R24) and the mechanism are both on record, not just the requirement |

## Decisions

No ADR raised for this unit. The token-vs-debounce choice in Approach was a
direct fix for a described failure mode with no genuinely close alternative, not a
contested or hard-to-reverse call — it does not meet the bar `architect-adr-record`
sets.

| ADR | Decision |
|---|---|
| — | none |

## Requirement coverage

Every R-ID in `requirements.md` must appear here.

| R-ID | Covered by |
|------|-----------|
| R1 | Session guard; Cross-cutting authn/authz |
| R2 | Search input state; Run a search flow |
| R3 | Run a search flow, step 2 |
| R4 | Run a search flow, step 2 |
| R5 | Assigned Underwriter filter flow |
| R6 | Result renderer; Run a search flow, step 5 |
| R7 | Result renderer |
| R8 | Result renderer; Run a search flow, step 5 |
| R9 | Result renderer; Run a search flow, step 5 |
| R10 | Open a result flow |
| R11 | Launch a create flow |
| R12 | Run a search flow, step 6; Contracts |
| R13 | Result renderer (responsive rendering is a UX-layer decision detailed in `ux/`; this unit's design fixes that both layouts share the same data source and row-open behaviour) |
| R14 | Run a search flow, step 2 (whitespace-only term treated as empty during the same validation check) |
| R15 | Result renderer failure handling |
| R16 | Session guard; Cross-cutting authn/authz |
| R17 | Session guard; Cross-cutting authn/authz |
| R18 | Launch a create flow |
| R19 | Request sequencer; State and idempotency (idempotency walk) |
| R20 | Request sequencer; State and idempotency (state machine, concurrency matrix) |
| R21 | Run a search flow — failure paths |
| R22 | Run a search flow — failure paths |
| R23 | Rate-limit handler; Run a search flow — failure paths |
| R24 | Request sequencer; Concurrency matrix |
| R25 | Session guard; Run a search flow — failure paths |
| R26 | Open a result flow — failure paths |
| R27 | Cross-cutting performance (bounded by UNIT-CMS-0003's own availability, stated in requirements.md) |
| R28 | Cross-cutting performance |
| R29 | Cross-cutting performance (volume assumption carried from requirements.md) |
| R30 | Cross-cutting performance; Rate-limit handler (no shedding of its own) |
| R31 | State and idempotency (idempotency walk) |
| R32 | Concurrency matrix |
| R33 | Rate-limit handler |
| R34 | Session guard; Cross-cutting authn/authz |
| R35 | Cross-cutting tenant isolation |
| R36 | N/A per requirements.md — no design section needed; no writes exist to audit |
| R37 | Cross-cutting observability |
| R38 | Cross-cutting observability (exclusion of personal data from telemetry); Data model |
| R39 | Data model |
| R40 | Cross-cutting migration/backfill |
| R41 | Cross-cutting feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
