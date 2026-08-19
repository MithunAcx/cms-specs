---
unit: UNIT-CMS-0009
change: original
---

# Tasks — Address Integration API

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate types/stubs from `interfaces/openapi.yaml` — satisfies R1, R2, R3, R4, R5, R6, R9, R10

## Data

No schema owned by this unit — nothing to migrate. This unit persists nothing and
reads nothing from this project's own datastore.

## Implementation

- [ ] Implement request validation rejecting a missing, empty, or below-minimum-length (3 characters) `q` before any upstream call — satisfies R4
- [ ] Implement the SmartyStreets client with a bounded timeout, reading the provider API key and endpoint from server-side configuration only — satisfies R1, R2, R3, R9, R10, R12
- [ ] Implement response assembly that strips every provider field except `line1`/`city`/`state`/`zip` before returning the result — satisfies R1, R6
- [ ] Wire bearer-token authentication and the Viewer-or-above scope check — satisfies R5, R18
- [ ] Assemble and return the final `{ suggestions: [...] }` shape per `interfaces/openapi.yaml`, excluding any field not in the contract — satisfies R1, R6

## Validation and errors

- [ ] Return `400 invalid_request` for a missing, empty, or below-minimum-length `q` — satisfies R4
- [ ] Return `401` for missing/invalid bearer token — satisfies R5
- [ ] Return `502 upstream_unavailable` for SmartyStreets outage, error response, or timeout, and never on a successful empty-result answer — satisfies R9, R10

## Observability

- [ ] Emit metrics: request count, upstream call latency, upstream error rate — satisfies R21
- [ ] Emit structured logs with caller id, tenant id, and `q` length only — never the raw query text — satisfies R21, R22
- [ ] Instrument the upstream call to SmartyStreets as its own trace span — satisfies R21

## Tests

- [ ] Unit tests covering every R-ID branch listed above
- [ ] Contract tests generated from `interfaces/openapi.yaml` pass
- [ ] Test: upstream outage/timeout produces `502`, never conflated with a genuine zero-match answer (R9 vs. R1 distinction)
- [ ] Test: a below-minimum-length `q` is rejected before any upstream call is attempted (R4)
- [ ] Test: two concurrent calls with the same or different `q` each complete independently with no shared state (R8)

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | SmartyStreets client task; response-assembly task |
| R2 | SmartyStreets client task |
| R3 | SmartyStreets client task |
| R4 | Request validation task; validation/errors task; test task |
| R5 | Bearer-token wiring task; validation/errors task |
| R6 | Response-assembly task |
| R7 | — no task; inherent to a stateless `GET`; covered by contract tests |
| R8 | — no task; inherent to a stateless `GET`; covered by concurrency test task |
| R9 | SmartyStreets client task; validation/errors task; test task |
| R10 | SmartyStreets client task; validation/errors task |
| R11 | — no task; platform-floor statement, not a build item |
| R12 | SmartyStreets client task (bounded timeout) |
| R13 | — no task; capacity assumption, revisited operationally |
| R14 | — no task; enforced by API Gateway configuration outside this unit's build |
| R15 | — no task; inherent to a stateless `GET` |
| R16 | — no task; inherent to a stateless `GET` |
| R17 | — no task; enforced by API Gateway configuration outside this unit's build |
| R18 | Bearer-token wiring task |
| R19 | — no task; N/A per `requirements.md` |
| R20 | — no task; N/A per `requirements.md` |
| R21 | Observability tasks |
| R22 | Observability logging task |
| R23 | — no task; N/A per `requirements.md` |
| R24 | — no task; N/A per `requirements.md` |
| R25 | — no task; N/A per `requirements.md` |
