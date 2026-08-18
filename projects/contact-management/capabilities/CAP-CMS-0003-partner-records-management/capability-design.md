---
capability: CAP-CMS-0003
title: Partner Records Management
project: CMS
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Partner Records Management — capability design

## Capability overview

**Capability:** CAP-CMS-0003 — Partner Records Management
**Outcome measures this design serves:** M1
**Projected units:** 2

## Prospective units

| # | Prospective unit | Kind | Target repo | Owns | Serves |
|---|------------------|------|-------------|------|--------|
| U1 | partner-records-api | backend | CMS-partner-records-management | Brokerage, Broker, Agency, Agent, Cga, ReferenceLookup entities | M1 |
| U2 | partner-records-ui | frontend | CMS-web | nothing persistent | M1 (UX), FR-BRK/FR-AGY/FR-CGA/FR-REF |

## Cross-unit decisions (XD log)

| # | Decision | Rationale | Affects | Cited by |
|---|----------|-----------|---------|----------|
| XD-0001 | The domain model is the clean projection in raw-ask §6.5 (`Brokerage`, `Broker`, `Agency`, `Agent`, `Cga`), not a column-for-column mirror of the legacy SQL Server tables | Confirmed by intake Q1/A1 — the target datastore is PostgreSQL, and legacy physical quirks (DR-1..DR-8) are not reproduced, only their domain intent | U1, U2 | _pending units_ |
| XD-0002 | Every brokerage/agency/CGA/broker/agent mutating endpoint accepts a `version` field on write and rejects a stale write with `409 conflict_version_mismatch` | Optimistic concurrency control on shared master records, per intake Q10 | U1, U2 | _pending units_ |
| XD-0003 | `disabled` is a single clean boolean field on every entity, replacing the legacy `history`/`History` mixed-convention flags (int `-1/0` vs `char(10)`) | DR-3's domain intent, carried forward per XD-0001 | U1, U2 | _pending units_ |
| XD-0004 | The `address` sub-resource shape (`{ line1, line2, city, state, zip }`) used on every brokerage/agency/CGA/accounting form must match the shape CAP-CMS-0005's address-suggest endpoint fills | Keeps the autocomplete-fill contract and the persisted address shape identical, so U2 never has to reshape data between the two | U1, U2, and (cross-capability) CAP-CMS-0005 | _pending units_ |

## Shared database schema

No entity in this capability is touched by more than one *prospective* unit — U1 owns
every persistent entity (Brokerage, Broker, Agency, Agent, Cga, ReferenceLookup); U2 is a
pure API consumer with no server-side schema of its own. U1's own entity design (fields,
types, relationships per raw-ask §6.1/§6.2, reshaped through XD-0001/XD-0003) belongs in
its own `design.md`.

**Constraints that carry a requirement:** every table U1 owns needs its own row-level
security policy (`stack.md`); the `version` field XD-0002 requires exists on every
mutable table, not just some.

## Unified API contract

### Shared conventions

| Concern | Convention |
|---|---|
| Versioning | `/api/v1/...` |
| Auth header shape | `Authorization: Bearer <access token>`, validated per CAP-CMS-0001/XD-0002 |
| Pagination | `page`/`size` for list endpoints (e.g. brokers/agents/CGA grids); total count and page metadata included |
| Error envelope | `{ error: { code, message, fields? } }` — `409 conflict_version_mismatch` per XD-0002 is a distinguished error code, not a generic `409` |
| Idempotency | `PUT` idempotent by resource id and `version`; `POST` creates are not idempotent |
| Rate limiting response | `429` with `Retry-After` |

### partner-records-api (U1) — endpoints

