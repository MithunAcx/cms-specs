---
id: UNIT-CMS-0010
slug: policy-integration-api
project: CMS
capability: CAP-CMS-0005
title: Policy Integration API
kind: backend
target_repo: CMS-external-integrations
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Policy Integration API

## Scope

A stateless, live read-only proxy to the policy-administration system (intake Q2 — no
replication), exposing one endpoint that returns policy data plus a server-computed
deep-link URL (XD-0003 of this capability's design), so the producer id and base URL
never reach the browser. Owns no persistent entity. Independent of every other unit.

**In scope:**
- `GET /policies` — live read-only call to the policy-administration system
- Server-side computation of the healthcare-vs-underwriter deep-link URL by policy class
- Resolving the producer id per brokerage/agency server-side (replacing the legacy hard-coded literal)

**Out of scope:**
- Creating or editing policy data anywhere (out of scope for the whole project)
- Which screen displays the result (UNIT-CMS-0006)

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
| 1 | The mechanism for the live read-only call to the policy-administration system (direct DB read, an API it exposes, or something else) is not yet named — intake Q2 confirmed "live call", not the transport. | this unit's `design.md` and `interfaces/` | @MithunAcx | open |
