---
unit: UNIT-CMS-0007
updated: 2026-08-18
---

# Design — Activity API

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

A single CRUD-plus-soft-delete resource service fronting one polymorphic `Activity`
entity. Every operation is scoped by `parentType`/`parentId` (an opaque reference to a
brokerage or agency owned elsewhere, per XD-0001) and by `tenant_id`. Writes derive
`userName` and timestamp fields server-side rather than trusting the caller (XD-0003);
delete never removes a row, it only sets a deleted marker (XD-0002). There is no
background processing, no async event, and no cache — every list read goes straight to
the store, because the "what's owed next" view (FR-ACT-5) must reflect the latest write
immediately and the read volume (≤15 rps peak) does not justify one.

The alternative considered — modelling agency-activity and brokerage-activity as two
separate entities/endpoints — was rejected per the capability design's own decomposition
rationale (XD-0001): they share one schema, one soft-delete rule, and one audit outcome,
and splitting them would duplicate all three for no behavioural gain.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Request validator | Rejects malformed `parentType`, missing/invalid `parentId`, and out-of-range query params before any store access | R1, R4, R6 (failure surface, see Flows) |
| Identity stamper | Reads the caller's identity from the validated auth token and derives `userName` for every write; never reads a client-supplied `userName` | R2, XD-0003 |
| Activity store accessor | Performs the tenant-scoped read/write against the `Activity` entity; enforces row-level security | R1, R4, R6, R9, R21 |
| Completion clock | Sets/clears `completedDate` server-side whenever `completed` flips, in either direction | R7, R8 |
| Soft-delete handler | Sets the deleted marker instead of removing the row; treats delete-of-already-deleted as a no-op `204` | R9, R10, R11 |
| Audit emitter | Writes one audit-trail record per create/update/delete, synchronously with the triggering write | R12, R22 |

## Flows

### POST /api/v1/activity — create — satisfies R1, R2, R3

1. Caller sends `POST /api/v1/activity` with a bearer token and `{ parentType, parentId, statusId, note, followUpDate }`.
2. Request validator checks the token, checks `parentType` is `agency`|`brokerage`, and checks `parentId`/`statusId` are present and well-formed.
3. Activity store accessor confirms `parentId` is a syntactically valid identifier belonging to the caller's own tenant (RLS-scoped check; does not validate the parent's own lifecycle — out of scope).
4. Identity stamper sets `userName` from the caller's authenticated identity and `enteredDate` to the current server timestamp.
5. Row is inserted with `completed = false`, `completedDate = null`, `deletedAt = null`.
6. Audit emitter writes a `create` audit record, synchronously, before the response is returned.
7. Caller receives `201` with the full `Activity` representation.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401` |
| 2 — caller has role below Editor | `403` |
| 2 — malformed `parentType`, missing `parentId`/`statusId` | `400 invalid_request` |
| 3 — `parentId` not resolvable in caller's tenant | `404 not_found` — identical shape whether the id does not exist at all or belongs to another tenant |
| 5 — store write fails (e.g. transient store error) | `503`; no partial row is left — insert is a single atomic statement |
| 6 — audit emit fails after the row insert succeeds | Insert is rolled back — the write and its audit record are one atomic unit (see State and idempotency); caller receives `503`, no orphaned `Activity` row is ever visible without a matching audit entry |

### GET /api/v1/activity — list — satisfies R4, R5

1. Caller sends `GET` with `parentType`, `parentId`, and optional `page`, `size`, `completed`, `sort=followUpDate`.
2. Request validator checks `parentType`/`parentId` presence and pagination bounds (`size` ≤ 100, default 25, cursor-based per platform convention).
3. Activity store accessor reads rows scoped to the caller's tenant, the named parent, `deletedAt IS NULL` by default, applying the `completed` filter and `followUpDate` sort if given.
4. Caller receives `200` with `{ items, next_cursor }`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401` |
| 2 — malformed query params | `400 invalid_request` |
| 3 — `parentId` not in caller's tenant | `404 not_found` |
| 3 — parent has zero activity rows | `200` with `items: []` — success, not an error |

### PUT /api/v1/activity/{id} — update — satisfies R6, R7, R8