| Method | Path | Request | Response | Status / errors | Min role |
|--------|------|---------|----------|------------------|----------|
| GET | `/api/v1/brokerages/{id}` | — | `Brokerage` (XD-0001 shape) | `404` | Viewer |
| POST | `/api/v1/brokerages` | `Brokerage` fields (FR-BRK-1) | `Brokerage` with new id | `400` validation | Editor |
| PUT | `/api/v1/brokerages/{id}` | `Brokerage` fields + `version` | updated `Brokerage` | `400`, `409` (XD-0002) | Editor |
| GET | `/api/v1/brokerages/{id}/brokers` | — | `Broker[]` | — | Viewer |
| POST | `/api/v1/brokerages/{id}/brokers` | `Broker` fields | `Broker` with new id | `400` | Editor |
| PUT | `/api/v1/brokers/{id}` | `Broker` fields + `version` | updated `Broker` | `400`, `409` | Editor |
| GET | `/api/v1/brokerages/{id}/accounting` | — | `Brokerage.accounting` sub-resource | `404` | Viewer |
| PUT | `/api/v1/brokerages/{id}/accounting` | accounting fields + `version` | updated accounting sub-resource | `400`, `409` | Editor |
| GET | `/api/v1/agencies/{id}` | — | `Agency` | `404` | Viewer |
| POST | `/api/v1/agencies` | `Agency` fields (FR-AGY-1) | `Agency` with new id and generated account code | `400` | Editor |
| PUT | `/api/v1/agencies/{id}` | `Agency` fields + `version` | updated `Agency` | `400`, `409` | Editor |
| GET | `/api/v1/agencies/{id}/agents` | — | `Agent[]` | — | Viewer |
| POST | `/api/v1/agencies/{id}/agents` | `Agent` fields | `Agent` with new id | `400` | Editor |
| PUT | `/api/v1/agents/{id}` | `Agent` fields + `version` | updated `Agent` | `400`, `409` | Editor |
| GET | `/api/v1/cgas/{id}` | — | `Cga` | `404` | Viewer |
| POST | `/api/v1/cgas` | `Cga` fields (FR-CGA-1) | `Cga` with new id | `400` | Editor |
| PUT | `/api/v1/cgas/{id}` | `Cga` fields + `version` | updated `Cga` | `400`, `409` | Editor |
| GET | `/api/v1/lookups/{type}` (`states`\|`broker-types`\|`agent-types`\|`broker-statuses`) | — | lookup list | — | Viewer |
| PUT | `/api/v1/lookups/{type}` | lookup values | updated list | `400` | Administrator |

### partner-records-ui (U2) — endpoints

None. U2 consumes every endpoint above.

## End-to-end flow diagrams

### Create a brokerage and add its first broker

```
U2                                    U1 (partner-records-api)         CAP-CMS-0005 (address-suggest)
 |  fill brokerage form, address lookup                                 |
 |------------------------------------------------------------------------------------------------------>|
 |  suggestions                                                                                            |
 |<------------------------------------------------------------------------------------------------------|
 |  POST /brokerages { ...fields, address }                            |
 |------------------------------------->|                               |
 |  201 { id, ...fields, version: 1 }   |                               |
 |<---------------------------------------
 |  navigate to Brokerage Detail (id)   |
 |  POST /brokerages/{id}/brokers       |
 |------------------------------------->|
 |  201 { id, ...fields }               |
 |<---------------------------------------
```

| Step | Unit | Touches |
|------|------|---------|
| Address autocomplete during entry | U2 → CAP-CMS-0005 | XD-0004 (address shape) |
| Create the brokerage | U2 → U1 | XD-0001, XD-0002 (initial `version: 1`) |
| Navigate to detail, add a broker | U2 → U1 | — |

### Concurrent edit rejected

```
U2 (tab A)                 U2 (tab B)                 U1
 |  GET /brokerages/1 (version: 3)       GET /brokerages/1 (version: 3)
 |<---------------------------------------------------------------------|
 |  PUT { ..., version: 3 } → 200 (version: 4)
 |----------------------------------------------------------------------->
 |                            PUT { ..., version: 3 } → 409 conflict_version_mismatch
 |                            ----------------------------------------------------->
```

| Step | Unit | Touches |
|------|------|---------|
| Two tabs load the same record | U2 | — |
| First save succeeds, bumps version | U2 → U1 | XD-0002 |
| Second save (stale version) is rejected | U2 → U1 | XD-0002 |

## Build and sequencing order

| Order | Unit | Blocked by | Why |
|-------|------|------------|-----|
| 1 | U1 partner-records-api | CAP-CMS-0005's address-suggest contract shape agreed (XD-0004) | U1's address sub-resource must match what CAP-CMS-0005 returns |
| 2 | U2 partner-records-ui | U1 designed | U2 is written against U1's endpoint contracts |

## Handoff notes to unit design

### partner-records-api (U1)

**Inherits as fixed:**
- `XD-0001` — the clean domain model shape
- `XD-0002` — the version-based optimistic concurrency contract on every mutable table
- `XD-0003` — the single `disabled` boolean convention
- `XD-0004` — the address sub-resource shape
- The full endpoint contract above

**Its own to decide:**
- Physical table/column design, indexing, and RLS policy details
- Account-code generation algorithm (replacing `ppsp_add_accountcode`)
- Validation/normalization implementation for phone, zip, email, FEIN, dates (NFR-VAL-1)

### partner-records-ui (U2)

**Inherits as fixed:**
- `XD-0001` through `XD-0004`
- The full endpoint contract above

**Its own to decide:**
- Brokerage/Agency Detail tab layout, inline-grid editing UX for brokers/agents (FE-2-equivalent), the Add Agency confirm-dialog's two-choice flow (FR-AGY-2)
- Client-side validation mirroring server rules (NFR-VAL-2)

## Open questions

| # | Question | Owner | Blocks |
|---|----------|-------|--------|

## Change log

| Date | Change | Units whose `design.md` must follow |
|------|--------|-------------------------------------|
