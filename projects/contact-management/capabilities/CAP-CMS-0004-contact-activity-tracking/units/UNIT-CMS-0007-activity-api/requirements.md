---
id: UNIT-CMS-0007
slug: activity-api
project: CMS
capability: CAP-CMS-0004
title: Activity API
kind: backend
target_repo: CMS-contact-activity-tracking
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Activity API

## Scope

Owns the polymorphic `Activity` entity (`parentType`/`parentId`, XD-0001), soft delete
(XD-0002), and server-derived `userName` (XD-0003). Its four-endpoint contract in
`capability-design.md` is independent of any specific brokerage/agency schema — it only
needs an opaque parent reference — so it can be built without waiting on UNIT-CMS-0005.

**In scope:**
- Create/list/update/soft-delete activity entries against either parent type
- Server-derived `userName` and `enteredDate`; server-set `completedDate` on completion
- Follow-up-date/completed-state sort and filter

**Out of scope:**
- Which entity is a valid parent, or that entity's own lifecycle (UNIT-CMS-0005)
- The task-type/status controlled list's maintenance (UNIT-CMS-0005's reference-lookup scope)
- Rendering the activity grid (UNIT-CMS-0008)

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | `POST /api/v1/activity` creates one activity entry against a `parentType` (`agency`\|`brokerage`) and `parentId`, capturing `statusId`, `note`, and `followUpDate` from the request body. | CAP-CMS-0004/A1, FR-ACT-1, FR-ACT-2 | P0 |
| R2 | The created entry's `userName` is set server-side from the authenticated caller's identity; no client-supplied `userName` value is ever read from the request body or applied. | CAP-CMS-0004/A1, M1, AUTHZ-2, XD-0003 | P0 |
| R3 | The created entry's `enteredDate` is set server-side to the current timestamp at creation time; no client-supplied `enteredDate` is accepted. | FR-ACT-2 | P0 |
| R4 | `GET /api/v1/activity?parentType=&parentId=&page=&size=&completed=&sort=followUpDate` returns the page of activity entries for the named parent, excluding soft-deleted entries by default. | CAP-CMS-0004/A3, FR-ACT-1, FR-ACT-5 | P0 |
| R5 | The list operation supports filtering by `completed` (open vs. closed) and sorting by `followUpDate`, so a caller can produce a "what is owed this partner next" view. | CAP-CMS-0004/A3, FR-ACT-5 | P0 |
| R6 | `PUT /api/v1/activity/{id}` updates `statusId`, `note`, `followUpDate`, and `completed` on an existing, non-deleted entry. | FR-ACT-3 | P0 |
| R7 | When an update flips `completed` from `false` to `true`, the entry's `completedDate` is set server-side to the current timestamp; no client-supplied `completedDate` is ever accepted. | CAP-CMS-0004/A2, FR-ACT-4 | P0 |
| R8 | When an update flips `completed` from `true` to `false`, the entry's `completedDate` is cleared server-side. | FR-ACT-4 | P1 |
| R9 | `DELETE /api/v1/activity/{id}` soft-deletes the entry: it sets a deleted flag/timestamp on the row and returns `204`; the row is retained, never physically removed. | CAP-CMS-0004/A4, XD-0002 | P0 |
| R10 | A soft-deleted entry is excluded from `GET /api/v1/activity`'s default listing but remains visible to the audit trail and to any explicit "include deleted" administrative path this unit does not itself expose. | CAP-CMS-0004/A4, XD-0002 | P1 |
| R11 | `DELETE` on an entry that is already soft-deleted returns `204` and performs no further change — it is idempotent, not a `404`. | capability-design.md Shared conventions (idempotency) | P1 |
| R12 | Every create, update, and soft-delete operation on an activity entry is written to CAP-CMS-0001's audit trail, recording what changed, when, and the acting user's identity. | CAP-CMS-0001/M3, NFR-AUD-2 | P0 |

## Behaviour detail

**R1/R6 — parent reference is opaque.** This unit does not validate that `parentId`
refers to an existing brokerage or agency record beyond confirming it is a syntactically
valid identifier belonging to the caller's own tenant (R21) — ownership and lifecycle of
the parent entity are UNIT-CMS-0005's concern, per this capability's non-goals.

