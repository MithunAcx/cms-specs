---
unit: UNIT-CMS-0005
updated: 2026-08-18
---

# Design — Partner Records API

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

One synchronous CRUD service standing in front of six owned entities — Brokerage,
Broker, Agency, Agent, Cga, and ReferenceLookup — plus an append-only audit trail.
Every mutable entity carries a single `version` field (XD-0002); every write is a
single atomic store operation that both checks the supplied `version` against the
currently stored value and applies the change, so the comparison and the write can
never observe two different states of the world. Every entity carries a single
`disabled` boolean (XD-0003) with no other soft-delete or history representation.
The accounting/billing address (FR-BRK-8/9) is modeled as a set of fields on the
same Brokerage record rather than as a separately versioned resource, so it shares
the brokerage's own `version` — a deliberate trade-off discussed in Risks. Reference
lookups are modeled and stored exactly like every other owned entity (tenant-scoped,
versioned) rather than as global, unscoped tables, per the Assumption recorded in
`requirements.md`.

The alternative considered for the accounting sub-resource was a second entity with
its own `version`, keyed 1:1 to Brokerage. That was rejected here: it doubles the
concurrency surface for a sub-resource that `capability.md`'s own volume constraint
(low hundreds of records, back-office staff) makes very unlikely to be edited
concurrently with the brokerage's main fields, and XD-0002 requires a `version` on
every *mutable table*, not on every mutable field-group within a table. If usage
later shows this is a real source of spurious conflicts, splitting it out is a
schema change, not a contract change — no caller-visible shape moves.

Account-code generation (FR-AGY-2, R12) is a contested-enough call — the generated
code becomes an externally visible reference the moment an agency is created, so
getting the shape wrong is expensive to unwind — that it is recorded separately;
see `decisions/ADR-0001-account-code-generation.md`.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Request authorizer | Validates the bearer token, resolves the caller's tenant and role, and checks the scope required for the targeted operation | R30, R31, R42 |
| Tenant-scoped resolver | Resolves every id (brokerage, broker, agency, agent, CGA, and every parent id) to a row within the caller's own tenant; a missing or foreign-tenant id is indistinguishable | R7, R16, R29, R43 |
| Field validator/normalizer | Enforces required fields; normalizes phone/fax to digits and formats them on output; normalizes CGA `agencyId` across string/integer input; keeps CGA `phone` as a string | R4, R14, R21, R22, R28 |
| Concurrency enforcer | Performs the compare-and-apply of `version` as one atomic store operation on every write; rejects a stale `version` without changing any field | R3, R8, R10, R13, R17, R20, R26, R39, R40 |
| Account-code generator | Produces a new agency's account code as part of the same create operation, per `ADR-0001` | R12 |
| CGA writer | Writes CGA creates/updates exclusively to the CGA entity | R19, DR-1 |
| Reference-lookup manager | Serves lookup reads to any authenticated role; restricts lookup writes to Administrator; enforces `Status_ID` uniqueness on `broker-statuses` | R23, R24, R25 |
| Audit recorder | Writes one append-only audit record for every create, update, and disable operation | R44, R47 |

## Flows

### Create a top-level record (Brokerage, Agency, or Cga) — satisfies R2, R4, R12, R14, R19, R21, R22, R26, R28, R30, R31, R32

