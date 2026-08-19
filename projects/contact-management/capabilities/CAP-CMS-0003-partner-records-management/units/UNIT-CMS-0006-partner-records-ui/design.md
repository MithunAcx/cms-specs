---
unit: UNIT-CMS-0006
updated: 2026-08-18
---

# Design — Partner Records UI

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

This unit is a pure API-consuming presentation layer: it owns no persistent state
and no server-side logic of its own. It renders the Brokerage Detail, Agency Detail,
CGA, and reference-lookup-admin screens against UNIT-CMS-0005's closed CRUD contract,
and embeds three sibling units' own widgets (UNIT-CMS-0008's activity grid,
UNIT-CMS-0009's address-suggest, UNIT-CMS-0010's policy-read) rather than
reimplementing any of their behaviour.

The shape chosen is **screen-scoped state, no local cache layer**. Each screen loads
its own data on entry and holds it only for the lifetime of that screen instance;
there is no cross-screen client-side store reconciling a brokerage record edited on
one screen with the same record shown on another. This is the right shape because:
the capability's own volume constraint (`capability.md`, intake Q8 — "low hundreds of
brokerages/agencies/CGAs") does not justify the complexity of a shared cache and its
invalidation problem, and the optimistic-concurrency contract (XD-0002) already forces
every screen to re-fetch `version` before trusting a save regardless of whether a
cache exists. A shared client-side cache was considered and rejected: it would need
its own invalidation-on-`409` behaviour on top of what XD-0002 already requires at the
network boundary, buying nothing this capability's scale needs.

Rendered "static" content (dropdown option lists, e.g. R27) is fetched per screen
mount from UNIT-CMS-0005's lookup endpoints rather than bundled at build time, so an
Administrator's edit to a lookup (R25) is visible to other sessions without a
redeploy.

Embedded sibling widgets (UNIT-CMS-0008, UNIT-CMS-0009, UNIT-CMS-0010) are treated as
opaque components reached only through the linking context each already defines
(brokerage/agency id for the activity grid; a callback contract for address-suggest;
brokerage/agency id for policy-read). This unit never reaches into their internal
state or calls their upstream APIs directly — R35's isolation requirement (a failing
embedded panel must not break the rest of the screen) depends on that boundary being
real, not just documented.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Brokerage Detail screen | Master-details view/edit, Brokers grid, accounting-address dialog entry point, embeds activity/policy panels | R3, R5–R12, R30, R31, R35, R36, R37, R41, R42 |
| Agency Detail screen | Master-details view/edit, Agents grid, Specialty navigation, embeds activity/policy panels | R15–R20, R30, R31, R35–R37, R41, R42 |
| Add New Brokerage form | Create capture, address-suggest, cancel-to-directory, navigate-on-save | R1–R4, R28, R29, R32, R33, R38 |
| Add New Agency form | Create capture, address-suggest, two-choice confirm dialog | R13–R15, R28, R29, R32, R33, R38 |
| CGA grid screen | Inline add/edit keyed by CGA id, address-suggest per row, back-to-directory | R21–R24, R28, R29, R32, R33, R38, R41 |
| Reference-lookup admin screens | Role-gated view/edit of the five lookups | R25–R27, R39 |
| Inline grid editor (shared behaviour, used by Brokers/Agents/CGA grids) | Row-level edit toggling, per-row save against the matching child endpoint | R9, R18, R21, R38 |
| Accounting-address dialog | Focused edit of a brokerage's accounting fields only | R11, R12 |
| Conflict/error presenter (shared behaviour) | Maps UNIT-CMS-0005's error envelope to the distinguishable UI states in R31–R37, R40 | R31–R37, R40, R47, R53 |
| Session/role gate (shared behaviour) | Renders or hides create/edit/admin controls per session role | R20, R25, R26, R39, R50 |

## Flows

### Create a brokerage and add its first broker — satisfies R1, R2, R3, R9, R30

