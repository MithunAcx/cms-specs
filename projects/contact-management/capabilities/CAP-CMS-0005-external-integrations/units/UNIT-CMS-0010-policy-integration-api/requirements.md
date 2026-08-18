---
id: UNIT-CMS-0010
slug: policy-integration-api
project: CMS
capability: CAP-CMS-0005
title: Policy Integration API
kind: backend
target_repo: CMS-external-integrations
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Policy Integration API

## Scope

A stateless, live read-only proxy to the policy-administration system (intake Q2 — no
replication), exposing one endpoint that returns policy data plus a server-computed
deep-link URL (XD-0003 of this capability's design), so the producer id and base URL
never reach the browser. Owns no persistent entity. Independent of every other unit.

**In scope:**
- `GET /policies` — live read-only call to the policy-administration system
- Server-side computation of the healthcare-vs-underwriter deep-link URL by policy class
- Resolving the producer id per brokerage/agency server-side (replacing the legacy hard-coded literal)

**Out of scope:**
- Creating or editing policy data anywhere (out of scope for the whole project)
- Which screen displays the result (UNIT-CMS-0006)

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | `GET /policies?parentType=brokerage\|agency&parentId=` returns the set of policies associated with the named brokerage or agency, read live from the policy-administration system at request time; no policy data is ever stored in this project's own datastore. | CAP-CMS-0005/A3 | P0 |
| R2 | Every returned policy item includes a server-computed `deepLinkUrl`: classes 15/16/17 resolve to the healthcare detail page, every other class resolves to the underwriter detail page. | CAP-CMS-0005/A3, FR-POL-2 | P0 |
| R3 | The external system base URL and the producer id used to build `deepLinkUrl` are read from server-side configuration; neither appears in the response body, in a log line, or in any client-visible artifact. | CAP-CMS-0005/M1, A4, FR-POL-3 | P0 |
| R4 | The producer id used for a given policy lookup is resolved server-side from the requested brokerage or agency's own record — never a single hard-coded literal for every request. | FR-POL-3, DR-4 | P0 |
| R5 | No endpoint in this unit creates, updates, or deletes policy data — the unit exposes exactly one `GET` operation and nothing else. | CAP-CMS-0005/A4, FR-POL-4 | P0 |
| R6 | A request missing `parentType`, missing `parentId`, or carrying a `parentType` outside `brokerage`/`agency` is rejected with `400 invalid_request` before any upstream call is made. | CAP-CMS-0005/A3 | P1 |
| R7 | A request whose `parentId` does not resolve to a brokerage or agency that belongs to the caller's own tenant is rejected with `404 not_found` — identical to the "record does not exist" case, so tenant membership is never disclosed by the error shape. | 10-platform.md Tenancy | P0 |
| R8 | An unauthenticated request is rejected with `401`; an authenticated request from any role of Viewer or above is accepted — this unit has no elevated-role requirement above Viewer. | CAP-CMS-0001/A1, A2 | P0 |
| R9 | A retried or duplicated `GET /policies` call has no side effect beyond re-reading current data — the operation is naturally idempotent and needs no dedupe key. | — (NFR: idempotency) | P2 |
| R10 | Two concurrent callers requesting the same or different `parentId` each receive an independent live read; neither call observes or blocks on the other. | — (NFR: concurrency) | P2 |
| R11 | When the policy-administration system is unreachable or returns an error, the caller receives `502 upstream_unavailable`; this is distinct from, and never conflated with, the upstream system successfully answering "no policies found" (`200` with `items: []`). | — (NFR: dependency) | P0 |
| R12 | When the policy-administration system does not respond within this unit's stated timeout budget (R-NFR-latency), the caller receives `502 upstream_unavailable` rather than the request hanging past that budget. | — (NFR: dependency) | P0 |
| R13 | Every call reads the policy-administration system directly; no response is served from a cache, so a policy's status or term reflects the upstream system's current answer, never a previously cached one. | CAP-CMS-0005 constraints (live read-only, no replica) | P1 |

## Behaviour detail

**R2 / R4 — deep-link and producer-id resolution.** The producer id is not a
project-wide constant. It is resolved from the requested brokerage's or agency's own
stored producer-id attribute (owned by UNIT-CMS-0005) before the upstream call is made.
See `decisions/ADR-0001-producer-id-resolution.md` for why this replaces the legacy
hard-coded literal `2105941587` and what would reverse the choice.

**R7 — tenant isolation on a read.** Because this unit owns no persistent entity of its
own, tenant isolation is enforced by validating that `parentId` resolves to a
brokerage/agency row visible under the caller's tenant (via UNIT-CMS-0005's
row-level-security-scoped lookup) before the upstream call is issued — never by trusting
a tenant claim embedded in the request.