1. Caller (Editor) sends a create request with the entity's required fields.
2. Request authorizer checks the bearer token and the entity's write scope.
3. Field validator normalizes and validates the fields (phone/fax/zip/email/FEIN,
   CGA's string-typed phone and normalized `agencyId`).
4. The store assigns a new id, sets `version: 1`, and persists the record —
   [Agency only] the account-code generator runs as part of the same atomic
   operation (`ADR-0001`).
5. Audit recorder writes one audit record for the create.
6. Response returns `201` with the created record.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401 unauthenticated` (R30) |
| 2 — token valid, wrong scope | `403 forbidden` (R31) |
| 3 — missing required field or malformed value | `400 invalid_request`, every failing field named in `details[]`; nothing is persisted (R28) |
| 4 — store failure of any kind | The create is aborted atomically; no partial record and no orphaned account code are ever visible — a caller sees a server-side failure, never a half-created record |
| repeated call (retry, double-submit) | Not deduplicated — a second, independent record is created (R32); this is a stated design choice, not a gap |

### Read a record or sub-resource — satisfies R1, R6, R9, R11, R15, R18, R23, R29

1. Caller sends a `GET` with a bearer token.
2. Request authorizer checks the token and the entity's read scope (every role
   Viewer and above holds every `.read` scope; lookups are readable by any role).
3. Tenant-scoped resolver locates the record (or, for a sub-collection or parent id
   in the path, resolves the parent first) within the caller's own tenant.
4. Response returns the record or list, including `version` on every mutable
   record.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401 unauthenticated` |
| 3 — id or parent id does not exist, or belongs to another tenant | `404 not_found` — the two cases are identical by design (R29) |

### Update a record or sub-resource (including the accounting sub-resource) — satisfies R3, R8, R10, R13, R17, R20, R26, R33, R34, R39, R40

1. Caller (Editor) sends a `PUT` with the entity's fields and `version`.
2. Request authorizer checks the token and the entity's write scope.
3. Tenant-scoped resolver locates the record; a record with `disabled: true` is
   located and editable exactly like any other (R33) — no terminal state blocks it.
4. Field validator normalizes and validates the fields.
5. Concurrency enforcer performs one atomic operation: compare the supplied
   `version` to the stored value, and if — and only if — they match, apply every
   field change and increment `version`.
6. Audit recorder writes one audit record for the update.
7. Response returns `200` with the updated record, or the conflict outcome below.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token, or wrong scope | `401`/`403` |
| 3 — id not found in caller's tenant | `404 not_found` |
| 4 — missing/malformed field | `400 invalid_request`; no field changed |
| 5 — supplied `version` does not match the stored value | `409 conflict_version_mismatch`; no field changed, `version` unchanged (R3, R26) |

### Create a sub-collection record (Broker under a Brokerage, Agent under an Agency) — satisfies R6, R7, R15, R16

1. Caller (Editor) sends a create request against the parent's sub-collection path.
2. Request authorizer checks the token and write scope.
3. Tenant-scoped resolver resolves the parent id within the caller's tenant;
   missing or foreign-tenant parent → `404` (R7, R16, R29).
4. Field validator validates the child's fields.
5. Store assigns a new id and `version: 1` to the child record, associated with
   the resolved parent.
6. Audit recorder writes one audit record.
7. Response returns `201` with the created child record.

Failure paths mirror "Create a top-level record", with the parent-resolution
failure (`404`) inserted before validation.

### Read or replace a reference lookup — satisfies R23, R24, R25

1. **Read:** any authenticated role (Viewer and above) may `GET /lookups/{type}`;
   the tenant-scoped resolver still applies (R43, and the Assumption in
   `requirements.md` that lookups are tenant-scoped).
2. **Write:** only Administrator may `PUT /lookups/{type}`; any other role is
   rejected with `403 forbidden` (R24) before the write is attempted.
3. For `broker-statuses`, the store enforces `Status_ID` as a unique logical key —
   a replacement list containing a duplicate `Status_ID` is rejected with `400
   invalid_request` before anything is written (R25, DR-7).

## Data model

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| Brokerage | id (tenant-scoped) | Master fields (FR-BRK-4) plus accounting/billing address fields (FR-BRK-8/9) sharing the same `version`; read-only ePay/AccountCode; `disabled` | Life of the partner relationship; personal fields (FEIN, phone, fax) redactable per R47 |
| Broker | id (tenant-scoped), owned by a Brokerage | Name, type/title, email, NPN, `disabled`, `version` | As above; personal fields redactable per R47 |
| Agency | id (tenant-scoped) | Master fields (FR-AGY-4), generated account code (`ADR-0001`), flags (High Potential, Premium Financing), `disabled`, `version` | Life of the partner relationship |
| Agent | id (tenant-scoped), owned by an Agency | Name, type/title, phone, email, NPN, `disabled`, `version` | As above; personal fields redactable per R47 |
| Cga | id (tenant-scoped) | Agent name, address, city, state, zip, email, phone (string-typed, R21), associated `agencyId` (normalized, R22), `version` | Life of the partner relationship |
| ReferenceLookup | (type, tenant) | `states` \| `broker-types` \| `agent-types` \| `broker-statuses`; `broker-statuses` entries carry a unique `Status_ID` (R25) | Maintained indefinitely by Administrator |
| AuditRecord | append-only, keyed by its own id | Who, tenant, entity type + id, old/new `version`, timestamp, operation | 7 years (R44, R47) |

## Contracts

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Partner Records API | sync HTTP | `interfaces/openapi.yaml` | R1–R25, R28–R34, R39–R43 |
| Partner records storage schema | storage (relational) | `interfaces/001_create_partner_records_schema.sql` | R25, R26, R27, R34, R43, R44 |

## State and idempotency

**State.** Each entity has a lightweight two-state lifecycle over one field:
`disabled: false` (active) and `disabled: true` — both directions are legal at any
time (R33), and neither is terminal; there is no third state and no hard delete.
The invariant that actually matters operationally is on `version`, not on
`disabled`: **`version` increments by exactly one on every successful write, and
never on a rejected one** — enforced by the concurrency enforcer performing the
compare-and-apply as one atomic store operation, never as an application-level
read-then-write (R26, R39, R40).

**Idempotency walk — `PUT` (update).** The idempotency key is `(resource id,
version)`, and both are fixed before execution (the id from the path, the version
from the request body) — neither is computed during execution.
- First attempt: `version` matches, write applies, `version` increments.
- Client retry of the same request, before any other write: identical outcome —
  the retry either lands first (applies) or second and observes a `version` that
  is now stale from its own prior success, so it degrades to the documented
  conflict outcome rather than reapplying — no double effect.
- Crash after the store applies the write but before the response reaches the
  caller: the caller cannot tell success from failure from the dropped response
  alone, but a subsequent `GET` shows the incremented `version`, so the caller can
  always determine whether the write landed before deciding to retry.
- Concurrent second caller: see the Concurrency matrix.
There is no scheduler, no message redelivery, and no external call in this unit's
own write path (account-code generation happens inside the same atomic create), so
those idempotency-walk classes do not apply here.

**`POST` (create) is explicitly not idempotent** (R32) — there is no key to derive
a create against, by the capability's own stated convention. A retried or
duplicated create produces a second, independent record every time; a caller
needing exactly-once creation must reconcile via a `GET` first.

## Concurrency matrix

| Concurrent pair | Winner | Enforcement |
|---|---|---|
| Two `PUT`s on the same resource, same starting `version` | First to apply; second observes the new `version` as stale → `409` | Storage-level: the version check and the write are one atomic operation, not a read-then-write in application code |
| `PUT` on a Brokerage's main fields concurrent with `PUT` on its accounting sub-resource | First to apply wins; second gets `409` even though the two touched different fields | Storage-level, by construction — see Risks for the accepted trade-off of sharing one `version` |
| Two `POST`s creating different top-level records | Both succeed independently | No contention — distinct ids, no shared state |
| `POST` of a Broker/Agent under a parent, concurrent with a `PUT` that sets that parent's `disabled: true` | Both succeed independently | Child-record creation does not check the parent's `disabled` flag — `disabled` never blocks a write (R33's principle extended to children) |
| Two `PUT`s replacing the same `lookups/{type}` list | First to apply wins; second gets `409` | Same version-based enforcement as any other entity |
| A `broker-statuses` `PUT` introducing a `Status_ID` that collides with another row in the same replacement | Rejected outright | Storage-level uniqueness constraint on `Status_ID`, not an application-level scan (R25, DR-7) |

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | Every table this unit owns — including reference lookups (Assumption, `requirements.md`) — is scoped by `tenant_id` and enforced by a row-level-security policy (R43); applied identically on read and write |
| authn/authz | Bearer token validated per CAP-CMS-0001; scopes `cms:brokerages.*`, `cms:agencies.*`, `cms:cgas.*`, `cms:lookups.read`/`cms:lookups.write`; Viewer holds all `.read`, Editor additionally holds all `.write` except `cms:lookups.write`, Administrator holds everything (R30, R31, R42) |
| validation | Required-field and shape checks before any write; phone/fax normalized to digits and formatted on output; CGA phone kept string-typed; CGA `agencyId` normalized across string/integer input (R4, R14, R21, R22, R28) |
| errors | Shared envelope `{ error: { code, message, details, trace_id } }`; `409 conflict_version_mismatch` distinguished from a generic `409`; `404` identical for missing and foreign-tenant ids (R3, R26, R29) |
| observability | Metrics: request count, latency, error rate per operation and status code, tagged by tenant. Logs: `trace_id`, tenant id, operation, entity type + id, result code — never FEIN, NPN, phone, email, or address (R45, R46) |
| performance | p95 ≤ 300 ms / p99 ≤ 800 ms per operation, budgeted for cold starts (R36) |
| migration/backfill | N/A — this unit defines the target schema; the one-time legacy cutover belongs to UNIT-CMS-0011/0012 (R48) |
| feature flag | N/A — no flagged rollout planned (R49) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The accounting sub-resource shares the Brokerage's single `version` rather than having its own | An Editor updating brokerage master fields and another Editor updating the accounting address at the same moment produces a spurious `409` for whichever applies second, even though the fields do not overlap | Accepted given the capability's stated low volume (low hundreds of records, back-office staff); revisit as a schema change (not a contract change) if usage shows this is a real source of friction |
| Account-code generation is a new algorithm with no legacy precedent to validate against | A generated code could collide, or could be rejected by a downstream system expecting the legacy format | `ADR-0001` records the chosen mechanism and its reversal criteria; confirm with any downstream consumer of agency account codes before this unit is handed off |
| Reference lookups' tenant-scoping (R43 applied to lookup tables) is an unconfirmed assumption | If lookups should instead be global, every lookup table's RLS policy and seeding approach needs rework | Flagged as an open, non-blocking question in `requirements.md`; resolve before `interfaces/schema.sql` is finalized if an answer arrives first |
| The erasure design (redact personal fields in place, retain the record shell) is unconfirmed with a compliance owner | Could conflict with an actual compliance requirement for full removal | Flagged as an open, non-blocking question in `requirements.md`; the audit trail's own severance approach mirrors it, so both would need to change together |
| Task/activity-status lookups are assumed to belong to CAP-CMS-0004, not this unit | If wrong, CAP-CMS-0004's design will expect an endpoint this unit does not expose | Recorded as an assumption; surfaces the first time CAP-CMS-0004's own unit design is written |
| *(resolved 2026-08-19)* `capability-design.md`'s Unified API Contract previously named `page`/`size` as the shared pagination convention, which conflicted with `10-platform.md`'s always-loaded, project-wide rule of cursor-only pagination ("no offset pagination anywhere") | An implementation following the capability's convention literally would have violated the platform floor | `capability-design.md`'s Pagination convention row and its `listBrokers`/`listAgents` entries are now corrected to cursor-based (`limit`/`cursor` in, `items`/`next_cursor` out) — see its Change log, 2026-08-19. `interfaces/openapi.yaml`'s two list operations (`listBrokers`, `listAgents`) already used this shape; the capability document now matches rather than merely being superseded by it. No residual risk — kept as a closed row for traceability. |

## Decisions

| ADR | Decision |
|---|---|
| `decisions/ADR-0001-account-code-generation.md` | Agency account-code generation mechanism, replacing the legacy `ppsp_add_accountcode` procedure |

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Flow: Read a record or sub-resource |
| R2 | Flow: Create a top-level record |
| R3 | Flow: Update a record or sub-resource; Concurrency matrix |
| R4 | Field validator/normalizer; Flow: Create a top-level record |
| R5 | Contracts — `interfaces/openapi.yaml` accepts no `AccountCode` field on write, by construction |
| R6 | Flow: Read a record or sub-resource |
| R7 | Flow: Create a sub-collection record; Tenant-scoped resolver |
| R8 | Flow: Update a record or sub-resource; Concurrency matrix |
| R9 | Flow: Read a record or sub-resource |
| R10 | Flow: Update a record or sub-resource (accounting sub-resource); Concurrency matrix |
| R11 | Flow: Read a record or sub-resource |
| R12 | Flow: Create a top-level record; Account-code generator; ADR-0001 |
| R13 | Flow: Update a record or sub-resource; Concurrency matrix |
| R14 | Field validator/normalizer |
| R15 | Flow: Read a record or sub-resource |
| R16 | Flow: Create a sub-collection record; Tenant-scoped resolver |
| R17 | Flow: Update a record or sub-resource; Concurrency matrix |
| R18 | Flow: Read a record or sub-resource |
| R19 | CGA writer; Flow: Create a top-level record |
| R20 | Flow: Update a record or sub-resource; Concurrency matrix |
| R21 | Field validator/normalizer |
| R22 | Field validator/normalizer |
| R23 | Flow: Read or replace a reference lookup |
| R24 | Flow: Read or replace a reference lookup |
| R25 | Flow: Read or replace a reference lookup; Concurrency matrix |
| R26 | Concurrency enforcer; State and idempotency; Concurrency matrix |
| R27 | State and idempotency (disabled is the sole representation) |
| R28 | Field validator/normalizer; Flow: Create a top-level record |
| R29 | Tenant-scoped resolver; Flow: Read a record or sub-resource |
| R30 | Request authorizer; Cross-cutting → authn/authz |
| R31 | Request authorizer; Cross-cutting → authn/authz |
| R32 | Flow: Create a top-level record (repeated-call row); Idempotency walk |
| R33 | Flow: Update a record or sub-resource (step 3) |
| R34 | Data model; Cross-cutting → validation |
| R35 | Risks (account-code / lookup dependencies do not change this) — Cross-cutting → performance frames the same-availability bound with UNIT-CMS-0001 |
| R36 | Cross-cutting → performance |
| R37 | Cross-cutting → performance (capacity inherited from `requirements.md`; no separate design section needed) |
| R38 | Cross-cutting → performance (gateway-level shedding, not unit-designed) |
| R39 | State and idempotency; Concurrency matrix |
| R40 | Concurrency matrix |
| R41 | Cross-cutting → errors (gateway-level, not unit-designed) |
| R42 | Cross-cutting → authn/authz |
| R43 | Cross-cutting → tenant isolation |
| R44 | Audit recorder; Data model (AuditRecord) |
| R45 | Cross-cutting → observability |
| R46 | Cross-cutting → observability; Data model |
| R47 | Data model; Risks (erasure design) |
| R48 | Cross-cutting → migration/backfill |
| R49 | Cross-cutting → feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
