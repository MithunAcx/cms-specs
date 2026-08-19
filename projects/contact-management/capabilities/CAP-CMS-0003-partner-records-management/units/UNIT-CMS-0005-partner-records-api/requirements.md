---
id: UNIT-CMS-0005
slug: partner-records-api
project: CMS
capability: CAP-CMS-0003
title: Partner Records API
kind: backend
target_repo: CMS-partner-records-management
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Partner Records API

## Scope

Owns the Brokerage, Broker, Agency, Agent, Cga, and ReferenceLookup entities in the
clean domain-model shape (XD-0001), with optimistic concurrency (XD-0002), the single
`disabled` boolean convention (XD-0003), and an address sub-resource shape matching
UNIT-CMS-0009's suggest contract (XD-0004). The full CRUD/lookup contract in
`capability-design.md`'s Unified API Contract section is this unit's closed endpoint
set — independently specifiable and verifiable as one deployable.

**In scope:**
- Brokerage/broker, agency/agent, CGA create/read/update, including accounting-address sub-resource
- Reference-lookup read (all roles) and write (Administrator only)
- Optimistic concurrency (`version` field, `409 conflict_version_mismatch`) on every mutable entity
- Account-code generation on brokerage/agency creation

**Out of scope:**
- Discovery/search of these records (UNIT-CMS-0003)
- Contact activity (UNIT-CMS-0007) and policy display (UNIT-CMS-0009/0010) — this unit exposes no endpoint for either
- Address-suggestion itself (UNIT-CMS-0009) — this unit only persists the address shape that contract fills
- The one-time legacy-data cutover into this schema (UNIT-CMS-0011/0012)

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | `GET /brokerages/{id}` returns the brokerage's full master detail (name, address, city, state, zip, phone, fax, tax id/FEIN, assigned underwriter, status, contract-received date, `disabled`, `version`, and the read-only ePay/AccountCode field) for a Viewer or above. | CAP-CMS-0003/A1, FR-BRK-4 | P0 |
| R2 | `POST /brokerages` creates a brokerage from the FR-BRK-1 field set, assigns a new id, sets `version: 1`, and returns `201` with the created record — for an Editor. | CAP-CMS-0003/A1, FR-BRK-1, FR-BRK-2 | P0 |
| R3 | `PUT /brokerages/{id}` updates the FR-BRK-4 field set when the request carries the current `version`; a stale `version` is rejected with `409 conflict_version_mismatch` and no field is changed. | CAP-CMS-0003/A1, A3, FR-BRK-6, XD-0002 | P0 |
| R4 | Phone and fax are normalized to digits-only on save and are always returned formatted as `(nnn) nnn-nnnn`. | FR-BRK-5, NFR-VAL-1 | P0 |
| R5 | The brokerage's ePay/AccountCode field is present on every read and is never accepted on `POST` or `PUT` — it is server-assigned and read-only through this unit's contract. | FR-BRK-5, 50-api-contracts.md Rule 11 | P0 |
| R6 | `GET /brokerages/{id}/brokers` returns the brokerage's brokers (first name, last name, broker type/title, email, NPN, `disabled`) for a Viewer or above. | CAP-CMS-0003/A1, FR-BRK-7 | P0 |
| R7 | `POST /brokerages/{id}/brokers` creates a broker under the named brokerage for an Editor; a `brokerageId` that does not resolve to a brokerage in the caller's own tenant is rejected with `404 not_found`. | CAP-CMS-0003/A1, FR-BRK-7 | P0 |
| R8 | `PUT /brokers/{id}` updates a broker's fields when the request carries the current `version`; a stale `version` is rejected with `409 conflict_version_mismatch`. | CAP-CMS-0003/A1, A3, XD-0002 | P0 |
| R9 | `GET /brokerages/{id}/accounting` returns the brokerage's accounting/billing address sub-resource (contact name, address, city, state, zip) for a Viewer or above. | CAP-CMS-0003/A1, FR-BRK-8 | P0 |
| R10 | `PUT /brokerages/{id}/accounting` updates the accounting sub-resource when the request carries the current `version`; a stale `version` is rejected with `409 conflict_version_mismatch`. | CAP-CMS-0003/A1, A3, FR-BRK-9, XD-0002 | P0 |
| R11 | `GET /agencies/{id}` returns the agency's full master detail (name, address, city, state, zip, phone, agency number/"G1 Agency ID", billing contact, billing contact phone, notes, High Potential flag, Premium Financing flag, `disabled`, `version`) for a Viewer or above. | CAP-CMS-0003/A1, FR-AGY-4 | P0 |
| R12 | `POST /agencies` creates an agency from the FR-AGY-1 field set, runs account-code generation, assigns a new id, sets `version: 1`, and returns `201` with the created record and its generated account code — for an Editor. | CAP-CMS-0003/A1, FR-AGY-1, FR-AGY-2 | P0 |
| R13 | `PUT /agencies/{id}` updates the FR-AGY-4 field set when the request carries the current `version`; a stale `version` is rejected with `409 conflict_version_mismatch`. | CAP-CMS-0003/A1, A3, XD-0002 | P0 |
| R14 | Agency phone numbers are normalized (punctuation stripped) on save. | FR-AGY-5, NFR-VAL-1 | P1 |
| R15 | `GET /agencies/{id}/agents` returns the agency's agents (first name, last name, agent type/title, phone, email, NPN, `disabled`) for a Viewer or above. | CAP-CMS-0003/A1, FR-AGY-6 | P0 |
| R16 | `POST /agencies/{id}/agents` creates an agent under the named agency for an Editor; an `agencyId` that does not resolve to an agency in the caller's own tenant is rejected with `404 not_found`. | CAP-CMS-0003/A1, FR-AGY-6 | P0 |
| R17 | `PUT /agents/{id}` updates an agent's fields when the request carries the current `version`; a stale `version` is rejected with `409 conflict_version_mismatch`. | CAP-CMS-0003/A1, A3, XD-0002 | P0 |
| R18 | `GET /cgas/{id}` returns the CGA record (agent name, address, city, state, zip, email, phone, associated agency id, `version`) for a Viewer or above. | CAP-CMS-0003/A1, FR-CGA-1 | P0 |
| R19 | `POST /cgas` creates a CGA record from the FR-CGA-1 field set for an Editor, and writes exclusively to the CGA entity — never to the Agent entity. | CAP-CMS-0003/A1, A2, FR-CGA-1, FR-CGA-3, DR-1 | P0 |
| R20 | `PUT /cgas/{id}` updates a CGA record's fields when the request carries the current `version`; a stale `version` is rejected with `409 conflict_version_mismatch`. | CAP-CMS-0003/A1, A3, XD-0002 | P0 |
| R21 | CGA `phone` is accepted, stored, and returned as a string, preserving whatever formatting the caller supplied — never coerced to a numeric type. | FR-CGA-4, DR-2 | P0 |
| R22 | A CGA's `agencyId` is accepted whether the caller sends it as a string or an integer-shaped value, and is normalized to one internal representation before being stored or compared. | DR-6 | P1 |
| R23 | `GET /lookups/{type}` (`states`\|`broker-types`\|`agent-types`\|`broker-statuses`) returns the current lookup list for a Viewer or above. | CAP-CMS-0003/A4, FR-REF-1 | P0 |
| R24 | `PUT /lookups/{type}` replaces a lookup's values for an Administrator only; a Viewer or Editor calling this operation is rejected with `403 forbidden`. | CAP-CMS-0003/A4, FR-REF-2 | P0 |
| R25 | `broker-statuses` values are stored with `Status_ID` enforced as a unique logical key, even though the legacy table declared no primary key — a `PUT` that would introduce a duplicate `Status_ID` is rejected with `400 invalid_request`. | DR-7 | P1 |
| R26 | Every mutable entity (Brokerage, Broker, Agency, Agent, Cga, and each lookup list) carries a `version` field on every read, requires it on every write, and rejects a write carrying anything other than the current stored value with `409 conflict_version_mismatch`, changing no field. | CAP-CMS-0003/A3, XD-0002 | P0 |
| R27 | `disabled` is a single boolean field on Brokerage, Broker, Agency, Agent and Cga; no other history/status representation is exposed through this unit's contract. | CAP-CMS-0003/A1, XD-0003, DR-3 | P0 |
| R28 | A request to any create or update operation missing a required field, or carrying a field of the wrong shape, is rejected with `400 invalid_request` naming every failing field in `details[]`, before any write occurs. | NFR-VAL-2 | P0 |
| R29 | A request whose path or body references a brokerage, broker, agency, agent, or CGA id belonging to a different tenant is rejected with `404 not_found` — identical to the "id does not exist" case, so cross-tenant existence is never disclosed. | 10-platform.md Tenancy | P0 |
| R30 | An unauthenticated request to any operation in this unit is rejected with `401 unauthenticated`. | CAP-CMS-0001 | P0 |
| R31 | An authenticated request lacking the scope required for the operation it targets (see R46) is rejected with `403 forbidden`. | CAP-CMS-0001 | P0 |
| R32 | A repeated or retried `POST` (double submit, client retry, at-least-once redelivery from a caller) is not deduplicated by this unit and creates a second record — creates in this unit are not idempotent, and a caller needing exactly-once creation must reconcile via a `GET` before retrying. | CAP-CMS-0003 Unified API Contract (Idempotency) | P1 |
| R33 | Updating an entity whose `disabled` field is `true` is permitted through the same `PUT` operation as any other update — `disabled` is not a terminal state that blocks further edits. | XD-0003 | P2 |
| R34 | `contract-received date` and every other date-only field is stored and returned as a date with no time component, and is never coerced to a timestamp. | 10-platform.md Formats | P1 |

