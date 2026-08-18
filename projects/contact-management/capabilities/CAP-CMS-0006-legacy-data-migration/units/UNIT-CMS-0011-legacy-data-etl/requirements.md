---
id: UNIT-CMS-0011
slug: legacy-data-etl
project: CMS
capability: CAP-CMS-0006
title: Legacy Data ETL
kind: data
target_repo: CMS-legacy-data-migration
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Legacy Data ETL

## Scope

One-time migration of active legacy brokerage/agency/broker/agent/activity/reference-
lookup records into UNIT-CMS-0005's clean-redesign schema (XD-0001). Owns and is the
sole writer of the `MigrationLog` entity (XD-0002), exposing a logging contract
UNIT-CMS-0012 calls rather than writing the table itself. An operator-run job, not a
request-serving service — its "contract" is the migration itself plus the log it
produces, independently verifiable via the validation report.

**In scope:**
- Migrating brokerages, agencies, brokers, agents, activity records, and reference lookups into the new schema
- Owning and writing the `MigrationLog` entity; exposing a logging call UNIT-CMS-0012 uses
- Producing a count/checksum validation report per source table

**Out of scope:**
- Defining the target schema (UNIT-CMS-0005 owns it)
- CGA reconciliation from `pp_agent` (UNIT-CMS-0012 — this unit does not scan for or fix mis-inserted CGA rows)
- Any ongoing sync after cutover — this is a one-time job

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|

## Behaviour detail

Per-requirement detail where a table row is not enough. Reference the R-ID.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0005 | schema | Migration target — cannot run until that schema is designed |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
