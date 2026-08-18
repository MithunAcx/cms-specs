---
id: UNIT-CMS-0008
slug: activity-grid-ui
project: CMS
capability: CAP-CMS-0004
title: Activity Grid UI
kind: frontend
target_repo: CMS-web
owner: "@MithunAcx"
engineering:
  frontend: { applicable: true }
  api:      { applicable: false }
created: 2026-08-18
updated: 2026-08-18
---

# Activity Grid UI

## Scope

A reusable activity-log grid component (list/add/edit/soft-delete) consuming
UNIT-CMS-0007's contract, packaged for embedding into a host screen owned by another
unit (UNIT-CMS-0006's Brokerage/Agency Detail). Independently verifiable against
UNIT-CMS-0007's contract in isolation, before any host screen embeds it.

**In scope:**
- Activity list/add/edit/soft-delete UX, inline within a host screen
- "What's owed next" sort/filter by follow-up date and completed state
- Packaging as an embeddable component with a defined parent-reference input

**Out of scope:**
- Which screen embeds it, or that screen's own layout (UNIT-CMS-0006)
- Activity persistence, soft-delete semantics, or the `UsrName` stamp itself (UNIT-CMS-0007)

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
| UNIT-CMS-0001 | contract | Auth/session, Editor-gated delete control |
| UNIT-CMS-0007 | contract | The four activity endpoints this component calls |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
