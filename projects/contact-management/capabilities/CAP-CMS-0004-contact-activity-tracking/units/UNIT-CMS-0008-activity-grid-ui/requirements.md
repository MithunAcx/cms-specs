---
id: UNIT-CMS-0008
slug: activity-grid-ui
project: CMS
capability: CAP-CMS-0004
title: Activity Grid UI
kind: frontend
target_repo: CMS-web
owner: "@MithunAcx"
engineering:
  frontend: { applicable: true }
  api:      { applicable: false }
created: 2026-08-18
updated: 2026-08-18
---

# Activity Grid UI

## Scope

A reusable activity-log grid component (list/add/edit/soft-delete) consuming
UNIT-CMS-0007's contract, packaged for embedding into a host screen owned by another
unit (UNIT-CMS-0006's Brokerage/Agency Detail). Independently verifiable against
UNIT-CMS-0007's contract in isolation, before any host screen embeds it.

**In scope:**
- Activity list/add/edit/soft-delete UX, inline within a host screen
- "What's owed next" sort/filter by follow-up date and completed state
- Packaging as an embeddable component with a defined parent-reference input

**Out of scope:**
- Which screen embeds it, or that screen's own layout (UNIT-CMS-0006)
- Activity persistence, soft-delete semantics, or the `UsrName` stamp itself (UNIT-CMS-0007)

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | The grid lists activity entries for one caller-supplied `parentType`/`parentId`, excluding soft-deleted entries, defaulting to sort by follow-up date ascending | CAP-CMS-0004/A3 | Must |
| R2 | The grid can be filtered by completed/open state, combinable with the follow-up-date sort, to surface "what is owed this partner next" | CAP-CMS-0004/A3 | Must |
| R3 | The grid paginates per UNIT-CMS-0007's page/size contract, displaying total count and current page, for either parent type | CAP-CMS-0004/A3 | Must |
| R4 | A caller holding Editor role can add a new entry by supplying task type/status, note, and follow-up date; on submit the component calls UNIT-CMS-0007's create endpoint with the host-supplied `parentType`/`parentId` | CAP-CMS-0004/A1, FR-ACT-2/3 | Must |
| R5 | A newly created entry is added to the grid showing the server-returned id, `userName`, and `enteredDate`, without a full page reload; the add form never presents a `userName` field for the caller to set | CAP-CMS-0004/A1, M1 | Must |
| R6 | A caller holding Editor role can edit an existing, non-deleted entry's task type/status, note, and follow-up date | FR-ACT-3 | Must |
| R7 | Marking an entry complete sets its `completed` flag via UNIT-CMS-0007's update endpoint; the grid displays the server-returned `completedDate`; the UI never presents an editable completion-date field | CAP-CMS-0004/A2 | Must |
| R8 | A caller holding Editor role can soft-delete an entry via a confirm step; on success the entry is removed from the default grid view without a full page reload; the delete control is not rendered for a caller without Editor role | CAP-CMS-0004/A4, FR-ACT-3 | Must |
| R9 | The component is packaged to accept `parentType` and `parentId` as external inputs from its host screen, and scopes every list/add/edit/delete call it makes to that parent | XD-0001 (CAP-CMS-0004 capability-design) | Must |
| R10 | Add/edit submission is validated client-side (status selected from the controlled list, follow-up date well-formed) before any call is made; a `400` response from UNIT-CMS-0007 is mapped to the offending field inline rather than shown as a generic error | — nine-class sweep: input | Must |
| R11 | A `404` response to an edit, complete, or delete action (the entry was concurrently hard-removed upstream or the id is stale) is shown as "no longer available" and the entry is removed from the local grid, not retried and not surfaced as a crash | — nine-class sweep: input/state | Must |
| R12 | A caller without Editor role sees the list, sort, and filter controls but no add, edit, complete, or delete controls | CAP-CMS-0004/A1 (server-derived actor stamp implies the client cannot pretend to write), authorization floor | Must |
| R13 | A `401` response from any call this component makes surfaces a session-expired state rather than an inline field error, and the component takes no further action of its own to re-authenticate | — nine-class sweep: authorization | Must |
| R14 | The add, edit, complete, and delete controls are disabled for the duration of their own in-flight request, so a repeated click cannot fire a duplicate call | — nine-class sweep: repetition | Must |
| R15 | When a submit's outcome is unknown (the request timed out after being sent), the component does not silently retry; it re-fetches the current list so the caller sees whether the change took effect before acting again | — nine-class sweep: repetition/partial failure | Must |
| R16 | The component performs no client-side merge of concurrent edits; after any successful add/edit/complete/delete call it displays exactly the state UNIT-CMS-0007 returns, and a second caller's later write always wins | — nine-class sweep: concurrency | Must |
| R17 | If UNIT-CMS-0007 is unreachable or times out on initial load, the grid shows an error state with a retry action, never an empty grid presented as "no activity" | — nine-class sweep: dependency | Must |
| R18 | A `429` response from UNIT-CMS-0007 is surfaced as a "try again" state honoring any `Retry-After` value returned, not a silent failure or an uncaught error | — nine-class sweep: dependency | Must |
| R19 | Follow-up date is captured, stored for display, and rendered as a date-only value; the component never attaches or infers a time-of-day or timezone component for it | — nine-class sweep: time, `10-platform.md` formats | Must |
| R20 | The component holds no cached copy of the list across a full page navigation; each time it is mounted for a given `parentType`/`parentId` it fetches fresh from UNIT-CMS-0007 | — nine-class sweep: state | Should |

## Behaviour detail

**R1/R2/R3 — listing, filtering, pagination.** The grid's default view excludes
soft-deleted entries (UNIT-CMS-0007 excludes them by default per its own contract).
Sort direction is caller-adjustable; the initial sort on mount is follow-up date
ascending (open items with the soonest follow-up first) — see Assumptions. The
completed/open filter and the follow-up-date sort compose: a caller can view "open
items sorted by follow-up date" in one state.

**R4/R5 — add.** The create form collects `statusId`, `note`, `followUpDate`. It does
not collect and cannot submit `userName`, `enteredDate`, `completedDate`, or `id` —
those fields do not exist as inputs anywhere in the form, not merely disabled, so
there is no code path that could supply them even if the API ignored a supplied
value. On a `400` (e.g. invalid `statusId` for the parent's task-type scope), the
offending field is highlighted with the server's `message`; on any other error the
form stays populated so the caller does not re-type it.

**R6 — edit.** Same field set as add, pre-populated from the entry's current values.
Editing a soft-deleted entry is unreachable through the grid's own UI (soft-deleted
rows are not rendered by default), so this path is only reachable via a stale local
reference — see R11.

**R7 — complete.** The "mark complete" control is a single action, not a text field —
there is no way for the caller to type a completion date. Un-completing (toggling
back to open) is out of scope unless FR-ACT-4 is read to permit it; treated here as
one-directional per the raw ask's wording ("marking an entry complete") — see
Assumptions.

**R8 — soft delete.** The delete control requires an explicit confirm step (a second
action) before the call is made, to reduce accidental data loss given delete is
otherwise irreversible from the caller's perspective. Deleting an already-deleted
entry is not reachable through the grid's own UI for the same reason as R6, but if it
occurs (stale reference), UNIT-CMS-0007's own idempotent `204` behavior means the
component simply removes the row with no error shown.

**R9 — embedding contract.** `parentType`/`parentId` are the only inputs the host
screen must supply; the component owns no navigation, routing, or knowledge of which
capability's screen embeds it.

**R10/R11 — input and state failures.** A `422`-class rejection (business-rule
violation, e.g. a `statusId` outside the parent type's controlled list) is treated the
same as a `400` for display purposes — mapped to the field, not a generic banner —
since the caller can act on it.

**R13 — session expiry.** Session recovery (re-login, token refresh) is the host
screen's and UNIT-CMS-0001's responsibility; this component only stops making calls
and reports the state upward, it does not implement its own re-auth flow.

**R17/R18 — dependency degradation.** Distinct from R11/R13: a `404`/`401` is an
answer from UNIT-CMS-0007 about a specific entry or session, while R17/R18 cover the
dependency not answering at all (down, slow, timing out) or refusing on capacity
(`429`) — these must never be presented as "no activity found" or as a field-level
error, because neither is true.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R21 | availability | No independent availability target — the component has no backend of its own to be up or down; it degrades to R17's error state whenever UNIT-CMS-0007 is unavailable, and inherits no SLO beyond that dependency's |
| R22 | latency | p95 ≤ 800 ms and p99 ≤ 2 s from mount to a populated first page of ≤25 entries, inclusive of network and UNIT-CMS-0007's own round trip; the p99 figure allows headroom for the cold-start behavior `stack.md` records for serverless compute on the API side |
| R23 | throughput | N/A — no independent peak figure for this unit; it issues at most one request per caller action, and the shared peak-load characteristic belongs to UNIT-CMS-0007, which owns the backend all embedding screens call |
| R24 | surge | No shedding decision of its own; a burst is handled entirely by UNIT-CMS-0007's own `429` behavior (R18) plus this unit's own duplicate-submit guard (R14) |
| R25 | idempotency | N/A for this unit — create/update/delete idempotency keys are defined and enforced by UNIT-CMS-0007 (XD-0002/XD-0003); this unit's only obligation is not to issue a duplicate call from the UI itself (R14) |
| R26 | concurrency | See R16 — no read-modify-write merge is performed; the grid always reflects the last state UNIT-CMS-0007 returned for an entry |
| R27 | rate limits | This unit applies no rate limit of its own; a `429` from UNIT-CMS-0007 is surfaced per R18, with no client-side throttling of legitimate use |
| R28 | authorization | List/sort/filter requires Viewer; add/edit/complete/delete requires Editor, matching UNIT-CMS-0007's own min-role table; the component reads the caller's role from the session UNIT-CMS-0001 already established and stores no role of its own |
| R29 | tenant isolation | The component never constructs or accepts a tenant selector — every call carries only `parentType`/`parentId` and the bearer token already scoped to one tenant by UNIT-CMS-0001; isolation itself is enforced server-side by UNIT-CMS-0007's row-level-security policy, on every operation including the list read, and this unit does not re-implement or bypass it |
| R30 | audit | N/A for this unit — it writes no audit record; every mutation's audit trail is produced by UNIT-CMS-0007 and CAP-CMS-0001, per CAP-CMS-0004's non-goals |
| R31 | observability | A client-side error is logged with the entry id (where known), the attempted operation, and the HTTP status/error code returned; the note field's free text and any other personal-data field are never included in a log line, since a note may incidentally contain special-category content (`20-compliance.md`) |
| R32 | data classification | `note` and `userName` are personal data (`userName` identifies the acting staff member; `note` may incidentally contain special-category content and is treated as such from the first character); both render on-screen and travel in direct API request/response bodies only — never in a log line, event, analytics call, or error message. `followUpDate`/`enteredDate`/`completedDate` are not personal data |
| R33 | retention and deletion | N/A for this unit — it holds no persisted state of its own; retention and the erasure path are UNIT-CMS-0007's obligation, and CAP-CMS-0004's Constraints record no bespoke retention requirement beyond soft delete |
| R34 | migration and backfill | N/A — greenfield component with no data of its own to migrate |
| R35 | feature flag | N/A — no feature flag was requested for this unit |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Activity | Read and written only via UNIT-CMS-0007's contract — no local persistence, no cache surviving a remount (R20) | Fields as UNIT-CMS-0007 defines them: `id`, `parentType`, `parentId`, `statusId`, `note`, `followUpDate`, `enteredDate`, `completed`, `completedDate`, `userName` (read-only from this unit's perspective) |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth/session; role (Viewer/Editor) used to gate controls per R12/R28; session-expiry handling per R13 |
| UNIT-CMS-0007 | contract | The four activity endpoints this component calls (list, create, update, soft-delete) |

## Assumptions

- Default sort on mount is follow-up date ascending (soonest-due first). The raw ask says the view must be "sortable/filterable by follow-up date and open/closed state" but does not name a default; this is the reading that best serves the "what is owed next" workflow. If wrong, it is a one-line change confined to this unit.
- "Marking an entry complete" (FR-ACT-4) is treated as one-directional from this unit's UI — there is no "reopen" control. Nothing in the raw ask asks for reopening, and adding one would be unrequested scope; if a reopen workflow is wanted later it arrives as a change request.
- UNIT-CMS-0007's contract carries no concurrency token (no ETag/version field in the capability-design's endpoint table), so R16/R26's last-write-wins behavior is a consequence of the contract as designed, not a choice this unit is free to override.
- This unit has no peak-volume figure of its own (R23) because it is a thin client with no shared backend state; UNIT-CMS-0007's own requirements carry the volume figure that bounds real capacity.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
