---
id: UNIT-CMS-0007
slug: activity-api
project: CMS
capability: CAP-CMS-0004
title: Activity API
kind: backend
target_repo: CMS-contact-activity-tracking
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Activity API

## Scope

Owns the polymorphic `Activity` entity (`parentType`/`parentId`, XD-0001), soft delete
(XD-0002), and server-derived `userName` (XD-0003). Its four-endpoint contract in
`capability-design.md` is independent of any specific brokerage/agency schema — it only
needs an opaque parent reference — so it can be built without waiting on UNIT-CMS-0005.

**In scope:**
- Create/list/update/soft-delete activity entries against either parent type
- Server-derived `userName` and `enteredDate`; server-set `completedDate` on completion
- Follow-up-date/completed-state sort and filter

**Out of scope:**
- Which entity is a valid parent, or that entity's own lifecycle (UNIT-CMS-0005)
- The task-type/status controlled list's maintenance (UNIT-CMS-0005's reference-lookup scope)
- Rendering the activity grid (UNIT-CMS-0008)

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
| UNIT-CMS-0001 | contract | Auth/RBAC; the audit-log write path this unit's mutations feed into |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