1. User opens the Add New Brokerage form (launched by UNIT-CMS-0004).
2. User fills master-detail fields; address entry uses UNIT-CMS-0009's suggest widget (R2), filling the XD-0004 address shape on acceptance.
3. Client-side validation (R28, R29) runs against required fields and formats (phone/zip/email/FEIN/date).
4. User submits; the create control disables (R38) until a response or error arrives.
5. UI calls UNIT-CMS-0005's brokerage create endpoint.
6. On `201`, the UI navigates to the Brokerage Detail screen for the returned id (R3), which loads the record including its initial `version`.
7. On the Detail screen, the user opens the Brokers grid and adds a broker inline (R9); this issues a separate create call scoped to that brokerage id — the brokerage record itself is not re-submitted.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 3 fails (client validation) | Save is blocked before any request is sent; offending fields identified inline (R32). |
| Step 5 returns `400` | Server-flagged fields mapped back to form fields; unmatched fields shown in a general error area (R33). |
| Step 5 times out / UNIT-CMS-0005 unavailable | Save reported as unresolved, not failed and not succeeded; create control re-enabled for exactly one manual retry (R37). |
| Step 5 double-fires (double-click) | Second submission is a no-op because the control was disabled at step 4 (R38). |
| Step 6 navigation target (Detail load) fails | Detail screen shows "unable to load" with retry (R36); the brokerage was still created — the user is not told creation failed. |
| Step 7 fails | Brokers grid row shows its own inline error; the rest of Detail screen is unaffected. |

### Edit a brokerage, agency, or CGA record and hit a stale version — satisfies R8, R30, R31

1. User loads a record (Brokerage/Agency Detail, or a CGA row); the current `version` is retained unmodified in screen state.
2. User edits fields and submits a save carrying that same `version` (R30 — the UI never fabricates or bumps it).
3. UNIT-CMS-0005 either accepts (returns the new `version`) or rejects with `409 conflict_version_mismatch` if the stored version has moved on.
4. On success, the UI shows a confirmation (R8) and updates the screen's held `version` from the response.
5. On `409`, the UI shows a distinguishable conflict message, preserves the user's unsaved edits, and offers an explicit reload-and-retry action rather than auto-merging or auto-discarding either side (R31).

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 3 returns `409` | Handled explicitly per step 5 above — never presented as a generic validation or server error. |
| Step 3 times out | Treated per R37 (unresolved, not failed) — a timeout must never be interpreted as a `409` or as success. |
| User chooses reload-and-retry after a `409` | Screen re-fetches the record (fresh `version`), discarding the stale local copy only on explicit user action, never automatically. |

### Two-choice confirmation after creating an agency — satisfies R15

1. User submits the Add New Agency form.
2. UNIT-CMS-0005 returns `201` with the new agency and its account code.
3. UI shows a dialog with exactly two actions: "Go to Agency Detail" and "Add another agency".
4. Choosing "Go to Agency Detail" navigates to that agency's Detail screen (same pattern as brokerage creation).
5. Choosing "Add another agency" resets the form to its initial empty state and returns focus to the agency-name field, remaining on the Add New Agency screen.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 fails | Handled identically to the brokerage-create failure table above (R32/R33/R37/R38). |
| Step 4/5 UI action itself fails to render (unexpected client error) | Out of scope for a server-failure table — this is a client defect, not a specified behaviour; not modelled further here. |

### Reference-lookup maintenance — satisfies R25, R26, R27, R39

1. Screen mounts; UI fetches the requested lookup type from UNIT-CMS-0005.
2. If the session role is Administrator, add/edit/delete controls render (R25); otherwise the list renders with no such controls (R26, R39).
3. An Administrator's edit submits to UNIT-CMS-0005's lookup write endpoint.
4. Every other screen in this unit that populates a dropdown from the same lookup type (R27) re-fetches it on its own mount — no shared in-memory cache is assumed to reflect an edit made moments earlier on another screen.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 1 fails | Screen shows "unable to load" with retry (R36); dropdowns elsewhere that depend on this lookup type independently retry per their own screen's load behaviour. |
| Step 3 returns `400` | Field-level errors mapped per R33. |
| Step 3 returns `403` (role changed mid-session) | Distinguishable "not permitted" message, not a validation error (R40). |

## Data model

This unit owns no persistent entity — see `requirements.md` Data. The only state
held is transient, in-browser, screen-scoped:

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| Screen-held record snapshot (Brokerage/Agency/Cga/Broker/Agent) | the id + `version` pair from UNIT-CMS-0005's last response | every field editable on that screen, plus the `version` used for optimistic concurrency (R30) | Held only for the screen instance's lifetime; discarded on navigation away. Never persisted client-side beyond the active session. |
| Reference-lookup values | lookup type | id/label/order pairs (R27) | Re-fetched per screen mount (see Flow 4, step 4); never persisted beyond that. |

