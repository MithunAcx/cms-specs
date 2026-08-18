---
id: UNIT-CMS-0009
slug: address-integration-api
project: CMS
capability: CAP-CMS-0005
title: Address Integration API
kind: backend
target_repo: CMS-external-integrations
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Address Integration API

## Scope

A stateless server-side proxy to SmartyStreets (kept per intake Q5), exposing one
suggest endpoint whose response shape matches UNIT-CMS-0005's address sub-resource
(XD-0002 of this capability's design). Owns no persistent entity. Independent of every
other unit in the project — can be built in parallel with anything else.

**In scope:**
- `GET /address/suggest` — proxying to SmartyStreets, credentials held server-side only
- The suggestion response shape (line1/city/state/zip) matching UNIT-CMS-0005's address fields

**Out of scope:**
- Which forms call this endpoint, or how they use the result (UNIT-CMS-0006)
- Any address data persistence (UNIT-CMS-0005)

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
| UNIT-CMS-0001 | contract | Auth — every call still requires an authenticated Viewer-or-above request |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
