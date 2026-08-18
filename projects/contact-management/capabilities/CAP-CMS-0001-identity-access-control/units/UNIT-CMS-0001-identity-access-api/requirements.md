---
id: UNIT-CMS-0001
slug: identity-access-api
project: CMS
capability: CAP-CMS-0001
title: Identity Access API
kind: backend
target_repo: CMS-identity-access-control
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Identity Access API

## Scope

Issues and validates the JWT access/refresh token pair, enforces RBAC by exposing the
`role` claim every other capability's backend unit reads locally, and owns the audit
log every mutating endpoint in the system writes to. This is the one deployable every
other unit in the project depends on for authentication, authorization, and audit —
the seam is the platform-wide identity/RBAC/audit contract (`CAP-CMS-0001`'s XD-0001
through XD-0003), independently specifiable and verifiable without any other unit
existing yet.

**In scope:**
- Login, token issuance, and refresh-token rotation/revocation (XD-0001)
- The `role` claim contract every other backend unit validates locally (XD-0002)
- The audit-log entry shape and write path every mutating endpoint in the system uses (XD-0003)
- Change-password (local credentials only, per intake Q3 — unconditionally in scope, not merely "where SSO is unavailable")
- Reference-lookup **permission** (who may maintain lookups) — the lookups themselves are CAP-CMS-0003's

**Out of scope:**
- Single sign-on / corporate identity-provider federation (intake Q3)
- Reference-lookup data and its maintenance screens (CAP-CMS-0003)
- Any other capability's own audit-worthy actions — this unit only provides the shared logging contract, not the calls into it

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

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
