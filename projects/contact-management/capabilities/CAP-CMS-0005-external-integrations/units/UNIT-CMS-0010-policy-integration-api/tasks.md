---
unit: UNIT-CMS-0010
change: original
---

# Tasks — Policy Integration API

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate types/stubs from `interfaces/openapi.yaml` — satisfies R1, R2, R3, R6, R7, R8, R11, R12

## Data

No schema owned by this unit — nothing to migrate. This unit reads UNIT-CMS-0005's
brokerage/agency producer-id attribute; no local storage task exists here.

## Implementation

- [ ] Implement request validation for `parentType`/`parentId` before any lookup or upstream call — satisfies R6
- [ ] Implement tenant-scoped parent resolver (brokerage/agency lookup restricted to the caller's tenant) — satisfies R7, R22
- [ ] Implement producer-id resolution from the resolved brokerage/agency record per ADR-0001 — satisfies R4
- [ ] Implement the policy-administration system client with a bounded timeout, surfacing `502 upstream_unavailable` on failure or timeout, and never on a successful empty-result answer — satisfies R1, R11, R12, R13
- [ ] Implement deep-link URL computation from `classId` (15/16/17 → healthcare page, else → underwriter page), reading base URL and producer id only from server-side configuration — satisfies R2, R3
- [ ] Wire bearer-token authentication and the Viewer-or-above scope check — satisfies R8, R21
- [ ] Assemble and return the final response shape per `interfaces/openapi.yaml`, excluding any field not in the contract — satisfies R1, R3, R25

## Validation and errors

- [ ] Return `400 invalid_request` for malformed `parentType`/`parentId` — satisfies R6
- [ ] Return `404 not_found` for a `parentId` outside the caller's tenant or nonexistent, using an identical shape for both cases — satisfies R7
- [ ] Return `401` for missing/invalid bearer token — satisfies R8
- [ ] Confirm no caching layer sits in front of the upstream call — satisfies R13

## Observability

- [ ] Emit metrics: request count, upstream call latency, upstream error rate — satisfies R24
- [ ] Emit structured logs with caller id, tenant id, `parentType`, `parentId`, upstream HTTP status — with no policy content (`insured`, `policyId`, etc.) ever logged — satisfies R24, R25
- [ ] Instrument the upstream call as its own trace span — satisfies R24

## Tests

- [ ] Unit tests covering every R-ID branch listed above
- [ ] Contract tests generated from `interfaces/openapi.yaml` pass
- [ ] Test: upstream outage/timeout produces `502`, never conflated with a genuine empty-result answer (R11 vs R13)
- [ ] Test: cross-tenant `parentId` produces the same `404` shape as a nonexistent `parentId` (R7)

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Policy-administration system client task; response-assembly task |
| R2 | Deep-link URL computation task |
| R3 | Deep-link URL computation task; response-assembly task |
| R4 | Producer-id resolution task |
| R5 | Contracts task — only one operation exists in `interfaces/openapi.yaml`, by construction |
| R6 | Request validation task; validation/errors task |
| R7 | Tenant-scoped parent resolver task; validation/errors task; test task |
| R8 | Bearer-token wiring task; validation/errors task |
| R9 | No dedicated task — inherent to a stateless `GET`; covered by contract tests |
| R10 | No dedicated task — inherent to a stateless `GET`; covered by contract tests |
| R11 | Policy-administration system client task; test task |
| R12 | Policy-administration system client task |
| R13 | No caching confirmation task; test task |
| R14 | — no task; platform-floor statement, not a build item |
| R15 | Policy-administration system client task (bounded timeout) |
| R16 | — no task; capacity assumption, revisited operationally |
| R17 | — no task; enforced by API Gateway configuration outside this unit's build |
| R18 | — no task; inherent to a stateless `GET` |
| R19 | — no task; inherent to a stateless `GET` |
| R20 | — no task; enforced by API Gateway configuration outside this unit's build |
| R21 | Bearer-token wiring task |
| R22 | Tenant-scoped parent resolver task |
| R23 | — no task; N/A per `requirements.md` |
| R24 | Observability tasks |
| R25 | Response-assembly task; observability logging task |
| R26 | — no task; N/A per `requirements.md` |
| R27 | — no task; N/A per `requirements.md` |
| R28 | — no task; N/A per `requirements.md` |
