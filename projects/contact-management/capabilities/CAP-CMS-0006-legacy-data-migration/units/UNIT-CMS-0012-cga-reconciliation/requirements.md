---
id: UNIT-CMS-0012
slug: cga-reconciliation
project: CMS
capability: CAP-CMS-0006
title: CGA Reconciliation
kind: data
target_repo: CMS-legacy-data-migration
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# CGA Reconciliation

## Scope

Identifies legacy `pp_agent` rows that are actually mis-inserted CGA records (the
legacy DR-1 bug) and reconciles them into UNIT-CMS-0005's `Cga` entity, linked to the
*new* (post-migration) agency id. Runs after UNIT-CMS-0011 has migrated agencies
(XD-0003); records its own outcomes only via UNIT-CMS-0011's logging contract, never by
writing `MigrationLog` directly (XD-0002).

**In scope:**
- A discovery pass over legacy `pp_agent` to identify CGA-shaped rows
- Reconciling identified rows into the new schema's `Cga` entity, linked to the new agency id
- Flagging ambiguous matches for manual review rather than auto-reconciling them
- Calling UNIT-CMS-0011's logging contract to record each outcome

**Out of scope:**
- General brokerage/agency/broker/agent/activity migration (UNIT-CMS-0011)
- Writing `MigrationLog` directly — this unit only calls UNIT-CMS-0011's logging contract
- Defining the `Cga` entity's schema (UNIT-CMS-0005 owns it)

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
| UNIT-CMS-0011 | contract | Must have migrated agencies first (XD-0003); this unit calls its logging contract rather than owning its own log |
| UNIT-CMS-0005 | schema | Reconciles into the `Cga` entity that unit defines |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | No count of how many `pp_agent` rows are actually CGA mis-inserts is known yet — a discovery pass may be needed before this unit's scope can be sized. | this unit's `requirements.md` (full pass) | @MithunAcx | open |
