---
unit: UNIT-CMS-0007
change: original
---

# Tasks — Activity API

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate server types/stubs and client types from `interfaces/openapi.yaml` — satisfies R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11
- [ ] Wire the bearer-token security scheme and its two scopes (`cms:activity.read`, `cms:activity.write`) into the generated server stubs — satisfies R20

## Data

- [ ] Apply migration `interfaces/001_create_activity.sql`, creating the `activity` storage construct with its check constraints and indexes — satisfies R1, R4, R6, R7, R8, R9
- [ ] Apply the row-level-security policy from `interfaces/001_create_activity.sql`, and confirm every session sets the tenant-scoping session variable before any query against this construct executes — satisfies R21
- [ ] Confirm the completed/completedDate pairing check constraint rejects a write that violates the invariant, rather than relying on application code to keep the two fields consistent — satisfies R7, R8

## Implementation

- [ ] Implement request validation for `parentType` (closed enum), `parentId` (format), `statusId`, `note`, `followUpDate` on create, and pagination bounds on list, before any store access — satisfies R1, R4
- [ ] Implement the tenant-scoped parent-reference check — confirm `parentId` is a syntactically valid identifier within the caller's own tenant, without validating the parent's own lifecycle — satisfies R21
- [ ] Implement create: insert one `Activity` row with `userName` derived from the authenticated caller's identity and `enteredDate` set to the current server timestamp, ignoring any client-supplied value for either field — satisfies R1, R2, R3
- [ ] Implement list: read rows scoped to the caller's tenant and the named parent, excluding soft-deleted rows by default, applying the `completed` filter and `followUpDate` sort/cursor pagination when given — satisfies R4, R5, R10
- [ ] Implement update: apply `statusId`, `note`, `followUpDate`, `completed` to an existing, non-deleted row scoped to the caller's tenant — satisfies R6
- [ ] Implement the completion clock: set `completedDate` to the current server timestamp when `completed` flips false→true, and clear it when it flips true→false, in the same write as the flip — satisfies R7, R8
- [ ] Implement soft delete: set the deleted marker and return `204`; if the row is already soft-deleted, return `204` with no further change instead of a second write — satisfies R9, R11
- [ ] Implement the write/audit-emit atomicity for create, update, and soft-delete: the entity write and its audit-trail record commit as one unit, so a failure after the entity write but before the audit emit rolls the entity write back rather than leaving an unaudited change — satisfies R12, R22
- [ ] Wire the Viewer/Editor role check per operation (Viewer for list, Editor for create/update/delete) — satisfies R20

## Validation and errors

- [ ] Return `400 invalid_request` for malformed `parentType`, missing/malformed `parentId`/`statusId`, or out-of-range pagination parameters — satisfies R1, R4, R6
- [ ] Return `401` for a missing or invalid bearer token on every operation — satisfies R20
- [ ] Return `403 forbidden` for an authenticated caller below the Editor role attempting create/update/delete — satisfies R20
- [ ] Return `404 not_found` for a `parentId` outside the caller's tenant or nonexistent on create/list, and for an activity id outside the caller's tenant, nonexistent, or belonging to a different parent on update/delete, using an identical shape regardless of which of those is true — satisfies R21
- [ ] Return `404 not_found` on update for an id that is already soft-deleted, distinguishing it from the delete operation's own idempotent `204` — satisfies R6, R9
- [ ] Return `503 write_failed` when the entity write and its audit emit cannot both commit, on create, update, and delete — satisfies R12, R22

## Observability

- [ ] Emit metrics: request count and error rate per endpoint, write-to-audit-emit latency — satisfies R23
- [ ] Emit structured logs with caller id, tenant id, `parentType`, `parentId`, activity id, operation, and HTTP status, with `note` content never logged — satisfies R23, R24
- [ ] Instrument the entity write and the audit-trail emit as their own trace spans — satisfies R23

## Tests

- [ ] Unit tests covering every R-ID branch listed above
- [ ] Contract tests generated from `interfaces/openapi.yaml` pass
- [ ] Test: a client-supplied `userName`, `enteredDate`, or `completedDate` field in a request body is ignored, never applied — satisfies R2, R3, R7, R8
- [ ] Test: `completed` false→true sets `completedDate`; true→false clears it; unchanged leaves it untouched — satisfies R7, R8
- [ ] Test: deleting an already soft-deleted entry returns `204` and performs no further write, distinct from deleting a nonexistent or foreign-tenant id (`404`) — satisfies R9, R11
- [ ] Test: cross-tenant `parentId` on create/list and cross-tenant activity id on update/delete each produce the same `404` shape as a nonexistent id — satisfies R21
- [ ] Test: a simulated failure between the entity write and the audit emit leaves no entity change committed, on each of create, update, and delete — satisfies R12, R22
- [ ] Test: two concurrent updates to the same entry resolve to a single consistent last-write-wins state, with no partial/interleaved field mix — satisfies R18
- [ ] Test: two concurrent soft-deletes on the same entry both return `204`, with only one delete actually recorded — satisfies R9, R11, R18

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Contracts task; request validation task; create task; validation/errors task |
| R2 | Create task; client-supplied-field test |
| R3 | Create task; client-supplied-field test |
| R4 | Contracts task; migration task; request validation task; list task; validation/errors task |
| R5 | Contracts task; list task |
| R6 | Contracts task; update task; validation/errors task (two rows) |
| R7 | Migration task (constraint); completion-clock task; audit-atomicity task; completed-flip test |
| R8 | Migration task (constraint); completion-clock task; completed-flip test |
| R9 | Migration task; soft-delete task; audit-atomicity task; idempotent-delete test; concurrent-delete test |
| R10 | List task |
| R11 | Contracts task; soft-delete task; idempotent-delete test; concurrent-delete test |
| R12 | Audit-atomicity implementation task; validation/errors task (503); audit-atomicity test |
| R13 | — no task; platform-floor availability statement, not a build item |
| R14 | — no task; latency target verified by contract/perf testing in the target repo, not a spec-side build item |
| R15 | — no task; capacity assumption, revisited operationally |
| R16 | — no task; enforced by API Gateway configuration outside this unit's build |
| R17 | Create task (idempotency behaviour is the absence of a dedupe key — no task needed beyond the create task itself) |
| R18 | Concurrency tests (last-write-wins update test; concurrent-delete test) |
| R19 | — no task; enforced by API Gateway configuration outside this unit's build |
| R20 | Bearer/scope wiring task; role-check task; validation/errors tasks (401/403) |
| R21 | Tenant-scoped parent-reference task; RLS-policy task; validation/errors task; cross-tenant test |
| R22 | Audit-atomicity implementation task; validation/errors task (503); audit-atomicity test |
| R23 | Observability tasks |
| R24 | Observability logging task |
| R25 | — no task; erasure path is an operational/administrative procedure documented in `requirements.md`, not a build-time task for this unit's contract |
| R26 | — no task; migration/backfill is CAP-CMS-0006's own build, not this unit's |
| R27 | — no task; N/A per `requirements.md` |
