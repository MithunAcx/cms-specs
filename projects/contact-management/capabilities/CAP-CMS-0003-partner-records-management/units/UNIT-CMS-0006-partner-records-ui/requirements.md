---
id: UNIT-CMS-0006
slug: partner-records-ui
project: CMS
capability: CAP-CMS-0003
title: Partner Records UI
kind: frontend
target_repo: CMS-web
owner: "@MithunAcx"
engineering:
  frontend: { applicable: true }
  api:      { applicable: false }
created: 2026-08-18
updated: 2026-08-18
---

# Partner Records UI

## Scope

Brokerage/Agency Detail screens (tabs for master details, brokers/agents grid,
accounting address), the CGA management grid, and the reference-lookup admin screens.
Embeds UNIT-CMS-0008's activity grid and calls UNIT-CMS-0009/0010's address-suggest and
policy-read contracts directly on these same screens. Consumes UNIT-CMS-0005's full
CRUD contract as a closed shape.

**In scope:**
- Brokerage/Agency Detail screens, CGA grid, accounting-address dialog, reference-lookup admin screens
- Inline add/edit for brokers/agents; optimistic-concurrency conflict handling in the UI
- Embedding UNIT-CMS-0008's activity grid and UNIT-CMS-0009/0010's address-suggest/policy-read widgets on these screens
- The "Add New Agency"/"Add New Brokerage" create forms themselves (launched by UNIT-CMS-0004)

**Out of scope:**
- Record CRUD logic, validation, or persistence (UNIT-CMS-0005)
- Search/discovery landing (UNIT-CMS-0004)
- The activity grid's own logic (UNIT-CMS-0008) and the address-suggest/policy-read logic (UNIT-CMS-0009/0010) — this unit only embeds those components

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
| UNIT-CMS-0001 | contract | Auth/session, role-driven control visibility |
| UNIT-CMS-0004 | navigation | Launched from search results and the create-flow entry points |
| UNIT-CMS-0005 | contract | The full brokerage/agency/CGA/lookup CRUD contract |
| UNIT-CMS-0008 | embed | Activity grid component embedded on Brokerage/Agency Detail |
| UNIT-CMS-0009 | contract | Address-suggest, embedded on every address form |
| UNIT-CMS-0010 | contract | Policy-read, embedded on the Policy tab |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