## Behaviour detail

**R3/R8/R10/R13/R17/R20/R26 — the shared conflict shape.** Every mutating `PUT` in
this unit follows the identical contract: the request body carries `version`; the
store compares it against the currently stored value in the same operation that
applies the write; a mismatch changes nothing and returns `409
conflict_version_mismatch`. This is the single mechanism XD-0002 requires, applied
uniformly rather than re-derived per entity.

**R7/R16/R29 — parent-id and cross-tenant resolution collapse to one behaviour.** A
`brokerageId`/`agencyId` that does not exist and one that belongs to another tenant
produce the same `404 not_found` — the two cases are indistinguishable to the caller
by design, so tenant membership is never disclosed through a different status code or
message.

**R19/R21/R22 — CGA's three legacy-defect corrections.** These are the only
behaviours this unit inherits directly from the raw ask's traceability matrix as
named defects (DR-1, DR-2, DR-6) rather than as fresh functional asks; each has its
own dedicated regression coverage per CAP-CMS-0003/A2.

**R32 — non-idempotent creates is a stated design choice, not a gap.**
`capability-design.md`'s Unified API Contract states plainly that `POST` creates are
not idempotent; this requirement exists so that behaviour is asserted rather than
silently absent, and so a client integration is not built assuming otherwise.

