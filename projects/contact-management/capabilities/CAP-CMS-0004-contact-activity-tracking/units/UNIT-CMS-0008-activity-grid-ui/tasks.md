---
unit: UNIT-CMS-0008
change: original
---

# Tasks — Activity Grid UI

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate client types/stubs from `interfaces/UNIT-CMS-0007.openapi.yaml` (list, create, update, soft-delete operations) — satisfies R1, R4, R6, R7, R8, R9
- [ ] Re-generate the above once UNIT-CMS-0007-activity-api publishes its own `interfaces/openapi.yaml` and this unit's local copy is re-synced from it (the current file is a derived placeholder — see `interfaces/consumed-contracts.yaml`) — satisfies R1, R4, R6, R7, R8, R9

## Data

No data tasks. This unit owns no schema and holds no persisted state of its own —
every entity read or written is UNIT-CMS-0007's (`design.md` § Data model).

## Implementation

- [ ] Implement the embedding adapter that accepts `parentType`/`parentId` as external inputs and threads them, unmodified, into every list/add/edit/complete/delete call this unit makes; construct no tenant selector of its own — satisfies R9, R29
- [ ] Implement the role-gate presenter: read the caller's role (Viewer/Editor) from the session context already established by the host screen, and omit add/edit/complete/delete controls entirely from the rendered output for a non-Editor caller (not present-and-disabled) — satisfies R12, R28
- [ ] Implement the initial-load flow: on mount, call the list operation with the default sort (follow-up date ascending), no completed filter, page 1; hold no cached copy of the list across a remount — satisfies R1, R3, R20
- [ ] Implement the completed/open filter, composable with the follow-up-date sort, re-issuing the list call on either change — satisfies R2
- [ ] Implement the add action: client-side validation (status from the controlled list, well-formed date) gates submit; the request body constructed for the create call contains only `statusId`, `note`, `followUpDate` — no code path exists that could also send `userName`, `enteredDate`, `completedDate`, or `id` — satisfies R4, R5, R10
- [ ] Implement the edit action: same field set as add, pre-populated from the entry's current values, reachable only for a visible (non-deleted) row — satisfies R6, R10
- [ ] Implement the mark-complete action as a single control with no date input; the update call it issues carries `completed: true` and nothing else — satisfies R7
- [ ] Implement the soft-delete action behind an explicit second confirm step; on a `204` response (including a repeat call against an already-deleted id) remove the row from the default view — satisfies R8, R11, R16
- [ ] Disable the triggering control for the duration of its own in-flight add/edit/complete/delete/soft-delete call, independently per row, so a repeated activation cannot fire a duplicate call — satisfies R14, R24
- [ ] Implement session-fault handling: treat a `401` from any call as session-expired, stop issuing further calls from this component until it is remounted, and retain any open form's entered values — satisfies R13
- [ ] Implement reconciliation-on-unknown-outcome: when a submit's result is unknown (timeout after the request was sent), re-fetch the list to observe ground truth before permitting any further write from that control, rather than retrying blindly or assuming failure — satisfies R15
- [ ] Ensure no client-side merge of concurrent edits is ever performed: after any successful call, render exactly the entry state the operation's response returned, with no local reconciliation against a prior in-memory copy — satisfies R16, R26
- [ ] Ensure `followUpDate` is captured, stored for display, and rendered strictly as a date-only value, with no time-of-day or timezone component attached at any point — satisfies R19

## Validation and errors

- [ ] Map a `400`/`422` response on add/edit to the field named in the response's `fields` array, shown inline; leave the rest of the form's values in place and re-enable submit — satisfies R10
- [ ] Map a `404` response on edit/complete/delete to a "no longer available" outcome for that row, then remove it from the local grid without retrying — satisfies R11
- [ ] Map a `429` response on any call to a throttled state honoring the returned `Retry-After` value, re-enabling the triggering control only once it elapses — satisfies R18, R27
- [ ] Map a connection failure or timeout on the initial list call to a recoverable error state with a retry action, never an empty "no activity" grid — satisfies R17
- [ ] Map a `401` response to the session-expired outcome per the Implementation task above, distinct from every other 4xx — satisfies R13

