---
id: UNIT-CMS-0005
slug: partner-records-api
project: CMS
capability: CAP-CMS-0003
title: Partner Records API
kind: backend
target_repo: CMS-partner-records-management
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Partner Records API

## Scope

Owns the Brokerage, Broker, Agency, Agent, Cga, and ReferenceLookup entities in the
clean domain-model shape (XD-0001), with optimistic concurrency (XD-0002), the single
`disabled` boolean convention (XD-0003), and an address sub-resource shape matching
UNIT-CMS-0009's suggest contract (XD-0004). The full CRUD/lookup contract in
`capability-design.md`'s Unified API Contract section is this unit's closed endpoint
set — independently specifiable and verifiable as one deployable.

**In scope:**
- Brokerage/broker, agency/agent, CGA create/read/update, including accounting-address sub-resource
- Reference-lookup read (all roles) and write (Administrator only)
- Optimistic concurrency (`version` field, `409 conflict_version_mismatch`) on every mutable entity
- Account-code generation on brokerage/agency creation

**Out of scope:**
- Discovery/search of these records (UNIT-CMS-0003)
- Contact activity (UNIT-CMS-0007) and policy display (UNIT-CMS-0009/0010) — this unit exposes no endpoint for either
- Address-suggestion itself (UNIT-CMS-0009) — this unit only persists the address shape that contract fills
- The one-time legacy-data cutover into this schema (UNIT-CMS-0011/0012)

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
| UNIT-CMS-0001 | contract | Auth/RBAC on every endpoint |
| UNIT-CMS-0009 | contract | Address sub-resource shape (XD-0004) must be agreed before this unit's address fields are finalized |

## Assumptions

-

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