**R2 — server-derived `userName`.** The value comes from the authenticated request's
identity claim (issued by CAP-CMS-0001's self-issued JWT), never from a request body
field. A request body that happens to carry a `userName` field is silently ignored, not
merged, rejected, or echoed back as an error.

**R7/R8 — `completedDate` follows `completed`, not the other way round.** `completed`
is the field a caller sets; `completedDate` is always a derived, read-only side effect of
that flip, in both directions.

**R9/R11 — soft delete is idempotent.** Deleting an entry that does not exist at all
(never created, or belonging to another tenant) is a `404`; deleting one that exists but
is already soft-deleted is a `204` no-op. These are different observable states and must
not share a response.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R13 | availability | This unit's own compute targets the platform default (99.9% monthly, serverless). It depends on UNIT-CMS-0001 (auth) being reachable for every operation; if that dependency is down, every write and every list call fails closed with `401`/`503` rather than proceeding unauthenticated — no lower bound is silently inherited. |
| R14 | latency | p95 ≤ 500 ms, p99 ≤ 1500 ms for every synchronous operation, inclusive of serverless cold start (per `stack.md`'s cold-start consequence). ASSUMPTION: no measured baseline exists yet; ≤15 rps peak (R15) makes cold start the dominant tail-latency contributor, not database load. |
| R15 | throughput | Peak figure: ≤15 requests/second, derived from intake's "low hundreds of brokerages/agencies, <50 concurrent staff" scale (same basis as UNIT-CMS-0010/R16) — ASSUMPTION, not a measured figure; revisit if traffic proves otherwise. |
| R16 | surge | At 2× peak (~30 rps), API Gateway throttling (per `stack.md`) sheds excess requests with `429` + `Retry-After`. Nothing is exempt — activity logging is never on a critical synchronous path for another capability. |
| R17 | idempotency | `PUT /api/v1/activity/{id}` is idempotent by resource id (per capability-design.md's shared conventions) — replaying the identical body produces the same resulting state. `DELETE` is idempotent per R11. `POST` is **not** idempotent — a retried `POST` with no dedupe key creates a second entry; ASSUMPTION: acceptable because duplicate activity log entries are a visible, correctable nuisance, not a financial or irreversible error (see Assumptions). |
| R18 | concurrency | Two concurrent `PUT`s against the same entry: last-write-wins at the row level is acceptable — activity notes are a low-contention, single-operator-at-a-time workflow, and no financial or irreversible state is at stake. Two concurrent `POST`s against the same parent create two independent entries, which is correct (they are two distinct log lines). |
| R19 | rate limits | Per caller and per this unit's own endpoints, enforced by API Gateway throttling (`stack.md`); response is `429` with `Retry-After`, matching the capability's shared error envelope. |
| R20 | authorization | Minimum role: Viewer for `GET`; Editor for `POST`/`PUT`/`DELETE` (FR-ACT-3). Ownership rule: any authenticated caller in the parent's own tenant may read or write — activity entries are not restricted to their original author, since follow-up tracking is a shared team workflow. No service-credential caller is defined for this unit today. |
| R21 | tenant isolation | Every operation — including `GET` — is scoped by `tenant_id` via PostgreSQL row-level security (`stack.md`); a caller can never list, read, update, or delete another tenant's activity rows, and a `parentId` belonging to another tenant is treated identically to a `parentId` that does not exist (`404`), never disclosed via a different error shape. |
| R22 | audit | Every create/update/soft-delete is recorded in CAP-CMS-0001's audit trail per R12: what changed, when (timestamp), who (server-derived `userName`), and the entry's id as the external reference. Immutability is enforced by the audit trail's own append-only store, owned by CAP-CMS-0001 — this unit only guarantees it emits the record, and emits it synchronously with the write it describes so no write can succeed without a corresponding audit entry. |
| R23 | observability | Metrics: request count and error rate per endpoint, write-to-audit-emit latency. Structured log fields: caller id, tenant id, `parentType`, `parentId`, activity id, operation (`create`\|`update`\|`delete`), HTTP status. `note` (free text) never appears in a log line (data-classification floor, R24). Trace span boundary: the write to the `Activity` store and the audit-trail emit are each their own span. |
| R24 | data classification | `note` (free text) — personal data by default (staff cannot be constrained from writing personal details about a contact into it); treated as such — never logged, never echoed in an error message, never emitted to a metric label. `userName` (acting staff member) — personal data, not special category. `statusId`, `followUpDate`, `enteredDate`, `completedDate`, `completed`, `parentType`, `parentId` — not personal data. No field in this entity is special-category. |
| R25 | retention and deletion | Activity rows are retained under standard policy (intake Q9 found no bespoke retention/erasure requirement) — soft delete only (R9), no hard-delete path exists in this unit. Where a data-subject erasure request reaches an activity `note`, the erasure path is: sever the free-text `note` content in place (replace with a redaction marker) while retaining the row, its timestamps, and its `userName` stamp for audit continuity — the row is never physically removed, since XD-0002 and the capability's non-goals rule out hard delete entirely. |
| R26 | migration and backfill | Legacy `PP_TskData` rows are migrated into this schema by CAP-CMS-0006 (Legacy Data Migration), including translation of the legacy soft-delete convention into this unit's `deletedAt` field. This unit's own schema is otherwise greenfield. Reversible: the migration is additive (new rows in a new schema); rollback is dropping the migrated rows, not touched by this unit's own build. |
| R27 | feature flag | N/A — no flagged or phased rollout is planned for this unit; it ships as a whole increment. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Activity | Owned | Polymorphic `parentType`/`parentId` per XD-0001; soft-delete per XD-0002 |
| Brokerage/Agency identity (as `parentId`) | Read (opaque reference only) | Owned by UNIT-CMS-0005; this unit validates only that it is a syntactically valid id in the caller's tenant, never the parent's own lifecycle |
| Task type/status controlled list (`TskType_ID = 2`) | Read | Owned by UNIT-CMS-0005's reference-lookup scope; consumed here only as `statusId`'s valid-value set |
| Audit trail entry | Emitted | Owned by CAP-CMS-0001; this unit writes one entry per create/update/delete |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth/RBAC (Viewer/Editor); the audit-log write path this unit's mutations feed into |
| UNIT-CMS-0005 | contract (soft, id-only) | Only consumes brokerage/agency and task-type ids as opaque values — no schema coupling |

## Assumptions

- Peak throughput of ≤15 rps (R15) is carried over from the same intake basis used for UNIT-CMS-0010, not a figure measured for activity traffic specifically. Revisit once real traffic is observed.
- `POST` is not made idempotent (R17) because a duplicate log entry is a low-severity, staff-correctable outcome, not a financial or safety one. If this proves wrong in practice, a client-supplied idempotency key can be added without a breaking change (an additive optional header).
- Last-write-wins concurrency (R18) is acceptable because activity entries are a single-operator, low-contention workflow; no requirement here assumes multi-editor simultaneous conflict resolution.
- No service-credential caller exists for this unit today (R20); only user-session callers are in scope.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
