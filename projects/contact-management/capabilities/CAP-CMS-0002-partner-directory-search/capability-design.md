---
capability: CAP-CMS-0002
title: Partner Directory & Search
project: CMS
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Partner Directory & Search — capability design

## Capability overview

**Capability:** CAP-CMS-0002 — Partner Directory & Search
**Outcome measures this design serves:** M1
**Projected units:** 2

## Prospective units

| # | Prospective unit | Kind | Target repo | Owns | Serves |
|---|------------------|------|-------------|------|--------|
| U1 | partner-search-api | backend | CMS-partner-directory-search | nothing of its own — read-only queries against CAP-CMS-0003's brokerage/agency/CGA entities | M1 |
| U2 | partner-directory-ui | frontend | CMS-web | nothing persistent | M1 (UX), FR-SEARCH-1..8 |

## Cross-unit decisions (XD log)

| # | Decision | Rationale | Affects | Cited by |
|---|----------|-----------|---------|----------|
| XD-0001 | Six search modes are six distinct query parameters on one `GET /search` family, not six separate endpoints — `mode` selects which fields are matched, `term`/`state`/`uw` are shared parameters interpreted per mode | Keeps one contract instead of six near-identical ones (mirrors the raw ask's own framing of "one Directory screen, six modes"), and gives U2 one client to write against | U1, U2 | _pending units_ |
| XD-0002 | Search reads are **cross-capability, read-only** against CAP-CMS-0003's brokerage/agency/CGA data — U1 owns no data of its own and must never write to those entities | Prevents this capability from silently becoming a second writer of Partner Records' data, which would violate CAP-CMS-0003's own "exactly one owning unit per entity" rule at the project level | U1 | _pending units_ |

## Shared database schema

No entity in this capability is touched by more than one *prospective* unit, and U1
itself owns no entity — it queries CAP-CMS-0003's brokerage/agency/CGA/broker/agent
tables read-only (XD-0002). That cross-capability read path, and any read-optimized view
or index U1 needs on top of CAP-CMS-0003's schema, is U1's own design decision, made in
coordination with CAP-CMS-0003's `design.md` — not a capability-design-level shared
schema, since it is cross-*capability*, not cross-*unit-within-this-capability*.

## Unified API contract

### Shared conventions

| Concern | Convention |
|---|---|
| Versioning | `/api/v1/...` |
| Auth header shape | `Authorization: Bearer <access token>`, validated per CAP-CMS-0001/XD-0002 |
| Pagination | `page`/`size` query params; response includes total count and page metadata (FR-SEARCH-7, API-1) |
| Error envelope | `{ error: { code, message, fields? } }` |
| Idempotency | All endpoints here are `GET` — inherently idempotent |
| Rate limiting response | `429` with `Retry-After`, per API Gateway throttling |

### partner-search-api (U1) — endpoints

| Method | Path | Request | Response | Status / errors | Min role |
|--------|------|---------|----------|------------------|----------|
| GET | `/api/v1/search?mode=brokerage\|broker\|state-broker\|agency\|cga\|state-agent&term=&state=&uw=&page=&size=` | query params per XD-0001 | `{ items: [...], total, page, size }` — item shape depends on `mode`, per raw-ask Appendix A's result columns | `400` if `term` required for the mode and missing (FR-SEARCH-3) | Viewer |
| GET | `/api/v1/lookups/assigned-uws` | — | `[{ uw: string }]` — distinct underwriters currently assigned to ≥1 brokerage | — | Viewer |

### partner-directory-ui (U2) — endpoints

None. U2 consumes the endpoints above and launches CAP-CMS-0003's create flows
("Add New Agency"/"Add New Brokerage" — FR-SEARCH-6) by navigation, not by an API call
of its own.

## End-to-end flow diagrams

### Search and open a result

```
U2 (Directory screen)                    U1 (partner-search-api)
  |  select mode + term, submit           |
  |--------------------------------------->|
  |  GET /search?mode=brokerage&term=...   |
  |  { items, total }                      |
  |<----------------------------------------|
  |  render results                        |
  |  click a row → navigate to Brokerage Detail (CAP-CMS-0003's screen, by id from the result item)
```

| Step | Unit | Touches |
|------|------|---------|
| Run a search | U2 → U1 | XD-0001 (mode parameter contract) |
| Render results, including the UW filter | U2 | — |
| Open a result | U2 → CAP-CMS-0003's detail screen | cross-capability navigation, not an API call of this capability's |

## Build and sequencing order

| Order | Unit | Blocked by | Why |
|-------|------|------------|-----|
| 1 | U1 partner-search-api | CAP-CMS-0003's brokerage/agency/CGA schema exists (design-time dependency) | U1 has nothing to query until that schema is defined |
| 2 | U2 partner-directory-ui | U1 designed | U2 is written against U1's `/search` contract |

## Handoff notes to unit design

### partner-search-api (U1)

**Inherits as fixed:**
- `XD-0001` — the single `/search` endpoint family and its mode parameter
- `XD-0002` — read-only access to CAP-CMS-0003's entities; no write path
- The two endpoints above

**Its own to decide:**
- Internal query implementation per mode (which columns/indexes back each mode, matching Appendix A's backing-read-model notes)
- Result-set size/virtualization thresholds within the ~1s latency target (M1)

### partner-directory-ui (U2)

**Inherits as fixed:**
- `XD-0001` — the six modes as query-parameter variants of one endpoint
- The two endpoints above

**Its own to decide:**
- Segmented-control/mode-switcher UX, responsive table-vs-card layout (FR-SEARCH-8), empty-state copy

## Open questions

| # | Question | Owner | Blocks |
|---|----------|-------|--------|

## Change log

| Date | Change | Units whose `design.md` must follow |
|------|--------|-------------------------------------|