## Contracts

This unit exposes no contract of its own — see `requirements.md` scope and
`capability-design.md`'s Unified API Contract, which records "partner-records-ui
(U2) — endpoints: None. U2 consumes every endpoint above." Its `interfaces/` folder
therefore holds copies of the contracts it consumes, per `shared-spec-conventions`'
rule that a consumer-only unit carries a copy of each depended-on unit's OpenAPI file
rather than an original.

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Consumption record (why, and error-code-to-outcome mapping, for every depended-on unit) | prose | `interfaces/consumed-contracts.yaml` | R1–R30, R31–R41, R43–R57 |
| UNIT-CMS-0005 Partner Records API (copy — byte-identical mirror, cursor pagination corrected 2026-08-19) | sync HTTP | `interfaces/UNIT-CMS-0005.openapi.yaml` | R1–R30, R31–R41, R43–R57 |
| UNIT-CMS-0010 Policy Integration API (copy — already published by its own unit) | sync HTTP | `interfaces/UNIT-CMS-0010.openapi.yaml` | R10, R19, R35, R47 |

UNIT-CMS-0005's own `interfaces/openapi.yaml` has since been authored and merged
(PR #56), including the fix for `capability-design.md`'s pagination convention
(`page`/`size` corrected to cursor-based `limit`/`cursor` in, `items`/`next_cursor`
out — see `capability-design.md`'s Change log, 2026-08-19). `interfaces/UNIT-CMS-0005.openapi.yaml`
here is now a byte-identical copy of that file, per `shared-spec-conventions`' rule
that a consumer unit carries a mirror rather than an original. This unit's own
`listBrokers`/`listAgents` consumption (R9, R18 — the Brokers/Agents grids) reads
`items`/`next_cursor` from that contract; given this capability's stated low-hundreds
volume (`capability.md`, intake Q8), each grid is expected to fit in a single page at
the default `limit` of 25, but the grid still follows `next_cursor` when present
rather than assuming a single page, so correctness does not depend on the volume
assumption holding.

UNIT-CMS-0009 (address-suggest) is still depended on by this unit but **has not yet
authored its own `interfaces/openapi.yaml`** — it remains mid-pipeline in this same
parallel work stream. Per `shared-spec-conventions`, a consumer unit's copy is only
ever a byte-identical mirror of a producer's *existing* file; there being nothing to
mirror yet, no `UNIT-CMS-0009.openapi.yaml` file is created here as a placeholder.
`consumed-contracts.yaml` records this explicitly as `PENDING`, naming the action
required (re-run `architect-unit-interfaces` for this unit once that producer's own
file exists).

Contracts for UNIT-CMS-0008 (activity grid) are that unit's own embedded-component
contract, not a network API, so no copy applies — this unit's Dependencies table
names it, and its own `interfaces/` (currently empty) would hold a machine-readable
form only if it ever exposes one.

## State and idempotency

**State machine.** This unit has no entity lifecycle of its own to model — every
lifecycle (brokerage/agency/CGA/broker/agent status, `disabled`/history) belongs to
UNIT-CMS-0005. The only state this design must pin down is **screen state**, which is
not a business lifecycle but is still worth naming because it is where R31/R37's
distinctions live:

```
idle → loading → loaded → editing → saving → (loaded | conflict | error | unresolved)
conflict → editing (user chooses reload-and-retry, discarding the conflicting attempt)
unresolved → saving (exactly one manual retry) | idle (user navigates away)
```

Invariant: a screen never shows a "saved" confirmation for a save whose response it did
not itself receive and parse as `200`/`201` — enforced by the confirmation UI reading
directly off the resolved response, never off the fact that a request was merely sent
(this is what keeps R37's unresolved-state distinct from a false success).

**Idempotency walk.** This unit issues no idempotency keys — `POST` creates are
non-idempotent per the capability's Unified API Contract (`capability-design.md`), and
`PUT` updates are idempotent by `(resource id, version)`, a guarantee UNIT-CMS-0005
owns. The paths that could otherwise perform a create's effect more than once, from
this unit's side, are:

| Path | Collapses to one because |
|---|---|
| First submission | The only attempt so far. |
| Double-click on submit | Submit control is disabled between click and response/error (R38) — no second request is constructible from the same form instance. |
| Client retry after a perceived failure (R37's "unresolved" case) | The design explicitly allows exactly one manual retry, and it is a **user-initiated** second `POST`, not an automatic one — the UI does not collapse this to one request; it surfaces the ambiguity ("unresolved") rather than silently retrying, because only UNIT-CMS-0005 (or its data) can determine whether the first attempt actually landed. This unit does not claim create-idempotency it does not own. |
| Browser refresh mid-submission | A fresh screen instance has no submit-in-flight state to resubmit; the create control starts idle, requiring a new explicit user action. |

**Concurrency matrix.**

| Two things at once | Who wins / what's observed | Enforcement |
|---|---|---|
| Two sessions load the same brokerage/agency/CGA record | Both succeed; each holds its own snapshot + `version` | Read is unrestricted; no locking |
| Both sessions save | First save UNIT-CMS-0005 accepts wins; second observes `409` (R31) | Storage-level — UNIT-CMS-0005's version check, not this unit's application logic (this unit only surfaces the outcome) |
| A grid inline-edit (broker/agent/CGA row) saved concurrently with the parent record's master-detail save | Independent — child and parent are separate endpoints/entities; no ordering dependency between them | N/A — separate resources |
| User's role changes mid-session (e.g. Editor access revoked) while a save is in flight | Save may be accepted or rejected `403` depending on when UNIT-CMS-0005 evaluates it; UI surfaces whichever actually happened (R40), never assumes | Storage/service-level authorization check, not this unit's |

**Answers that can change.** UNIT-CMS-0005's `version` field is itself the mechanism
by which a stale local answer is detected and never silently trusted — see the "hit a
stale version" flow. This unit holds no other data whose past answer could later be
revised (no cached decision survives past the screen instance).

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | This unit holds no tenant-scoped state; every request is scoped by the caller's session purely because it targets UNIT-CMS-0005's tenant-scoped endpoints. The UI never accepts or forwards a tenant identifier of its own (R51). |
| authn/authz | Session/role gating renders or hides controls per R20, R25, R26, R39, R50; the UI never treats "control not shown" as the authorization boundary itself — every save still relies on UNIT-CMS-0005 rejecting an unauthorized request, and R40 covers the case where the UI's rendered state and the server's live decision disagree. |
| validation | Client-side mirrors server rules for required fields and phone/zip/email/FEIN/date formats (R28, R29) as a UX improvement only; the server's rejection (R33) is still the authority and is always surfaced if it disagrees with the client's check. |
| errors | UNIT-CMS-0005's `{ code, message, details[], trace_id }` envelope (per `10-platform.md`) is mapped to per-field messages where `details[]` names a field, and to a general error area otherwise; `409 conflict_version_mismatch`, `403`, and `429` each get their own distinguishable presentation (R31, R40, R47) rather than falling into a generic error bucket. |
| observability | One structured client-side log per failed load or save, carrying the screen/action id, the HTTP status or error code, and `trace_id` — no personal data (R53). |
| performance | Screen loads target p95 1.5s/p99 3s measured from the underlying API call resolving (R44), consistent with the serverless cold-start consequence in `stack.md`; this unit does not attempt to hide cold-start latency, only to bound perceived wait with a loading state. |
| migration/backfill | None — greenfield UI, no prior version of these screens in this system to migrate from (R56). |
| feature flag | None required by any stated requirement (R57); if one is added later its off-state must fall back to a working prior screen, never a blank one, and must not discard an in-flight inline-grid edit. |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Embedded sibling widgets (UNIT-CMS-0008/0009/0010) are designed independently and could evolve a contract shape this unit doesn't expect | A previously-working embed silently breaks on the host screen | Mitigating — R35's isolation requirement (failing panel doesn't break the rest of the screen) contains the blast radius; the embed contracts are each that sibling unit's own interface, versioned independently per `10-platform.md`'s additive-versioning rule |
| No shared client-side cache means a value edited on one open screen is not reflected on another open screen for the same record until it reloads | A user editing the same record in two tabs can be surprised by R31's conflict message rather than seeing a live update | Accepting — R31 already specifies the correct, safe behaviour (reject and preserve edits) for this case; building live cross-tab sync was rejected in Approach as unjustified by this capability's volume |
| Serverless cold starts (stack.md) mean first-load latency after idle periods can exceed the steady-state p95/p99 in R44 | Perceived slowness on the first screen load of a session | Accepting — named explicitly as a stack consequence in `stack.md`; the loading-state requirement (R36's dependency-failure family) ensures the wait is visible and bounded rather than silent, but the absolute number is a platform constraint this unit cannot design around |
| Reference-lookup edits (R25) are not reflected on other open sessions/tabs until they reload a lookup | An Administrator's status-list edit doesn't appear to a Viewer already mid-session on a dependent screen | Accepting — consistent with the no-shared-cache approach; each screen mount re-fetches lookups (Flow 4), bounding staleness to "until next navigation", which is acceptable at this capability's low-hundreds volume |

## Decisions

No ADR raised for this unit. The screen-scoped, no-shared-cache approach in
Approach was a real alternative-vs-chosen decision, but it is reversible at low cost
(a cache layer can be added later without changing any contract this unit exposes,
since it exposes none) and is not contested — no ADR needed per the bar in
`architect-adr-record`.

| ADR | Decision |
|---|---|
| — | none |

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Flow: Create a brokerage and add its first broker |
| R2 | Flow: Create a brokerage and add its first broker; Approach (embedded widgets) |
| R3 | Flow: Create a brokerage and add its first broker |
| R4 | Components: Add New Brokerage form |
| R5 | Components: Brokerage Detail screen |
| R6 | Cross-cutting: validation |
| R7 | Components: Brokerage Detail screen |
| R8 | Flow: Edit a brokerage/agency/CGA and hit a stale version |
| R9 | Components: Inline grid editor; Flow: Create a brokerage and add its first broker |
| R10 | Approach (embedded sibling widgets); Components: Brokerage Detail screen |
| R11 | Components: Accounting-address dialog |
| R12 | Components: Accounting-address dialog |
| R13 | Components: Add New Agency form |
| R14 | Components: Add New Agency form |
| R15 | Flow: Two-choice confirmation after creating an agency |
| R16 | Components: Agency Detail screen |
| R17 | Cross-cutting: validation |
| R18 | Components: Inline grid editor |
| R19 | Approach (embedded sibling widgets); Components: Agency Detail screen |
| R20 | Components: Agency Detail screen; Cross-cutting: authn/authz |
| R21 | Components: CGA grid screen; Components: Inline grid editor |
| R22 | Components: CGA grid screen |
| R23 | Components: CGA grid screen |
| R24 | Components: CGA grid screen |
| R25 | Flow: Reference-lookup maintenance |
| R26 | Flow: Reference-lookup maintenance |
| R27 | Flow: Reference-lookup maintenance |
| R28 | Cross-cutting: validation |
| R29 | Cross-cutting: validation |
| R30 | State and idempotency: state machine; Flow: Edit a brokerage/agency/CGA and hit a stale version |
| R31 | Flow: Edit a brokerage/agency/CGA and hit a stale version; Concurrency matrix |
| R32 | Failure path tables (Create a brokerage); Cross-cutting: validation |
| R33 | Failure path tables (Create a brokerage); Cross-cutting: errors |
| R34 | Risks (embedded widgets); Components: Add New Brokerage/Agency/CGA forms (degrade to free-text) |
| R35 | Approach (embedded widgets as opaque components); Risks |
| R36 | Failure path tables (multiple flows) |
| R37 | Failure path tables (Create a brokerage); Idempotency walk |
| R38 | Idempotency walk; Components: Inline grid editor |
| R39 | Flow: Reference-lookup maintenance; Cross-cutting: authn/authz |
| R40 | Flow: Reference-lookup maintenance; Concurrency matrix; Cross-cutting: errors |
| R41 | Components: CGA grid screen (disabled is not a lock) |
| R42 | Cross-cutting (date handling — platform date-only rule, no dedicated section beyond this) |
| R43 | Cross-cutting: performance |
| R44 | Cross-cutting: performance |
| R45 | Approach (screen-scoped state, no shared cache — sized to low-hundreds volume) |
| R46 | Cross-cutting: performance (no unit-issued surge behaviour) |
| R47 | Cross-cutting: errors |
| R48 | Idempotency walk |
| R49 | Concurrency matrix |
| R50 | Cross-cutting: authn/authz |
| R51 | Cross-cutting: tenant isolation |
| R52 | Cross-cutting: errors/observability (no audit of its own) |
| R53 | Cross-cutting: observability |
| R54 | Data model; Cross-cutting: observability |
| R55 | Data model (no persistent store) |
| R56 | Cross-cutting: migration/backfill |
| R57 | Cross-cutting: feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
