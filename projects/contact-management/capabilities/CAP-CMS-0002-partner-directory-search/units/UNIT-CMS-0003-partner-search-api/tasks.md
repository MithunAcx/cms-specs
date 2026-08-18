---
unit: UNIT-<CODE>-NNNN
change: original
---

# Tasks — <Title>

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate types/stubs from `interfaces/openapi.yaml` — satisfies R1

## Data

Schema and migration tasks from `interfaces/*.sql`, plus any backfill the design
flagged as its own task.

- [ ] Apply the schema in `interfaces/*.sql` — satisfies R4

## Implementation

- [ ]

## Validation and errors

- [ ]

## Observability

- [ ]

## Tests

- [ ] Unit tests covering every R-ID branch listed above
- [ ] Contract tests generated from `interfaces/` pass

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 |  |