1. Caller sends `PUT` with `{ statusId, note, followUpDate, completed }`.
2. Request validator checks token and body shape.
3. Activity store accessor reads the existing row scoped to caller's tenant, rejecting if not found or soft-deleted.
4. Completion clock compares the existing `completed` value to the incoming one: `false → true` sets `completedDate` to now; `true → false` clears it; unchanged leaves it untouched.
5. Row is updated (last-write-wins at the row level — see Concurrency matrix).
6. Audit emitter writes an `update` audit record synchronously.
7. Caller receives `200` with the updated `Activity`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401` |
| 2 — caller has role below Editor | `403` |
| 2 — malformed body | `400 invalid_request` |
| 3 — id not found, wrong tenant, or already soft-deleted | `404 not_found` |
| 6 — audit emit fails after the row update succeeds | Update is rolled back to the pre-update row; caller receives `503` |

### DELETE /api/v1/activity/{id} — soft delete — satisfies R9, R10, R11

1. Caller sends `DELETE`.
2. Request validator checks token.
3. Activity store accessor reads the row scoped to caller's tenant.
4. Soft-delete handler: if the row does not exist in caller's tenant → `404`. If it exists and `deletedAt IS NULL` → set `deletedAt` to now, write audit record, return `204`. If it exists and `deletedAt` is already set → return `204` with no further change (idempotent no-op) and no second audit record.
5. Caller receives `204`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401` |
| 2 — caller has role below Editor | `403` |
| 3 — id not found or wrong tenant | `404 not_found` |
| 4 — audit emit fails on first delete | Soft-delete marker is rolled back; caller receives `503`; the row remains not-deleted so a retry is safe |

## Data model

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| Activity | tenant-scoped identifier | `parentType`, `parentId`, `statusId`, `note`, `followUpDate`, `enteredDate`, `completed`, `completedDate`, `userName`, `deletedAt` | Retained indefinitely under standard policy (no bespoke retention per intake Q9); soft-deleted rows are retained, never purged, by this unit — see `requirements.md` R25 for the erasure path on `note` |

`parentId` and the task-type/status value behind `statusId` are read-only references
into entities this unit does not own (UNIT-CMS-0005) — see `requirements.md` § Data.

## Contracts

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Activity CRUD + soft delete | sync HTTP | `interfaces/openapi.yaml` | R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11 |
| Activity storage schema and RLS policy | storage | `interfaces/001_create_activity.sql` | R21, plus the physical shape backing every R-ID above |

## State and idempotency

**State machine.** `Activity` has two independent boolean-shaped facets rather than one
combined lifecycle: *completion* (`open` ↔ `completed`, freely reversible in either
direction, R7/R8) and *deletion* (`active` → `deleted`, one-way, R9). `deleted` is
terminal — no operation in this unit's contract un-deletes a row. The invariant "a
`completed` entry always has a non-null `completedDate`, and a non-`completed` entry
always has a null one" is enforced by the completion clock setting/clearing the field in
the same write as the `completed` flip — never as a separate step a caller could
interleave with.

**Idempotency walk.**

- *`POST` — first attempt:* inserts one row, one audit record, atomically.
- *`POST` — client retry (network timeout, no idempotency key supplied):* inserts a
  second, independent row. This is accepted, not collapsed — see `requirements.md` R17 and
  Assumptions; each `POST` is a distinct log entry by design, and there is no key to
  derive one from without an explicit client-supplied token, which is not part of this
  unit's contract today.
- *`PUT` — first attempt and any retry:* every retry re-applies the same field values to
  the same row id; the resulting state is identical regardless of how many times it is
  applied, because there is no "add N" semantic anywhere in this entity — every field is
  a replace. The "key" here is simply the resource id (`{id}` in the path), fixed before
  execution.
- *`DELETE` — first attempt and any retry:* first call transitions `deletedAt: null →
  <timestamp>`; every subsequent call observes `deletedAt` already set and no-ops to
  `204`. The check-then-no-op happens inside the same operation that would otherwise
  write, so there is no window where a concurrent second delete could set two different
  timestamps — the store's row-level lock on the update covers it (see Concurrency
  matrix).
- *Crash between the `Activity` write and the audit emit (any of the three write
  flows):* the write and its audit record are treated as one atomic unit (see Flows'
  failure tables) — either both are durable or neither is. This is stronger than
  eventual consistency because CAP-CMS-0001/M3's audit obligation must never be
  satisfiable by a write with no corresponding record.

**Concurrency matrix.**

| Scenario | Outcome | Enforcement |
|---|---|---|
| Two concurrent `PUT`s on the same `id` | Last write wins at the row level; both callers receive `200` with the state as it stood when their own write committed | Storage-level: the row's own atomic update, no read-then-write in application code |
| Two concurrent `POST`s under the same `parentId` | Both succeed, producing two independent rows | No contention — each insert is its own new row |
| Concurrent `PUT` and `DELETE` on the same `id` | Whichever commits second determines final state; if `DELETE` commits last, a concurrent `PUT`'s change is preserved on the now-deleted row (soft delete does not erase prior field values) | Storage-level: each is a single atomic statement against the row |
| Two concurrent `DELETE`s on the same `id` | Exactly one sets `deletedAt`; the other observes it already set and no-ops to `204`; both callers receive `204` | Storage-level: the row's own atomic conditional update (set `deletedAt` only if currently null) — never a read-then-write in application code |
| A `GET` list read racing a concurrent write on one of its rows | The read reflects whichever state existed at the read's own snapshot; no read blocks on a write | No enforcement needed — reads are not required to observe a write that has not yet committed |

