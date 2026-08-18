---
id: UNIT-CMS-0002
slug: identity-access-ui
project: CMS
capability: CAP-CMS-0001
title: Identity Access UI
kind: frontend
target_repo: CMS-web
owner: "@MithunAcx"
engineering:
  frontend: { applicable: true }
  api:      { applicable: false }
created: 2026-08-18
updated: 2026-08-18
---

# Identity Access UI

## Scope

The login screen, session/token handling, and role-aware routing guards consumed by
every other frontend unit. Depends on UNIT-CMS-0001's five auth endpoints as a closed
contract (XD-0001); its own concern is client-side token storage, the login/change-
password forms, and silently refreshing an expired access token. The seam is the
browser/API boundary — this unit is independently verifiable against UNIT-CMS-0001's
contract without any other frontend unit existing yet.

**In scope:**
- Login form, sign-out, and change-password forms
- Client-side storage and refresh of the access/refresh token pair (XD-0001)
- Route guards that redirect unauthenticated requests to sign-in
- Hiding/disabling controls the current role may not use (UI-level defense in depth; the server is still the enforcement point)

**Out of scope:**
- Server-side token issuance, validation, or revocation (UNIT-CMS-0001)
- Any other screen's own content — this unit provides only the shell/guard/session layer other frontend units sit inside

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
| UNIT-CMS-0001 | contract | Auth endpoints (XD-0001) must exist before this unit can be designed against them |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
