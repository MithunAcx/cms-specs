---
capability: CAP-CMS-0004
title: Contact Activity & Follow-up Tracking
project: CMS
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-19
---

# Contact Activity & Follow-up Tracking — capability design

## Capability overview

**Capability:** CAP-CMS-0004 — Contact Activity & Follow-up Tracking
**Outcome measures this design serves:** M1
**Projected units:** 2

## Prospective units

| # | Prospective unit | Kind | Target repo | Owns | Serves |
|---|------------------|------|-------------|------|--------|
| U1 | activity-api | backend | CMS-contact-activity-tracking | Activity entity | M1 |
| U2 | activity-grid-ui | frontend | CMS-web | nothing persistent — a reusable component embedded in CAP-CMS-0003's Brokerage/Agency Detail screens | M1 (UX), FR-ACT-1..5 |

## Cross-unit decisions (XD log)

| # | Decision | Rationale | Affects | Cited by |
|---|----------|-----------|---------|----------|
| XD-0001 | `Activity` is one entity with a polymorphic `parentType` (`agency` \| `brokerage`) and `parentId`, not two separate tables | Mirrors the raw ask's own domain model (§6.5's single `Activity` resource) while keeping the parent reference explicit rather than the legacy's two nullable FK columns | U1, U2 | UNIT-CMS-0007, UNIT-CMS-0008 |
| XD-0002 | Delete is a **soft delete** — a `deletedAt` timestamp is set, the row is retained, and it is excluded from default list queries | Confirmed by intake Q6; distinguishes this capability's delete semantics from a physical `DELETE` | U1, U2 | UNIT-CMS-0007, UNIT-CMS-0008 |
| XD-0003 | `userName` on every activity record is server-derived from the authenticated request (via CAP-CMS-0001's token), never accepted from the client | Enforces AUTHZ-2/API-4 at the contract level, not left to each caller's discipline | U1 | UNIT-CMS-0007 |

## Shared database schema

No entity in this capability is touched by more than one *prospective* unit — U1 owns
the `Activity` entity; U2 is a pure API consumer with no server-side schema of its own.
`Activity`'s field design (per XD-0001's polymorphic shape) belongs in U1's own
`design.md`.

## Unified API contract

### Shared conventions

| Concern | Convention |
|---|---|
| Versioning | `/api/v1/...` |
| Auth header shape | `Authorization: Bearer <access token>`, validated per CAP-CMS-0001/XD-0002 |
| Pagination | Cursor-based only, per `10-platform.md`: `limit` + `cursor` in, `items` + `next_cursor` out. Default `limit` 25, maximum 100. No offset pagination anywhere |
| Error envelope | `{ code, message, details[], trace_id }` |
| Idempotency | `PUT` idempotent by resource id; `DELETE` (soft) idempotent — deleting an already-deleted entry is a no-op `204`, not a `404` |
| Rate limiting response | `429` with `Retry-After` |

### activity-api (U1) — endpoints

| Method | Path | Request | Response | Status / errors | Min role |
|--------|------|---------|----------|------------------|----------|
| GET | `/api/v1/activity?parentType=&parentId=&limit=&cursor=&completed=&sort=followUpDate` | — | `{ items: Activity[], next_cursor }` (excludes soft-deleted by default) | — | Viewer |
| POST | `/api/v1/activity` | `{ parentType, parentId, statusId, note, followUpDate }` | `Activity` with new id, server-derived `userName`, `enteredDate` | `400` | Editor |
| PUT | `/api/v1/activity/{id}` | `{ statusId, note, followUpDate, completed }` | updated `Activity`; `completedDate` server-set when `completed` flips true | `400`, `404` | Editor |
| DELETE | `/api/v1/activity/{id}` | — | `204` (soft delete — sets `deletedAt`) | `404` if never existed | Editor |

### activity-grid-ui (U2) — endpoints

None. U2 consumes the endpoints above; it is embedded as a component inside
CAP-CMS-0003's Brokerage Detail and Agency Detail screens.

## End-to-end flow diagrams

### Log and complete a follow-up, embedded in a Brokerage Detail screen

```
CAP-CMS-0003's Brokerage Detail screen
   └─ embeds U2 (activity-grid-ui)
         |  POST /activity { parentType: 'brokerage', parentId, ... }   → U1
         |  { id, userName (server-derived), enteredDate }              ← U1
         |  ... later, mark complete ...
         |  PUT /activity/{id} { completed: true }                      → U1
         |  { completedDate: <server timestamp> }                       ← U1
```

| Step | Unit | Touches |
|------|------|---------|
| Log a new activity entry from within the host screen | U2 → U1 | XD-0001 (parent reference), XD-0003 (server-derived `userName`) |
| Mark it complete | U2 → U1 | server-set `completedDate` |
| Any later listing of that brokerage's activity | CAP-CMS-0003's screen → U2 → U1 | XD-0001 |

## Build and sequencing order

| Order | Unit | Blocked by | Why |
|-------|------|------------|-----|
| 1 | U1 activity-api | — | Independent of CAP-CMS-0003's own schema — only needs `parentType`/`parentId` as opaque references |
| 2 | U2 activity-grid-ui | U1 designed | Written against U1's contract |
| — | CAP-CMS-0003's frontend unit | U2 exists | Embeds U2 as a component on its Detail screens (cross-capability integration, not a build-order dependency of this capability's own units) |

## Handoff notes to unit design

### activity-api (U1)

**Inherits as fixed:**
- `XD-0001` — the polymorphic parent-reference shape
- `XD-0002` — soft delete
- `XD-0003` — server-derived `userName`
- The four endpoints above

**Its own to decide:**
- Physical schema for `Activity`, its RLS policy, and index design for the follow-up/open-item sort (FR-ACT-5)

### activity-grid-ui (U2)

**Inherits as fixed:**
- `XD-0001` and `XD-0002`
- The four endpoints above

**Its own to decide:**
- Grid layout, inline add/edit UX, and how it is packaged for embedding into a host screen owned by another capability

## Open questions

| # | Question | Owner | Blocks |
|---|----------|-------|--------|

## Change log

| Date | Change | Units whose `design.md` must follow |
|------|--------|-------------------------------------|
| 2026-08-19 | Corrected shared conventions to match the platform floor: pagination changed from `page`/`size` (offset) to cursor-based `limit`+`cursor` in / `items`+`next_cursor` out (10-platform.md, "no offset pagination anywhere"); error envelope corrected from the stale `{ error: { code, message, fields? } }` to the platform-standard `{ code, message, details[], trace_id }`. Endpoint table for U1 updated to match. No ADR — this restores the already-mandatory platform floor rather than adopting a new convention. | UNIT-CMS-0007, UNIT-CMS-0008 |
