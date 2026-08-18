---
id: UNIT-CMS-0004
slug: partner-directory-ui
project: CMS
capability: CAP-CMS-0002
title: Partner Directory UI
kind: frontend
target_repo: CMS-web
owner: "@MithunAcx"
engineering:
  frontend: { applicable: true }
  api:      { applicable: false }
created: 2026-08-18
updated: 2026-08-18
---

# Partner Directory UI

## Scope

The Directory/search landing screen: mode switcher, term/state/UW inputs, results
table/card view, and the "Add New Agency"/"Add New Brokerage" launch points. Consumes
UNIT-CMS-0003's `/search` contract as a closed shape; independently verifiable against
that contract once it exists.

**In scope:**
- Search-mode UX (segmented control), term/state/UW inputs, empty-state and result-count display
- Responsive table (desktop) / stacked-card (mobile) result rendering
- Launching the create flows owned by UNIT-CMS-0006 (navigation only, no form logic here)
- Opening a result row into the correct detail screen owned by UNIT-CMS-0006

**Out of scope:**
- Search query logic, ranking, or data access (UNIT-CMS-0003)
- The create-brokerage/create-agency forms themselves (UNIT-CMS-0006)
- Brokerage/agency/CGA detail screens (UNIT-CMS-0006)

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
| UNIT-CMS-0001 | contract | Auth/session (login guard, role-aware display) |
| UNIT-CMS-0003 | contract | The `/search` and `/lookups/assigned-uws` endpoints this screen calls |
| UNIT-CMS-0006 | navigation | Opens into that unit's detail/create screens; does not call its API directly |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
