---
unit: UNIT-CMS-0008
updated: 2026-08-19
---

# Design — Activity Grid UI

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

This unit is a pure consumer: it owns no server-side schema and exposes no contract
of its own (per CAP-CMS-0004's capability-design, U2 is "nothing persistent"). The
design is therefore a client-side interaction layer over UNIT-CMS-0007's four
endpoints — a list/query view plus four write actions (add, edit, mark-complete,
soft-delete) — packaged to accept a `parentType`/`parentId` pair from whichever host
screen embeds it, and holding no state that survives a remount.

The rejected alternative was letting this component cache and locally re-sort/re-filter
a full page of entries fetched once, to reduce round trips. That was rejected because
UNIT-CMS-0007's contract carries no concurrency token: a locally cached page can go
stale the moment another caller (or another tab of the same caller) writes to the
same parent, and this component has no way to detect that short of re-fetching. Every
sort, filter, or page change instead re-issues a list call with the new parameters,
so what is on screen is never more than one round trip old. This is the "no local
persistence" reading of the capability-design taken to its logical edge, not an
independent architectural choice — see Requirement coverage for R20.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| List/query view | Builds `limit`/`cursor`/`sort`/`completed` filter parameters, calls UNIT-CMS-0007's list endpoint, and renders the loading/loaded/empty/error/throttled states | R1, R2, R3, R17, R18, R20, R29 |
| Add action | Client-validates and submits a new entry; never offers a field for `userName`, `enteredDate`, `completedDate`, or `id` | R4, R5, R9, R10, R12, R14, R15, R28 |
| Edit action | Client-validates and submits changes to `statusId`/`note`/`followUpDate` on an existing, non-deleted entry | R6, R9, R10, R11, R12, R14, R15, R28 |
| Complete action | Single-action toggle that submits `completed: true` only; presents no completion-date input | R7, R9, R12, R14, R28 |
| Soft-delete action | Confirm-gated action that submits the delete call and removes the row from the default view on success | R8, R9, R11, R12, R14, R16, R28 |
| Role-gate presenter | Reads the caller's role from the session UNIT-CMS-0001 already established and renders write controls only for Editor | R12, R28 |
| Session-fault handler | Intercepts a `401` from any of the above and raises a session-expired state instead of a field or list error | R13 |
| Embedding adapter | Accepts `parentType`/`parentId` as external inputs and threads them, unmodified, into every call this unit makes | R9, R29 |

## Flows

### Initial load — satisfies R1, R2, R3, R17, R18, R20, R29

1. The host screen mounts this component, supplying `parentType`, `parentId`, and the
   caller's already-authenticated session (UNIT-CMS-0001).
2. The component calls UNIT-CMS-0007's list endpoint with that `parentType`/`parentId`,
   no `cursor` (first page), the default `limit` (25), sorted by follow-up date
   ascending, no completed filter applied.
3. On success, it renders the returned `items` and, if `next_cursor` is non-null, a
   "load more"/next-page control that re-issues the call with that cursor. There is no
   total count or page number to display — cursor pagination exposes neither.
4. A caller changing sort or the completed/open filter re-issues the list call from the
   first page (no cursor) with the new parameters; nothing is re-derived from a locally
   cached page (R20).

Failure paths:

| Step fails | Behaviour |
|---|---|
| List call times out or the connection fails (dependency down/slow) | Error state with a retry action; never rendered as an empty "no activity" grid (R17) |
| List call returns `429` | Throttled state honoring the returned `Retry-After`, not a silent failure (R18) |
| List call returns `401` | Session-expired state (R13); no further calls attempted until the host remounts the component post-re-auth |
| List call returns any other error | Generic error state naming the response's `trace_id`, for support — never a blank grid |

### Add an entry — satisfies R4, R5, R9, R10, R12, R14, R15, R28

1. An Editor-role caller opens the add form (the control is not rendered for any
   other role — R12/R28).
2. The caller supplies `statusId` (from the controlled list scoped to the parent
   type), `note`, and `followUpDate`. No other field is present in the form.
3. Client-side validation (status selected, date well-formed) gates whether submit
   is enabled (R10).
4. On submit, the control is disabled for the duration of the call (R14); the
   component calls UNIT-CMS-0007's create endpoint with `parentType`, `parentId`,
   `statusId`, `note`, `followUpDate` — no `userName`, `enteredDate`, `completedDate`,
   or `id` value is ever constructed to send (R5).
5. On success, the returned entry (carrying the server-derived `id`, `userName`,
   `enteredDate`) is added to the current view if it matches the active filter/sort,
   and the form closes.

Failure paths:

| Step fails | Behaviour |
|---|---|
| `400`/`422` (invalid `statusId` for this parent type, malformed date) | Inline field-level error from the response's `details[]`; submit re-enabled; no automatic retry (R10) |
| `401` | Session-expired state; the caller's entered values are retained in the still-open form so nothing is lost once re-authenticated (R13) |
| `429` | Throttled message honoring `Retry-After`; submit re-enabled once it elapses (R18) |
| Timeout / network error, outcome unknown | The component re-fetches the list rather than assuming failure or retrying the write blindly; if the entry now appears, the form closes as a success, otherwise submit is re-enabled (R15) |

### Edit an entry — satisfies R6, R9, R10, R11, R12, R14, R15, R28

1. An Editor-role caller opens the edit form for a visible (non-deleted) row,
   pre-populated with its current `statusId`/`note`/`followUpDate`.
2. Steps 3–4 mirror Add, calling UNIT-CMS-0007's update endpoint for that entry's id.

Failure paths:

| Step fails | Behaviour |
|---|---|
| `400`/`422` | Same as Add's row above (R10) |
| `404` (the entry was concurrently removed, or the id is stale) | "No longer available" shown; the row is removed from the local grid without a crash (R11) |
| `401` | Session-expired state, edits retained locally (R13) |
| `429` | Throttled, per Add (R18) |
| Timeout, outcome unknown | List re-fetch reconciliation, per Add (R15) |

### Mark an entry complete — satisfies R7, R9, R12, R14, R28

1. An Editor-role caller triggers the single "mark complete" action on an open entry
   — there is no text or date field involved.
2. The control disables for the call's duration (R14); the component calls
   UNIT-CMS-0007's update endpoint with `completed: true` only.
3. On success, the grid displays the server-returned `completedDate`; the component
   never constructs or sends a completion-date value of its own (R7).

Failure paths:

| Step fails | Behaviour |
|---|---|
| `404` | "No longer available", row removed (R11) |
| `401` | Session-expired state (R13) |
| `429` | Throttled, per Add (R18) |
| Timeout, outcome unknown | List re-fetch reconciliation (R15) |

### Soft-delete an entry — satisfies R8, R9, R11, R12, R14, R16, R28

1. An Editor-role caller triggers delete and confirms a second, explicit step (delete
   is otherwise irreversible from the caller's perspective).
2. The control disables for the call's duration (R14); the component calls
   UNIT-CMS-0007's soft-delete endpoint for that entry's id.
3. On a `204`, the row is removed from the default view without a full reload. A
   `204` on an entry already soft-deleted (reachable only via a stale local
   reference, since the default view never shows a soft-deleted row) is treated
   identically to a first-time delete, matching UNIT-CMS-0007's own idempotent
   delete-by-id contract (R16).

Failure paths:

| Step fails | Behaviour |
|---|---|
| `404` (never existed) | "No longer available", row removed (R11) |
| `401` | Session-expired state (R13) |
| `429` | Throttled, per Add (R18) |
| Timeout, outcome unknown | List re-fetch reconciliation — the component confirms whether the row is gone before reporting success or re-enabling the control (R15) |

## Data model

This unit owns no entity of its own. `Activity` is read and written only through
UNIT-CMS-0007's contract; the machine-readable shape is defined there and copied
into this unit's `interfaces/` per convention, not re-specified here.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| Activity (read/write via UNIT-CMS-0007 only — no local store) | `id`, as returned by UNIT-CMS-0007 | `parentType`, `parentId`, `statusId`, `note`, `followUpDate`, `enteredDate`, `completed`, `completedDate`, `userName` (never client-writable) | None — an ephemeral, in-memory client-side representation only, discarded whenever the component unmounts (R20) |

## Contracts

This unit exposes no contract of its own — CAP-CMS-0004's capability-design lists no
endpoints for U2. It consumes UNIT-CMS-0007's four `/api/v1/activity` endpoints as a
closed shape; per the shared conventions, a consumer-only unit carries a **copy** of
the producer's contract file rather than an original.

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| UNIT-CMS-0007's activity contract (consumed; derived from capability-design.md pending UNIT-CMS-0007's own publication — see the file's own header comment) | sync HTTP | `interfaces/UNIT-CMS-0007.openapi.yaml` | R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R13, R16, R17, R18, R28, R29 |
| Index of every contract this unit consumes, why, and the error→outcome map | prose (authored, not machine-generated) | `interfaces/consumed-contracts.yaml` | R10, R11, R13, R15, R17, R18 |

## State and idempotency

**State machine (interaction-level, not entity-level — this unit owns no entity
lifecycle).** Per mount: `idle → loading → { loaded | error | throttled | session-expired }`.
From `loaded`, each row/action independently enters `submitting-<action>` and returns
to `loaded` (success) or `loaded` with an inline field/row error (failure); `loaded`
itself never blocks on one row's in-flight action. `session-expired` is terminal for
that mount — the component issues no further calls until the host remounts it after
re-authentication.

Invariant: at most one write in flight per row, per mount. This is enforced by
disabling that row's controls for the call's duration (R14) — a UI-only guarantee,
not a system-wide one, since a stateless client component holds no lock a second
browser tab could observe. The concurrency matrix below is what actually protects
correctness across tabs/callers; the invariant here only prevents a single UI
surface from firing a duplicate click.

**Idempotency walk.** This unit issues writes only by calling UNIT-CMS-0007; it
derives no idempotency key of its own (that is UNIT-CMS-0007's obligation, XD-0002 /
XD-0003). Walking every path that could perform an effect:

- **First attempt:** one call, submit disabled until the response arrives (R14).
- **Client retry (deliberate, after a visible failure):** only reachable once the
  control is re-enabled, i.e. after the prior call definitively failed — so it is a
  new, separate request against a request already known to have failed, not a
  duplicate of one still in flight.
- **Duplicate schedule fire:** not applicable — this unit runs no scheduled or
  background job.
- **At-least-once redelivery:** not applicable — this unit is not a message consumer.
- **Timeout, outcome unknown:** never blindly retried. R15 mandates a list re-fetch
  to observe ground truth before any further write is permitted, which is what
  prevents this component from ever issuing a duplicate create/update/delete for an
  attempt whose result it never saw.
- **Crash before the call:** no local effect exists yet; nothing to reconcile.
- **Crash after the call, before the outcome is recorded (e.g. tab closed
  mid-submit):** this unit holds no durable "I attempted this" record of its own —
  a remount always re-fetches fresh from UNIT-CMS-0007 (R20) rather than
  reconstructing state from a stale local flag.
- **Concurrent second caller:** resolved by R16 below — this unit performs no merge
  and simply displays whichever state UNIT-CMS-0007 last returned.

**Concurrency matrix**

| Two things at once | Who wins | Enforcement |
|---|---|---|
| Two tabs/callers editing the same entry | The later `PUT` reaching UNIT-CMS-0007 is authoritative; the earlier tab's view is stale until its next re-fetch | Storage-level, inside UNIT-CMS-0007 — this unit performs no read-then-write merge (R16/R26) |
| Two callers add distinct entries for the same parent concurrently | Both succeed independently; no shared key contends | N/A — no uniqueness constraint between two new entries |
| A caller double-clicks "mark complete" | Second click is inert — the control disables after the first (R14); if a network race still produced two in-flight `PUT`s, both carry `completed: true` against the same id, so the effect is identical either way | Application-level (R14) plus UNIT-CMS-0007's own idempotent-by-id `PUT` |
| A delete lands while another caller has that entry's edit form open | The delete completes first; the pending edit's submit then receives a `404`, handled per R11 | UNIT-CMS-0007's delete-then-404 behavior; this unit only reacts (R11) |
| Two callers load the list at the same moment | Independent reads, no contention | N/A |

**Answers that can change.** Not applicable to this unit — it holds no decision of
its own to later revise. If UNIT-CMS-0007 later returns a different state for an
entry than a previous response showed, this component simply displays the newer
response the next time it fetches or receives one (R15/R20); there is no local
verdict here to re-evaluate, silently void, or delete.

**Event durability.** Not applicable — this unit emits no events. It makes only
synchronous HTTP calls to UNIT-CMS-0007, and any audit trail those calls produce is
UNIT-CMS-0007's and CAP-CMS-0001's responsibility (R30).

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | This unit constructs no tenant selector of its own — every call carries only `parentType`/`parentId` plus the bearer token UNIT-CMS-0001 already scoped to one tenant. Isolation is enforced server-side by UNIT-CMS-0007's row-level-security policy on every operation, reads included; this unit has nothing further to enforce (R29) |
| authn/authz | The session/bearer token comes from the host screen via UNIT-CMS-0001; the caller's role (Viewer/Editor) is read from that same session to gate which write controls render (R12/R28). A `401` from any call is always treated as session-expired, never retried by this unit (R13) |
| validation | Every write is client-validated first (status from the controlled list, well-formed date — R10), but the server remains the authority; a client-side pass never substitutes for the server's own `400`/`422` |
| errors | Every UNIT-CMS-0007 error follows the platform envelope `{ code, message, details[], trace_id }` (`10-platform.md`); field-scoped entries in `details[]` map to the offending form control, non-field errors render as a banner naming the response's `trace_id` |
| observability | A failed call logs the entry id (where known), the attempted operation, and the returned status/code; `note` and every other personal-data field are excluded from every log line (R31/R32) |
| performance | p95 ≤ 800 ms / p99 ≤ 2 s to a populated first page (R22), budgeted against UNIT-CMS-0007's own cold-start-inclusive latency. A slow response shows the loading state, never stale cached data standing in for it |
| migration/backfill | None — greenfield component with no data of its own to migrate (R34) |
| feature flag | None requested for this unit; not designed (R35) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Two browser tabs open against the same entry — R14's in-flight guard is per-tab, not per-entry across tabs | A caller could still fire two competing writes for one entry from two tabs | Accepted — R16 already defines last-write-wins as the resolution; a cross-tab lock was not requested and would be unrequested scope |
| `note` is free text and may incidentally carry special-category content (health, biometric, or anything revealing them) | Correctly excluded from logs/analytics by R31/R32 today, but a future instrumentation change could reintroduce it by accident | Mitigating — flagged explicitly here and in requirements so any later telemetry work is reviewed against this exclusion before shipping |
| UNIT-CMS-0007's serverless cold starts could regularly approach or exceed the p99 budget under real traffic | Caller perceives the grid as slow after an idle period | Accepted at this unit's boundary — warming/provisioned-concurrency mitigation belongs to UNIT-CMS-0007's own design; this unit only states the budget it must not itself add to |

## Decisions

No decision at this unit's own boundary was contested or hard-to-reverse enough to
warrant an ADR here. The two choices that would usually earn one — the polymorphic
`Activity` shape (XD-0001) and the absence of a concurrency token in the contract —
are already fixed at CAP-CMS-0004's capability-design level, not a call this unit is
free to make differently; recording them again here would duplicate, not add,
record.

| ADR | Decision |
|---|---|

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Initial load flow; List/query view component |
| R2 | Initial load flow (filter/sort combination); List/query view component |
| R3 | Initial load flow (pagination); List/query view component |
| R4 | Add an entry flow; Add action component |
| R5 | Add an entry flow step 4; Add action component |
| R6 | Edit an entry flow; Edit action component |
| R7 | Mark an entry complete flow; Complete action component |
| R8 | Soft-delete an entry flow; Soft-delete action component |
| R9 | Embedding adapter component; present in every flow's step 1 |
| R10 | Add/Edit flows' failure-path tables (400/422 row); validation cross-cutting row |
| R11 | Edit/Complete/Soft-delete flows' failure-path tables (404 row) |
| R12 | Role-gate presenter component; every flow's step 1 |
| R13 | Session-fault handler component; every flow's failure-path table (401 row); authn/authz cross-cutting row |
| R14 | State machine invariant; every flow's submit step |
| R15 | Idempotency walk ("timeout, outcome unknown"); every flow's failure-path table |
| R16 | Concurrency matrix; Soft-delete flow step 3 |
| R17 | Initial load flow's failure-path table (timeout/down row) |
| R18 | Every flow's failure-path table (429 row) |
| R19 | Data model (followUpDate as a date-only field passed through unmodified to/from UNIT-CMS-0007) |
| R20 | Approach (rejected caching alternative); Initial load flow step 4; Data model retention column |
| R21 | Cross-cutting performance row |
| R22 | Cross-cutting performance row |
| R23 | Approach; this unit issues no independent-of-caller-action traffic |
| R24 | Cross-cutting performance row; R14 (own duplicate-submit guard) |
| R25 | Idempotency walk (this unit derives no key of its own) |
| R26 | Concurrency matrix |
| R27 | Every flow's failure-path table (429 row) |
| R28 | Role-gate presenter component; every flow's step 1 |
| R29 | Cross-cutting tenant isolation row; Embedding adapter component |
| R30 | Event durability (not applicable — audit is UNIT-CMS-0007's/CAP-CMS-0001's) |
| R31 | Cross-cutting observability row |
| R32 | Cross-cutting observability row; Risks (note field) |
| R33 | Data model retention column |
| R34 | Cross-cutting migration/backfill row |
| R35 | Cross-cutting feature flag row |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
| 2026-08-19 | — | Corrected list/query view, initial-load flow, and Cross-cutting → errors row from `page`/`size` offset pagination and the stale `{ error: { code, message, fields? } }` envelope to UNIT-CMS-0007's corrected cursor-based contract (`limit`/`cursor` in, `items`/`next_cursor` out) and the platform envelope `{ code, message, details[], trace_id }`, matching `capability-design.md`'s correction and the re-synced `interfaces/UNIT-CMS-0007.openapi.yaml`. Direct correction — unit is `ready`, not yet handed off. |
