---
unit: UNIT-<CODE>-NNNN
updated: <YYYY-MM-DD>
---

# Design — <Title>

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

The shape of the solution in a few paragraphs, and why this shape over the
alternatives.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
|  |  | R1, R2 |

## Flows

### <flow name> — satisfies R<n>

1.
2.

Failure paths:

| Step fails | Behaviour |
|---|---|

## Data model

Entities, keys, relationships, ownership, retention. The machine-readable form
lives in `interfaces/*.sql` and `interfaces/*.schema.json`.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|

## Contracts

What this unit exposes and consumes. Each row must correspond to a file in
`interfaces/`.

| Contract | Kind | File | Satisfies |
|---|---|---|---|
|  | sync HTTP | `interfaces/openapi.yaml` | R1 |

## State and idempotency

State transitions, concurrency, replay/retry semantics, idempotency keys.

## Cross-cutting

| Concern | Decision |
|---|---|
| authn/authz |  |
| validation |  |
| errors |  |
| observability |  |
| performance |  |
| migration/backfill |  |
| feature flag |  |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|

## Decisions

Anything consequential gets an ADR in `decisions/`. List them here.

| ADR | Decision |
|---|---|

## Requirement coverage

Every R-ID in `requirements.md` must appear here.

| R-ID | Covered by |
|------|-----------|
| R1 |  |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