**Answers that can change.** This unit has no upstream answer about the past that gets
revised — `statusId` and the task-type list it draws from are read-only references, not
inputs computed elsewhere and later corrected. Not applicable.

**Event durability.** This unit emits no async event to any transport (SQS/SNS) — the
only durability concern is the write/audit-emit atomicity above, which is a synchronous,
same-transaction concern, not a queue-durability one.

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | Every operation, including `GET`, is scoped by `tenant_id` enforced by a PostgreSQL row-level security policy on the `Activity` storage construct (`stack.md`) — never by an application-level `WHERE` clause alone, so a query that forgets the filter still cannot cross tenants (R21) |
| authn/authz | Bearer token validated per CAP-CMS-0001; minimum role Viewer for `GET`, Editor for `POST`/`PUT`/`DELETE` (R20); ownership rule is tenant-wide, not per-author — any Editor in the tenant may edit or delete any entry |
| validation | `parentType` restricted to `agency`\|`brokerage`; `parentId`/`statusId` format-checked before any store access; pagination bounds enforced (`size` ≤ 100, default 25) |
| error model | Shared envelope `{ error: { code, message, fields? } }` per capability convention; `400 invalid_request`, `401`, `403`, `404 not_found`, `503` for a rolled-back write, `429` at the gateway layer |
| observability | Metrics: request count and error rate per endpoint, write-to-audit-emit latency. Logs: caller id, tenant id, `parentType`, `parentId`, activity id, operation, HTTP status — never `note` content (R23, R24) |
| performance | p95 ≤ 500 ms / p99 ≤ 1500 ms inclusive of cold start (R14); ≤15 rps peak assumption (R15); 2× surge shed by API Gateway throttling with `429`/`Retry-After` (R16) |
| migration/backfill | Legacy `PP_TskData` rows are migrated in by CAP-CMS-0006, translating its soft-delete convention into this unit's `deletedAt` field; this unit's own schema is otherwise greenfield and additive (R26) |
| feature flag | N/A — no flagged rollout planned (R27) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| `POST` is not idempotent and has no client-supplied dedupe key | A flaky network client that retries a create produces a duplicate, user-visible log entry | Accepted (R17/Assumptions) — duplicate entries are low-severity and staff-correctable via `PUT`/`DELETE`; if this proves costly, an additive optional idempotency-key header can be introduced without a breaking change |
| Last-write-wins on concurrent `PUT` | A second editor's simultaneous change silently overwrites the first editor's, with no conflict signal | Accepted (R18/Assumptions) — activity notes are a low-contention, largely single-operator workflow; revisit if multi-editor conflict becomes observed in practice |
| Write/audit-emit atomicity depends on a mechanism this design asserts but does not name | If the engineering repo implements the write and the audit emit as two separate, non-atomic calls, a crash between them silently violates CAP-CMS-0001/M3 | Flagged explicitly in Flows and the idempotency walk as a hard requirement — not a suggestion — so `tasks.md` must carry an explicit task and acceptance check for this atomicity, not leave it implicit |

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Flow: POST create; Contracts |
| R2 | Identity stamper; Flow: POST create |
| R3 | Identity stamper; Flow: POST create |
| R4 | Flow: GET list; Activity store accessor |
| R5 | Flow: GET list |
| R6 | Flow: PUT update |
| R7 | Completion clock; Flow: PUT update; State machine |
| R8 | Completion clock; Flow: PUT update; State machine |
| R9 | Soft-delete handler; Flow: DELETE |
| R10 | Soft-delete handler; Flow: GET list (default exclusion) |
| R11 | Soft-delete handler; Idempotency walk |
| R12 | Audit emitter; Flows' failure tables (atomicity) |
| R13 | Cross-cutting → tenant isolation, authn/authz (dependency framing carried from `requirements.md`) |
| R14 | Cross-cutting → performance |
| R15 | Cross-cutting → performance |
| R16 | Cross-cutting → performance |
| R17 | Idempotency walk; Risks |
| R18 | Concurrency matrix; Risks |
| R19 | Cross-cutting → error model (gateway-level `429`, not unit-designed) |
| R20 | Cross-cutting → authn/authz |
| R21 | Cross-cutting → tenant isolation |
| R22 | Audit emitter; Idempotency walk (atomicity) |
| R23 | Cross-cutting → observability |
| R24 | Cross-cutting → observability; Data model |
| R25 | Data model (retention note); N/A design section not needed beyond that — erasure path is fully specified in `requirements.md` |
| R26 | Cross-cutting → migration/backfill |
| R27 | Cross-cutting → feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
