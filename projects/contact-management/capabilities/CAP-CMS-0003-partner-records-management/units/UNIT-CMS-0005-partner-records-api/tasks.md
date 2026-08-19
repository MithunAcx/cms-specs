---
unit: UNIT-CMS-0005
change: original
---

# Tasks — Partner Records API

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate types/stubs for every operation in `interfaces/openapi.yaml` — satisfies R1, R2, R3, R6, R7, R8, R9, R10, R11, R12, R13, R15, R16, R17, R18, R19, R20, R23, R24

## Data

- [ ] Apply `interfaces/001_create_partner_records_schema.sql`, including the row-level-security policy on every table (Brokerage, Broker, Agency, Agent, Cga, every reference-lookup table, the agency account-code counter, and the audit table) — satisfies R26, R27, R43
- [ ] Confirm the `broker_status` table's unique constraint on `(tenant_id, status_id)` is enforced by the store, not by an application-level scan — satisfies R25
- [ ] Confirm the audit table's application role is granted `INSERT` only — no `UPDATE`, no `DELETE` — satisfies R44
- [ ] No backfill task exists here — the one-time legacy-data cutover into this schema belongs to CAP-CMS-0006/UNIT-CMS-0011 and UNIT-CMS-0012, not this unit's build — satisfies R48

## Implementation

- [ ] Implement the request authorizer: bearer-token validation and per-operation scope check (`cms:brokerages.*`, `cms:agencies.*`, `cms:cgas.*`, `cms:lookups.read`/`.write`) — satisfies R30, R31, R42
- [ ] Implement the tenant-scoped resolver for every id and parent id (brokerage, broker, agency, agent, CGA), producing an identical outcome for "does not exist" and "belongs to another tenant" — satisfies R7, R16, R29, R43
- [ ] Implement the field validator/normalizer: required-field checks; phone/fax normalization to digits with `(nnn) nnn-nnnn` formatting on output; CGA `phone` kept string-typed; CGA `agencyId` normalized across string/integer input — satisfies R4, R14, R21, R22, R28
- [ ] Implement the concurrency enforcer as one atomic compare-and-apply of `version` per write, used by every mutating operation (Brokerage, Broker, Agency, Agent, Cga, and every lookup replace) — satisfies R3, R8, R10, R13, R17, R20, R26, R39, R40
- [ ] Implement brokerage create/read/update, including the read-only `accountCode` field that is never accepted on write — satisfies R1, R2, R3, R5
- [ ] Implement the accounting/billing address sub-resource read/update, sharing the parent Brokerage's own `version` — satisfies R9, R10
- [ ] Implement broker create/read (list)/update under a brokerage — satisfies R6, R7, R8
- [ ] Implement the account-code generator for agency creation, using the per-tenant atomic counter per `ADR-0001`, inside the same operation as the agency insert — satisfies R12
- [ ] Implement agency create/read/update — satisfies R11, R13, R14
- [ ] Implement agent create/read (list)/update under an agency — satisfies R15, R16, R17
- [ ] Implement CGA create/read/update, writing exclusively to the CGA entity and never to the Agent entity — satisfies R18, R19, R20
- [ ] Implement reference-lookup read (any authenticated role) and replace (Administrator only, `403` otherwise) for `states`, `broker-types`, `agent-types`, `broker-statuses` — satisfies R23, R24
- [ ] Implement `disabled` as the sole soft-delete representation on every entity, and confirm no operation blocks editing a record with `disabled: true` — satisfies R27, R33
- [ ] Implement date-only handling (no time component, no timezone coercion) for `contractReceivedDate` and any other date-only field — satisfies R34
- [ ] Implement the audit recorder, writing one append-only record (who, tenant, entity type and id, old/new `version`, timestamp) for every create, update, and disable operation — satisfies R44

## Validation and errors

- [ ] Return `400 invalid_request` naming every failing field in `details[]` for any create/update with a missing or malformed field, before any write occurs — satisfies R28
- [ ] Return `404 not_found` for any id or parent id that does not exist or belongs to another tenant, using an identical response shape for both cases — satisfies R7, R16, R29
- [ ] Return `401 unauthenticated` for any request with a missing or invalid bearer token — satisfies R30
- [ ] Return `403 forbidden` for any request lacking the scope required by the targeted operation, including a non-Administrator calling the lookup-replace operation — satisfies R24, R31
- [ ] Return `409 conflict_version_mismatch` for any write whose supplied `version` does not match the stored value, changing no field — satisfies R3, R8, R10, R13, R17, R20, R26
- [ ] Return `400 invalid_request` for a `broker-statuses` replacement introducing a duplicate `statusId` — satisfies R25
- [ ] Confirm a retried/duplicated create is not deduplicated and produces a second, independent record — satisfies R32

## Observability