## Observability

- [ ] On any failed call, log the entry id (where known), the attempted operation, and the returned HTTP status/error code, and confirm by inspection that no log line, analytics event, or error message this unit produces ever includes `note`, `userName`, or any other personal-data field — satisfies R31, R32

## Tests

- [ ] Unit tests covering every R-ID branch listed above, including every row of the Implementation and Validation and errors sections
- [ ] Unit tests for the concurrency cases in `design.md`'s concurrency matrix: two callers editing the same entry, a double-activation of mark-complete, and a delete landing while an edit is pending — satisfies R16, R26
- [ ] Contract tests generated from `interfaces/UNIT-CMS-0007.openapi.yaml` pass; re-run once that file is re-synced from UNIT-CMS-0007's own published contract — satisfies R1, R4, R6, R7, R8
- [ ] Accessibility verification against `ux/a11y.md`: the full keyboard map, focus order including on open/close/after submit/after error/after every terminal outcome, and every live-region announcement — satisfies R10, R11, R12, R13, R28
- [ ] Verify the first-page load meets the p95 ≤ 800 ms / p99 ≤ 2 s budget against a realistic UNIT-CMS-0007 response-time profile, including a cold-start-inclusive sample — satisfies R22

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Generate client types/stubs (Contracts); initial-load flow (Implementation); contract tests (Tests) |
| R2 | Completed/open filter (Implementation) |
| R3 | Initial-load flow (Implementation) |
| R4 | Generate client types/stubs (Contracts); add action (Implementation); contract tests (Tests) |
| R5 | Add action — request body field set (Implementation) |
| R6 | Generate client types/stubs (Contracts); edit action (Implementation); contract tests (Tests) |
| R7 | Generate client types/stubs (Contracts); mark-complete action (Implementation); contract tests (Tests) |
| R8 | Generate client types/stubs (Contracts); soft-delete action (Implementation); contract tests (Tests) |
| R9 | Generate client types/stubs (Contracts); embedding adapter (Implementation) |
| R10 | Add action validation gate (Implementation); 400/422 mapping (Validation and errors); a11y verification (Tests) |
| R11 | Soft-delete action idempotent removal (Implementation); 404 mapping (Validation and errors); a11y verification (Tests) |
| R12 | Role-gate presenter (Implementation); a11y verification (Tests) |
| R13 | Session-fault handling (Implementation); 401 mapping (Validation and errors); a11y verification (Tests) |
| R14 | Per-row in-flight disable (Implementation) |
| R15 | Reconciliation-on-unknown-outcome (Implementation) |
| R16 | Soft-delete idempotent removal (Implementation); no-merge guarantee (Implementation); concurrency unit tests (Tests) |
| R17 | Connection-failure/timeout mapping (Validation and errors) |
| R18 | 429 mapping (Validation and errors) |
| R19 | Date-only handling (Implementation) |
| R20 | Initial-load flow — no cross-remount cache (Implementation) |
| R21 | No task — N/A, this unit has no independent availability target (`requirements.md` R21); degradation is exercised by the connection-failure/timeout task above |
| R22 | Latency verification (Tests) |
| R23 | No task — N/A, no independent peak-volume figure for this unit (`requirements.md` R23) |
| R24 | Per-row in-flight disable (Implementation) |
| R25 | No task — N/A, idempotency keys are UNIT-CMS-0007's obligation, not this unit's (`requirements.md` R25) |
| R26 | No-merge guarantee (Implementation); concurrency unit tests (Tests) |
| R27 | 429 mapping (Validation and errors) |
| R28 | Role-gate presenter (Implementation); a11y verification (Tests) |
| R29 | Embedding adapter (Implementation) |
| R30 | No task — N/A, this unit writes no audit record; produced by UNIT-CMS-0007/CAP-CMS-0001 (`requirements.md` R30) |
| R31 | Observability logging task |
| R32 | Observability logging task |
| R33 | No task — N/A, no persisted state of this unit's own (`requirements.md` R33) |
| R34 | No task — N/A, greenfield, nothing to migrate (`requirements.md` R34) |
| R35 | No task — N/A, no feature flag requested (`requirements.md` R35) |