**R11 vs. R13 — outage vs. answer.** "The upstream system is down" (R11/`502`) and "the
upstream system answered with zero policies" (`200`, empty `items`) are different
outcomes and must never share a status code or an error path.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R14 | availability | This unit's own compute carries the platform default; its *effective* availability for a caller is bounded by the policy-administration system's own availability, which is not owned by this project. `R11`/`R12` are how that bound is made observable rather than silently inherited. |
| R15 | latency | p95 ≤ 900 ms, p99 ≤ 2500 ms end-to-end, inclusive of serverless cold start (per `stack.md`'s cold-start consequence) and the upstream round trip. ASSUMPTION: no measured baseline exists yet for the upstream system's own latency; revisit once observed. |
| R16 | throughput | Peak figure: ≤15 requests/second, derived from intake Q8's "low hundreds of brokerages/agencies, <50 concurrent staff" (small-scale) — ASSUMPTION, not a measured figure; label per rule 30-nfr-floor.md and revisit if traffic proves otherwise. |
| R17 | surge | At 2× peak (~30 rps), API Gateway throttling (per `stack.md`) sheds excess requests with `429` + `Retry-After`; nothing here is exempt from shedding, since every request is a discretionary read. |
| R18 | idempotency | Covered by R9 — `GET` is inherently idempotent; no key is derived or stored. |
| R19 | concurrency | Covered by R10 — no shared mutable state exists in this unit, so no contended operation exists to enforce ordering on. |
| R20 | rate limits | Per caller and per this unit's own endpoint, enforced by API Gateway throttling (`stack.md`); response is `429` with `Retry-After`, matching CAP-CMS-0005's shared error envelope. |
| R21 | authorization | Minimum role: Viewer (R8). No service-credential caller is defined for this unit; ownership rule is "the caller's own session, scoped to their own tenant" — see R7. |
| R22 | tenant isolation | Enforced on the one read this unit performs, per R7 — the caller's tenant must own the `parentId` record before any upstream call is issued. |
| R23 | audit | N/A — this unit performs no create/update/delete operation, so CAP-CMS-0001/M3's audit-log obligation (scoped to mutating operations) does not apply here. |
| R24 | observability | Metrics: request count, upstream call latency, upstream error rate. Structured log fields: caller id, tenant id, `parentType`, `parentId`, upstream HTTP status. Insured name, policy id detail, and any other policy content never appear in a log line (data-classification floor, R26). Trace span boundary: the upstream call to the policy-administration system is its own span. |
| R25 | data classification | `policyId`, `status`, `term`, `classId`, `subclass` — not personal data. `insured` (the named insured on the policy) — personal data, not special category; never logged, never appears in an error message. |
| R26 | retention and deletion | N/A — this unit persists nothing; there is no retention period to define and no erasure path to build, since no policy data is ever stored here. |
| R27 | migration and backfill | N/A — greenfield unit, no data owned, nothing to migrate or backfill. |
| R28 | feature flag | N/A — no flagged rollout is planned for this unit. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Policy (external) | Read (never persisted) | Read live from the policy-administration system per request; this unit is the only place that system's read shape is translated into this project's response shape |
| Brokerage/Agency producer-id attribute | Read | Owned by UNIT-CMS-0005; read here only to resolve the producer id and to validate tenant ownership of `parentId` (R7) |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth — every call still requires an authenticated Viewer-or-above request |
| UNIT-CMS-0005 | contract | Reads the brokerage/agency record to resolve the producer id and to validate tenant ownership of `parentId` |
| Policy-administration system | external | Live read-only call; no replica. Transport mechanism is still open — see Open questions |

## Assumptions

- Peak throughput of ≤15 rps (R16) is derived from intake Q8's qualitative "small scale" statement, not a measured figure. Revisit once real traffic is observed.
- No service-credential caller exists for this unit today (R21); only user-session callers are in scope. If a service-to-service caller is added later, its ownership rule needs its own requirement.
- The policy-administration system has no stated SLA; R14/R15 treat it as best-effort and make the bound observable (`502`) rather than assuming any particular uptime.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | The mechanism for the live read-only call to the policy-administration system (direct DB read, an API it exposes, or something else) is not yet named — intake Q2 confirmed "live call", not the transport. | this unit's `design.md` and `interfaces/` | @MithunAcx | open — non-blocking; `design.md` proceeds on the assumption of a synchronous HTTP call, revisited when the transport is named |
