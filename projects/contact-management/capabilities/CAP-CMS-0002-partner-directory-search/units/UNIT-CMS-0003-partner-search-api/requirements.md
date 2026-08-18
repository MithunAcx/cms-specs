---
id: UNIT-CMS-0003
slug: partner-search-api
project: CMS
capability: CAP-CMS-0002
title: Partner Search API
kind: backend
target_repo: CMS-partner-directory-search
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Partner Search API

## Scope

The six-mode search contract (`GET /search`, per XD-0001) plus the assigned-underwriter
lookup, read-only against UNIT-CMS-0005's brokerage/agency/CGA data. Owns no entity of
its own — its seam is the read-only query boundary against another unit's schema, one
contract (`/search` and `/lookups/assigned-uws`), independently verifiable once that
schema exists.

**In scope:**
- The six search modes as query-parameter variants of one endpoint (XD-0001)
- The assigned-underwriter filter lookup
- Server-side pagination/filtering for all six modes

**Out of scope:**
- Writing to brokerage/agency/CGA data (UNIT-CMS-0005 owns it; this unit is read-only — XD-0002)
- The Directory screen's UI (UNIT-CMS-0004)
- Launching "Add New Agency"/"Add New Brokerage" (a UI navigation concern, UNIT-CMS-0004/UNIT-CMS-0006)

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
| UNIT-CMS-0001 | contract | Auth/RBAC — every search endpoint requires an authenticated Viewer-or-above request |
| UNIT-CMS-0005 | schema | Read-only queries against brokerage/agency/CGA data; this unit cannot be built until that schema exists |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