- [ ] Emit metrics: request count, latency, and error rate per operation and status code, tagged by tenant — satisfies R45
- [ ] Emit structured logs with `trace_id`, tenant id, operation, entity type and id, and result code — confirm FEIN, NPN, phone, email, and address never appear in a log line — satisfies R45, R46
- [ ] Instrument one trace span per operation, encompassing its store read/write — satisfies R45

## Tests

- [ ] Unit tests covering every R-ID branch listed above
- [ ] Contract tests generated from `interfaces/openapi.yaml` pass
- [ ] Test: a stale-`version` update on every mutable entity (Brokerage, Broker, Agency, Agent, Cga, each lookup type) returns `409 conflict_version_mismatch` with no field changed (R3, R8, R10, R13, R17, R20, R26)
- [ ] Test: a cross-tenant id (brokerage, broker, agency, agent, CGA, and every parent-id path) returns the same `404` shape as a nonexistent id (R7, R16, R29)
- [ ] Test: CGA create/update writes only to the CGA entity, never to the Agent entity (R19, DR-1)
- [ ] Test: CGA `phone` round-trips as a string regardless of the caller's input formatting (R21, DR-2)
- [ ] Test: CGA `agencyId` accepted as either a string or an integer-shaped value resolves to the same normalized record (R22, DR-6)
- [ ] Test: a `broker-statuses` replacement with a duplicate `statusId` is rejected before any write (R25, DR-7)
- [ ] Test: updating an entity with `disabled: true` succeeds like any other update (R33)
- [ ] Test: two concurrent creates of unrelated top-level records both succeed independently (Concurrency matrix)
- [ ] Test: two concurrent agency creates each receive a distinct, non-colliding `accountCode` (ADR-0001)

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Contracts task; Brokerage create/read/update task |
| R2 | Brokerage create/read/update task |
| R3 | Concurrency enforcer task; Brokerage create/read/update task; validation/errors 409 task; test task |
| R4 | Field validator/normalizer task |
| R5 | Brokerage create/read/update task |
| R6 | Broker task |
| R7 | Tenant-scoped resolver task; Broker task; validation/errors 404 task; test task |
| R8 | Concurrency enforcer task; Broker task; validation/errors 409 task; test task |
| R9 | Accounting sub-resource task |
| R10 | Concurrency enforcer task; Accounting sub-resource task; validation/errors 409 task; test task |
| R11 | Agency create/read/update task |
| R12 | Account-code generator task; test task |
| R13 | Concurrency enforcer task; Agency create/read/update task; validation/errors 409 task; test task |
| R14 | Field validator/normalizer task; Agency create/read/update task |
| R15 | Agent task |
| R16 | Tenant-scoped resolver task; Agent task; validation/errors 404 task; test task |
| R17 | Concurrency enforcer task; Agent task; validation/errors 409 task; test task |
| R18 | CGA task |
| R19 | CGA task; test task |
| R20 | Concurrency enforcer task; CGA task; validation/errors 409 task; test task |
| R21 | Field validator/normalizer task; test task |
| R22 | Field validator/normalizer task; test task |
| R23 | Reference-lookup task |
| R24 | Reference-lookup task; validation/errors 403 task |
| R25 | Data — broker_status uniqueness task; validation/errors task; test task |
| R26 | Concurrency enforcer task; Data — RLS/schema task; validation/errors 409 task; test task |
| R27 | Disabled-representation task |
| R28 | Field validator/normalizer task; validation/errors 400 task |
| R29 | Tenant-scoped resolver task; validation/errors 404 task; test task |
| R30 | Request authorizer task; validation/errors 401 task |
| R31 | Request authorizer task; validation/errors 403 task |
| R32 | Validation/errors — repeated-create confirmation task |
| R33 | Disabled-representation task; test task |
| R34 | Date-only handling task |
| R35 | — no task; platform-floor availability statement, bounded by UNIT-CMS-0001's own availability, not a build item |
| R36 | — no task; latency budget verified operationally, not a discrete build item |
| R37 | — no task; capacity assumption, revisited operationally |
| R38 | — no task; enforced by API Gateway configuration outside this unit's build |
| R39 | Concurrency enforcer task; test task |
| R40 | Concurrency enforcer task; test task |
| R41 | — no task; enforced by API Gateway configuration outside this unit's build |
| R42 | Request authorizer task |
| R43 | Tenant-scoped resolver task; Data — RLS/schema task |
| R44 | Audit recorder task; Data — audit-table grants task |
| R45 | Observability tasks |
| R46 | Observability logging task |
| R47 | — no task; erasure design is an open, non-blocking question in `requirements.md` — revisit before this unit is handed off if answered |
| R48 | Data — no-backfill statement task |
| R49 | — no task; N/A per `requirements.md`, no flagged rollout planned |