**Dependency outage (UNIT-CMS-0001).** If the auth dependency this unit calls to
validate a bearer token is down, slow, or times out, every operation in this unit
fails closed with `401 unauthenticated` (or the gateway-level equivalent) — never with
a fallback to an unauthenticated or reduced-trust path. This unit's own observed
availability can never exceed UNIT-CMS-0001's (see R35).

**Ordering.** N/A — this unit performs no asynchronous operation and emits no event;
every operation is a synchronous request/response, so there is no ordering class to
specify.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R35 | availability | Target 99.9% monthly for this unit's own compute. Effective availability for a caller is bounded above by UNIT-CMS-0001's own availability (every operation requires a valid token) — R30/R31's fail-closed behaviour is how that bound is made observable rather than silently inherited. |
| R36 | latency | p95 ≤ 300 ms, p99 ≤ 800 ms for every synchronous operation, budgeted to absorb serverless cold starts per `stack.md`'s cold-start consequence row. |
| R37 | throughput | Peak figure: ≤10 requests/second. ASSUMPTION — derived from CAP-CMS-0003's Constraints row ("low hundreds of brokerages/agencies/CGAs", intake Q8), not a measured figure; no larger caller population than back-office staff exists for this unit. Revisit once real traffic is observed. |
| R38 | surge | At 2× peak (~20 rps), API Gateway throttling (`stack.md`) sheds excess requests with `429` + `Retry-After`; a write already accepted for processing is never aborted mid-write to make room for new requests. |
| R39 | idempotency | `PUT` is idempotent by resource id + `version` (R26): replaying an identical request before any other write succeeds produces the same resulting state; replaying it after a successful application observes a now-stale `version` and receives `409`, which is the expected idempotent-conflict outcome, not a new error class. `POST` is explicitly not idempotent — see R32. |
| R40 | concurrency | Covered by R26: of two callers writing the same resource, the first to apply wins and bumps `version`; the second observes the new `version` as stale and is rejected, never silently overwritten (CAP-CMS-0003/A3). |
| R41 | rate limits | Enforced by API Gateway throttling per `stack.md`, per caller and per resource path; response is `429` with `Retry-After`. No tension with peak load (R37) is expected at this unit's stated volume. |
| R42 | authorization | Scopes: `cms:brokerages.read`/`cms:brokerages.write`, `cms:agencies.read`/`cms:agencies.write`, `cms:cgas.read`/`cms:cgas.write`, `cms:lookups.read`, `cms:lookups.write`. Viewer holds every `.read` scope; Editor additionally holds every `.write` scope except `cms:lookups.write`; Administrator holds all of the above. Ownership rule: no per-record ownership beyond tenant membership — any in-tenant Editor/Administrator may write any record in scope (ASSUMPTION — ownership was not restricted further in the raw ask; ties to Assumptions below). |
| R43 | tenant isolation | Every table this unit owns is scoped by `tenant_id` and enforced by a row-level-security policy (`stack.md`), applied identically to reads and writes — R29 is that guarantee made observable at the API boundary. |
| R44 | audit | Every create, update, and disable operation across Brokerage, Broker, Agency, Agent, and Cga writes an audit record (who, tenant, entity type and id, old and new `version`, timestamp) to an append-only audit store; immutability is enforced by granting no update or delete privilege on that store, only insert. Retention: 7 years (20-compliance.md). |
| R45 | observability | Metrics: request count, latency, and error rate per operation and status code, tagged by tenant. Structured log fields: `trace_id`, tenant id, operation, entity type and id, result code. FEIN, NPN, phone, email, and address never appear in a log line (see R46). Trace span boundary: one span per operation, encompassing its store read/write. |
| R46 | data classification | FEIN (tax id), NPN, phone, fax, email, and every address field are personal data; none is special category (CAP-CMS-0003 Constraints — no special-category PII in this capability). Brokerage/agency name, notes, and status fields are not personal data. |
| R47 | retention and deletion | Brokerage/Agency/CGA/Broker/Agent records are retained for the life of the partner relationship; the audit trail retains 7 years per R44. Erasure of an individual's personal fields (a broker's or agent's name, email, phone, NPN) is performed by redacting those fields in place while the record shell (id, brokerage/agency association, `version`) is retained for referential integrity; audit records already written under R44 retain their pre-redaction values for the same 7-year window, per the same severance approach `20-compliance.md` requires for financial/regulated records. ASSUMPTION — this erasure design has not been confirmed with a compliance owner; see Open questions. |
| R48 | migration and backfill | N/A for this unit — it defines the target schema; the one-time legacy-data cutover is CAP-CMS-0006/UNIT-CMS-0011 and UNIT-CMS-0012's responsibility, not this unit's. |
| R49 | feature flag | N/A — no flagged or phased rollout is planned for this unit. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Brokerage (incl. accounting sub-resource) | Owned | XD-0001 shape; R1–R5, R9–R10 |
| Broker | Owned | R6–R8 |
| Agency | Owned | XD-0001 shape; R11–R14 |
| Agent | Owned | R15–R17 |
| Cga | Owned | XD-0001 shape; R18–R22 |
| ReferenceLookup (states, broker-types, agent-types, broker-statuses) | Owned | R23–R25; task/activity-status lookups (FR-REF-1's last clause) are out of this unit's scope — see Assumptions |
| AuditRecord | Owned | append-only; R44, R47 |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth/RBAC on every endpoint (R30, R31, R42); this unit's own availability is bounded by UNIT-CMS-0001's (R35) |
| UNIT-CMS-0009 | contract | Address sub-resource shape (XD-0004) must be agreed before this unit's address fields are finalized — no runtime call between the two units; the dependency is a shape agreement, consumed at design time |

## Assumptions

- Peak throughput of ≤10 rps (R37) is derived from CAP-CMS-0003's "low hundreds" volume constraint, not a measured figure — revisit once real traffic is observed.
- No per-record ownership restriction beyond tenant (R42) — any in-tenant Editor/Administrator may edit any brokerage/agency/CGA record, matching the legacy system's apparent behaviour; not explicitly reconfirmed by the sponsor for the new build.
- Reference lookups (R23–R25) are treated as tenant-scoped, like every other table this unit owns, to satisfy 10-platform.md's blanket tenant-isolation rule — even though several lists (e.g., US states) hold identical content across tenants. Revisit if a lookup is later confirmed to be genuinely global rather than per-tenant.
- Task/activity-status lookups named in the capability's raw ask (FR-REF-1's last clause) are out of this unit's scope: `capability-design.md`'s Unified API Contract lists only `states`\|`broker-types`\|`agent-types`\|`broker-statuses` under this unit's `/lookups/{type}` endpoint, so task/activity statuses are assumed to belong to CAP-CMS-0004 (Contact Activity & Follow-up Tracking) instead.
- The erasure design in R47 (redact personal fields in place, retain the record shell) has not been confirmed with a compliance owner — see Open questions.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | Is the R47 erasure design (redact broker/agent personal fields in place, keep the record shell) the intended approach, or does compliance require a different mechanism (e.g. full row removal with a tombstone)? | Nothing in this unit's `design.md`/`interfaces/` — proceeds on the stated assumption | @MithunAcx | open — non-blocking |
| 2 | Should reference lookups genuinely be tenant-scoped, or shared/global across tenants (R43's application to lookup tables)? | Nothing blocking now; affects the RLS policy shape for lookup tables in `interfaces/*.sql` | @MithunAcx | open — non-blocking |
