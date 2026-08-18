---
capability: CAP-CMS-0005
title: External Integrations
project: CMS
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# External Integrations — capability design

## Capability overview

**Capability:** CAP-CMS-0005 — External Integrations
**Outcome measures this design serves:** M1
**Projected units:** 2

## Prospective units

| # | Prospective unit | Kind | Target repo | Owns | Serves |
|---|------------------|------|-------------|------|--------|
| U1 | address-integration-api | backend | CMS-external-integrations | nothing persistent — a stateless proxy | M1, FR-ADDR-1..4 |
| U2 | policy-integration-api | backend | CMS-external-integrations | nothing persistent — a stateless proxy | M1, FR-POL-1..4 |

No frontend unit is projected for this capability: address-suggest and policy-display UI
live inside CAP-CMS-0003's frontend unit, which calls U1 and U2 directly. Both units land
in the same target repo (`CMS-external-integrations`) since both are `backend` kind.

## Cross-unit decisions (XD log)

| # | Decision | Rationale | Affects | Cited by |
|---|----------|-----------|---------|----------|
| XD-0001 | Both units are stateless server-side proxies; provider/system credentials and base URLs are read from secure configuration and never appear in any response body sent to a browser | ARCH-4, ARCH-5, G2, G4 — this is the one property M1 measures across both integrations | U1, U2 | _pending units_ |
| XD-0002 | The address-suggest response item shape (`{ line1, city, state, zip }`) exactly matches CAP-CMS-0003/XD-0004's address sub-resource shape | Lets CAP-CMS-0003's frontend fill a form field-for-field from a suggestion with no reshaping | U1, and (cross-capability) CAP-CMS-0003 | _pending units_ |
| XD-0003 | The policy-read response includes a server-computed `deepLinkUrl` per policy (healthcare vs. underwriter page, per `classId` 15/16/17), rather than returning the raw base URL and producer id for the client to assemble | Keeps FR-POL-3's configuration values (base URL, producer id) off the browser entirely — the client only ever receives a ready-to-open link, satisfying XD-0001 for this specific case | U2 | _pending units_ |

## Shared database schema

Neither prospective unit owns a persistent entity — both are stateless proxies to
external systems (SmartyStreets for U1, the policy-administration system for U2). There
is no shared, or even unit-local, database schema in this capability.

## Unified API contract

### Shared conventions

| Concern | Convention |
|---|---|
| Versioning | `/api/v1/...` |
| Auth header shape | `Authorization: Bearer <access token>`, validated per CAP-CMS-0001/XD-0002 |
| Pagination | N/A — both endpoints return small, bounded result sets |
| Error envelope | `{ error: { code, message } }`; an upstream provider failure surfaces as `502 upstream_unavailable`, never a raw provider error body |
| Idempotency | Both endpoints are `GET` — inherently idempotent |
| Rate limiting response | `429` with `Retry-After` |

### address-integration-api (U1) — endpoints

| Method | Path | Request | Response | Status / errors | Min role |
|--------|------|---------|----------|------------------|----------|
| GET | `/api/v1/address/suggest?q=` | free-text partial address | `{ suggestions: [{ line1, city, state, zip }] }` (XD-0002 shape) | `502 upstream_unavailable` if the provider fails | Viewer |

### policy-integration-api (U2) — endpoints

| Method | Path | Request | Response | Status / errors | Min role |
|--------|------|---------|----------|------------------|----------|
| GET | `/api/v1/policies?parentType=brokerage\|agency&parentId=` | — | `{ items: [{ policyId, status, term, insured, classId, subclass, deepLinkUrl }] }` (XD-0003) | `502 upstream_unavailable` | Viewer |

## End-to-end flow diagrams

### Address autocomplete during brokerage/agency/CGA form entry

```
CAP-CMS-0003's frontend unit          U1 (address-integration-api)      SmartyStreets
   |  GET /address/suggest?q=123 Main             |
   |----------------------------------------------->|
   |                                                 |  (server-side call, credentials held here)
   |                                                 |----------------------------------------->|
   |                                                 |<-----------------------------------------|
   |  { suggestions: [...] } (XD-0002 shape)        |
   |<------------------------------------------------|
   |  fills line1/city/state/zip directly into the form
```

| Step | Unit | Touches |
|------|------|---------|
| Request suggestions | CAP-CMS-0003's frontend → U1 | XD-0002 |
| Proxy to SmartyStreets, credentials never leave the server | U1 | XD-0001 |
| Fill the form with no reshaping | CAP-CMS-0003's frontend | XD-0002 |

### View and open a related policy

```
CAP-CMS-0003's frontend unit          U2 (policy-integration-api)       Policy-administration system
   |  GET /policies?parentType=brokerage&parentId=42
   |----------------------------------------------->|
   |                                                 |  live read-only call
   |                                                 |----------------------------------------->|
   |                                                 |<-----------------------------------------|
   |  { items: [{ ..., deepLinkUrl }] } (XD-0003)   |
   |<------------------------------------------------|
   |  render color-coded rows; "Open" navigates to deepLinkUrl directly
```

| Step | Unit | Touches |
|------|------|---------|
| Request related policies | CAP-CMS-0003's frontend → U2 | XD-0003 |
| Live read-only call to the policy system | U2 | XD-0001, intake Q2 |
| Open a policy | CAP-CMS-0003's frontend | uses the server-computed `deepLinkUrl` directly — no client-side class routing logic or producer id |

## Build and sequencing order

| Order | Unit | Blocked by | Why |
|-------|------|------------|-----|
| — | U1 address-integration-api | — | Independent of U2 and of CAP-CMS-0003's own build; can be built in parallel |
| — | U2 policy-integration-api | — | Independent of U1; can be built in parallel |

Neither unit blocks the other. Both must exist before CAP-CMS-0003's frontend unit can
be considered feature-complete, but that is a cross-capability dependency recorded in
`capability.md` § Dependencies, not an ordering within this capability.

## Handoff notes to unit design

### address-integration-api (U1)

**Inherits as fixed:**
- `XD-0001` — credentials/config server-side only
- `XD-0002` — the suggestion response shape
- The one endpoint above

**Its own to decide:**
- SmartyStreets request/response mapping, caching policy (if any), and timeout/retry behavior against the upstream provider

### policy-integration-api (U2)

**Inherits as fixed:**
- `XD-0001` — credentials/config server-side only, including the producer id
- `XD-0003` — the deep-link-URL-computed-server-side contract
- The one endpoint above

**Its own to decide:**
- How the producer id is resolved per brokerage/agency (replacing the legacy hard-coded literal, per FR-POL-3/DR-4)
- Upstream call timeout/retry and the exact `502` fallback behavior when the policy system is unavailable

## Open questions

| # | Question | Owner | Blocks |
|---|----------|-------|--------|
| 1 | The mechanism for the live read-only call to the policy-administration system (direct DB read, an API it exposes, or something else) is not yet named — intake Q2 confirmed "live call", not the transport. | @MithunAcx | U2's `design.md` and `interfaces/` |

## Change log

| Date | Change | Units whose `design.md` must follow |
|------|--------|-------------------------------------|
