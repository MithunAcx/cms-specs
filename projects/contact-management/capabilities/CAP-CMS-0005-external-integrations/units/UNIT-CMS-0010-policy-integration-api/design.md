---
unit: UNIT-CMS-0010
updated: 2026-08-18
---

# Design — Policy Integration API

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

A single stateless, synchronous read endpoint that stands between the CMS frontend and
the external policy-administration system. On each call it: (1) resolves the requested
brokerage or agency, validating it belongs to the caller's tenant, (2) resolves that
record's producer id, (3) makes a live, synchronous call to the policy-administration
system for that producer id, (4) computes a `deepLinkUrl` per policy from its class, and
(5) returns the assembled list. No response is cached and no policy data is written to
this project's own datastore, so the shape stays a thin, synchronous proxy rather than an
integration with its own state to reason about. The alternative considered — caching
policy reads for a short TTL to absorb upstream latency — was rejected because R13
requires every read to reflect the upstream system's current answer, and a stale cache
is exactly the failure that requirement exists to prevent.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Request validator | Rejects malformed `parentType`/`parentId` before any lookup or upstream call | R6 |
| Tenant-scoped parent resolver | Resolves `parentId` to a brokerage/agency row within the caller's own tenant; resolves the producer id from that row | R4, R7, R21, R22 |
| Policy-system client | Makes the live synchronous call to the policy-administration system, with a bounded timeout | R1, R11, R12, R13 |
| Deep-link resolver | Computes `deepLinkUrl` per policy from `classId` (15/16/17 → healthcare page, else → underwriter page) using server-side base-URL configuration | R2, R3 |
| Response assembler | Builds the final `{ items: [...] }` shape; strips anything upstream that is not part of the contract | R1, R3, R25 |

## Flows

### GET /policies — happy path — satisfies R1, R2, R3, R4, R7, R8

1. Caller sends `GET /api/v1/policies?parentType=&parentId=` with a bearer token.
2. Request validator checks the token is present and valid (R8); rejects malformed
   `parentType`/`parentId` (R6).
3. Tenant-scoped parent resolver looks up the brokerage/agency by `parentId` **within
   the caller's tenant**; not-found (wrong tenant or nonexistent) → `404` (R7).
4. Resolver reads that record's stored producer id.
5. Policy-system client calls the policy-administration system with the resolved
   producer id, within the stated timeout budget (R15).
6. Deep-link resolver computes `deepLinkUrl` for each returned policy from its `classId`.
7. Response assembler returns `{ items: [{ policyId, status, term, insured, classId, subclass, deepLinkUrl }] }`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401` (R8) |
| 2 — malformed query params | `400 invalid_request` (R6) |
| 3 — `parentId` not found in caller's tenant | `404 not_found` (R7) — identical shape whether the row does not exist or belongs to another tenant |
| 5 — upstream unreachable, connection refused, non-2xx | `502 upstream_unavailable` (R11) |
| 5 — upstream exceeds timeout budget | `502 upstream_unavailable`; request is not held open past the budget (R12) |
| 5 — upstream answers with zero policies | `200` with `items: []` — success, not an error (R11 distinction) |
| 6 — `classId` outside the known set | Defaults to the underwriter page; logged as an observability event (unknown class), never a 5xx — an unmapped class must not break the read |

## Data model

This unit owns no persistent entity — see `requirements.md` § Data. The only local
read is the brokerage/agency's producer-id attribute, owned by UNIT-CMS-0005; its shape
lives in that unit's own `interfaces/`, not here.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| — (none owned) | — | — | — |

## Contracts

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Policy read | sync HTTP | `interfaces/openapi.yaml` | R1, R2, R3, R6, R7, R8, R11, R12 |

## State and idempotency

This unit holds no state and performs no write, so there is no state machine and no
idempotency key to derive (R9, R18) — every call is a fresh, independent read, and a
retried or duplicated call has no cumulative effect (R9, R10, R19).

## Cross-cutting

| Concern | Decision |
|---|---|
| authn/authz | Bearer token validated per CAP-CMS-0001; minimum role Viewer (R8, R21) |
| validation | `parentType` restricted to `brokerage`/`agency`; `parentId` format validated before any lookup (R6) |
| errors | Shared envelope `{ error: { code, message } }`; `502 upstream_unavailable` for any upstream failure, `404 not_found` for missing/foreign-tenant `parentId`, `400 invalid_request` for malformed input (R6, R7, R11) |
| observability | Metrics: request count, upstream latency, upstream error rate. Logs: caller id, tenant id, `parentType`, `parentId`, upstream status — never policy content (R24, R25) |
| performance | p95 ≤ 900 ms / p99 ≤ 2500 ms inclusive of cold start and upstream round trip (R15) |
| migration/backfill | N/A — greenfield, no owned data (R27) |
| feature flag | N/A — no flagged rollout planned (R28) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Policy-administration system has no stated SLA | Unbounded tail latency could exceed this unit's own p99 budget regardless of this unit's own code | Bounded client-side timeout (R12) turns an unbounded hang into a fast, observable `502`; document the bound as a caller-facing contract, not an internal implementation detail |
| Producer-id resolution logic diverges from what the legacy system computed | A brokerage/agency could get zero or wrong policies after cutover, undetected until a user notices | Resolution rule is recorded in `ADR-0001` with its own reversal criteria; UNIT-CMS-0011's migration validation report should spot-check a sample of resolved producer ids against legacy behaviour |
| `classId` values outside the known healthcare set (15/16/17) shift over time | Deep-link routing silently sends users to the wrong page | Unknown-class default (underwriter page) is explicit and logged as an observability event, not a silent guess (see Flows) |

## Decisions

| ADR | Decision |
|---|---|
| `decisions/ADR-0001-producer-id-resolution.md` | Producer id is resolved per-request from the brokerage/agency's own stored attribute, replacing the legacy hard-coded literal `2105941587` |

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Flow: GET /policies happy path; Policy-system client |
| R2 | Deep-link resolver |
| R3 | Deep-link resolver; Response assembler; Cross-cutting → errors |
| R4 | Tenant-scoped parent resolver; ADR-0001 |
| R5 | Contracts — only one `GET` operation exists in `interfaces/openapi.yaml`, by construction |
| R6 | Request validator; Failure paths |
| R7 | Tenant-scoped parent resolver; Failure paths |
| R8 | Request validator; Failure paths; Cross-cutting → authn/authz |
| R9 | State and idempotency |
| R10 | State and idempotency |
| R11 | Policy-system client; Failure paths |
| R12 | Policy-system client; Failure paths; Cross-cutting → performance |
| R13 | Approach (no-cache rationale) |
| R14 | Risks (SLA-less dependency) |
| R15 | Cross-cutting → performance |
| R16 | Contracts / capacity — inherited from `requirements.md`, no separate design section needed |
| R17 | Cross-cutting → errors (`429`, gateway-level, not unit-designed) |
| R18 | State and idempotency |
| R19 | State and idempotency |
| R20 | Cross-cutting → errors |
| R21 | Cross-cutting → authn/authz |
| R22 | Tenant-scoped parent resolver |
| R23 | N/A per `requirements.md` — no design section needed for a non-applicable NFR |
| R24 | Cross-cutting → observability |
| R25 | Cross-cutting → observability; Data model |
| R26 | N/A per `requirements.md` |
| R27 | Cross-cutting → migration/backfill |
| R28 | Cross-cutting → feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
