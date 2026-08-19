---
unit: UNIT-CMS-0003
change: original
---

# Tasks — Partner Search API

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate types/stubs from `interfaces/openapi.yaml`, including the four
      discriminated result-item shapes and the shared error envelope — satisfies
      R1, R2, R3, R4, R5, R6, R7, R8, R9, R12, R13, R14, R15

## Data

No schema owned by this unit — nothing to migrate here. This unit reads
UNIT-CMS-0005's brokerage/broker/agency/agent/CGA data read-only; no local
storage task exists.

- [ ] Confirm UNIT-CMS-0005's schema exposes the fields this unit's queries
      depend on (brokerage name/address/state/assigned-UW, broker name/title/
      email/disabled, agency/agent name/address/state, CGA agent name/address)
      before implementation begins — this is a design-time dependency gate, not
      a schema this unit owns — satisfies R1, R2, R3, R4, R5, R6, R8

## Implementation

- [ ] Implement mode validation: reject a `mode` outside the six-value enum, and
      require `term` for `brokerage`/`broker`/`agency`/`cga` or `state` for
      `state-broker`/`state-agent` before any query runs — satisfies R10, R11
- [ ] Implement the brokerage/state-broker predicate (name substring match or
      state equality match) against UNIT-CMS-0005's data, scoped by that
      schema's row-level-security policy — satisfies R1, R3, R24
- [ ] Implement the broker predicate (person-name substring match), returning
      the owning brokerage's id — satisfies R2, R7, R24
- [ ] Implement the agency/state-agent predicate (agency+address substring
      match, or state equality match) — satisfies R4, R6, R24
- [ ] Implement the CGA predicate (agent name/address substring match) —
      satisfies R5, R24
- [ ] Implement the assigned-underwriter exact-match filter (`uw` param) on the
      brokerage predicate — satisfies R9
- [ ] Implement the assigned-underwriter lookup (distinct non-null
      `BAssignedUW` values across brokerages currently assigned at least one) —
      satisfies R8, R24
- [ ] Implement the result assembler: project matched rows to each mode's
      result columns, attach the detail-screen identifier per mode, and build
      the paginated `{ items, total, page, size }` envelope — satisfies R7, R12,
      R13, R14, R15
- [ ] Wire bearer-token authentication and the Viewer-or-above scope check on
      both operations — satisfies R23

## Validation and errors

- [ ] Return `400 term_required` when `term` is absent/empty for a mode that
      requires it — satisfies R10
- [ ] Return `400 state_required` when `state` is absent for a mode that
      requires it — satisfies R11
- [ ] Return `400 invalid_request` for a `mode` outside the closed enum or a
      malformed `state` code — satisfies R10, R11
- [ ] Return `401` for a missing/invalid bearer token on both operations —
      satisfies R23
- [ ] Confirm an empty match set on either operation returns `200` with
      `items: []`/`total: 0`, never an error — satisfies R13

## Observability

- [ ] Emit metrics: request count and latency per `mode`, result-set size
      distribution, `400`/`429` rate — satisfies R26
- [ ] Emit structured logs with caller id, tenant id, `mode`, and whether
      `term`/`state`/`uw` was supplied — never the value itself — satisfies R26,
      R27
- [ ] Instrument the query against UNIT-CMS-0005's data as its own trace span —
      satisfies R26

## Tests

- [ ] Unit tests covering every R-ID branch listed above, including all six
      modes' happy path and their term/state requirement errors
- [ ] Contract tests generated from `interfaces/openapi.yaml` pass
- [ ] Test: two concurrent callers running the same or different searches each
      observe an independent, consistent read (R21)
- [ ] Test: the assigned-UW filter narrows results to an exact match, not a
      substring match, on `BAssignedUW` (R9)
- [ ] Test: every query path runs under UNIT-CMS-0005's row-level-security
      policy — a term or state value that would match another tenant's data
      returns no rows (R24)

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Brokerage/state-broker predicate task; schema-dependency confirmation task |
| R2 | Broker predicate task |
| R3 | Brokerage/state-broker predicate task |
| R4 | Agency/state-agent predicate task; schema-dependency confirmation task |
| R5 | CGA predicate task |
| R6 | Agency/state-agent predicate task |
| R7 | Broker predicate task; result assembler task |
| R8 | Assigned-UW lookup task; schema-dependency confirmation task |
| R9 | Assigned-UW filter task; test task |
| R10 | Mode validation task; validation/errors tasks |
| R11 | Mode validation task; validation/errors tasks |
| R12 | Result assembler task |
| R13 | Result assembler task; validation/errors empty-result task |
| R14 | Result assembler task |
| R15 | Result assembler task; contract-generation task |
| R16 | — no task; platform-floor statement inherited from UNIT-CMS-0005's own availability, not a build item |
| R17 | — no task; a performance budget verified by test/load-test tooling in the engineering repo, not a discrete build task |
| R18 | — no task; capacity assumption, revisited operationally |
| R19 | — no task; enforced by API Gateway configuration outside this unit's build |
| R20 | — no task; inherent to a stateless `GET` |
| R21 | Test task (concurrency) |
| R22 | — no task; enforced by API Gateway configuration outside this unit's build |
| R23 | Bearer-token wiring task; validation/errors `401` task |
| R24 | Predicate implementation tasks; test task (tenant isolation) |
| R25 | — no task; N/A per `requirements.md` |
| R26 | Observability tasks |
| R27 | Observability logging task |
| R28 | — no task; N/A per `requirements.md` |
| R29 | — no task; N/A per `requirements.md` |
| R30 | — no task; N/A per `requirements.md` |
