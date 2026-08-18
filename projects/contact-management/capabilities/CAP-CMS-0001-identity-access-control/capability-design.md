---
capability: CAP-CMS-0001
title: Identity & Access Control
project: CMS
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Identity & Access Control — capability design

## Capability overview

**Capability:** CAP-CMS-0001 — Identity & Access Control
**Outcome measures this design serves:** M1, M2, M3
**Projected units:** 2

## Prospective units

| # | Prospective unit | Kind | Target repo | Owns | Serves |
|---|------------------|------|-------------|------|--------|
| U1 | identity-access-api | backend | CMS-identity-access-control | User/Credential, RefreshToken, RoleAssignment, AuditLogEntry | M1, M2, M3 |
| U2 | identity-access-ui | frontend | CMS-web | nothing persistent — client-held tokens only | M1 (role-aware UI), AUTH-1/4/5 UX |

## Cross-unit decisions (XD log)

| # | Decision | Rationale | Affects | Cited by |
|---|----------|-----------|---------|----------|
| XD-0001 | Token contract: short-lived JWT access token + a separate opaque, server-side-revocable refresh token; revocation = invalidating the refresh token record | Satisfies AUTH-4 ("expire and can be revoked") against a purely stateless JWT's inability to be revoked before expiry (intake Q4) | U1, U2 | _pending units_ |
| XD-0002 | RBAC role-claim contract: the access token JWT carries a single `role` claim (`viewer` \| `editor` \| `administrator`); every other capability's backend unit validates it locally via shared middleware, never by calling back to U1 per request | Keeps authorization enforcement server-side (AUTHZ-1) without making every request a round-trip to the identity service; matches AUTH-5's "stateless with respect to business data" | U1, and every backend unit in every other capability (documented here as the platform-wide contract this capability is upstream of, per `capability.md` § Dependencies) | _pending units_ |
| XD-0003 | Audit-log entry shape: `{ actor, timestamp, entityType, entityId, action, metadata }`, written via a shared logging call every mutating endpoint in every capability invokes | Gives M3's "100% of mutating operations produce a matching audit-log entry" one canonical shape instead of each capability inventing its own | U1 (owns the store + write path), and every mutating endpoint in every other capability | _pending units_ |

## Shared database schema

No entity in this capability is touched by more than one *prospective* unit — U1 owns
every persistent identity/RBAC/audit entity; U2 is a pure API consumer with no
server-side schema of its own (client-held tokens are not a database entity). U1's own
entities (User/Credential, RefreshToken, RoleAssignment, AuditLogEntry) are therefore its
own to design in full, in its own `design.md`.

**Constraints that carry a requirement:** every table U1 owns needs its own row-level
security policy (per `stack.md`'s tenant-isolation choice), authored alongside its
migration — this is a capability-wide obligation restated here because U1 is the only
unit with a schema to apply it to.

## Unified API contract

### Shared conventions

| Concern | Convention |
|---|---|
| Versioning | `/api/v1/...` |
| Auth header shape | `Authorization: Bearer <access token>` |
| Pagination | `page`/`size` query params; response includes total count and page metadata |
| Error envelope | `{ error: { code, message, fields? } }` — `400` field-keyed validation, `401` unauthenticated, `403` insufficient role, `404` not found, `409` conflict |
| Idempotency | `PUT` idempotent by resource id; `POST /auth/refresh` is explicitly **not** idempotent — it rotates the refresh token each call |
| Rate limiting response | `429` with a `Retry-After` header, per API Gateway throttling (`stack.md`) |

### identity-access-api (U1) — endpoints

| Method | Path | Request | Response | Status / errors | Min role |
|--------|------|---------|----------|------------------|----------|
| POST | `/api/v1/auth/login` | `{ username, password }` | `{ accessToken, refreshToken, expiresIn }` | `401` bad credentials | none (unauthenticated) |
| POST | `/api/v1/auth/refresh` | `{ refreshToken }` | `{ accessToken, refreshToken, expiresIn }` (rotated) | `401` invalid/revoked refresh token | none — the refresh token itself is the credential |
| POST | `/api/v1/auth/logout` | `{ refreshToken }` | `204` | `401` unauthenticated | Viewer |
| GET | `/api/v1/auth/me` | — | `{ username, displayName, role }` | `401` unauthenticated | Viewer |
| POST | `/api/v1/auth/change-password` | `{ oldPassword, newPassword }` | `204` | `401` bad old password, `400` weak new password | Viewer (self-service; local credentials only, per FR-AUTH-5/intake Q3 — every user of this build is local-credentials, so this endpoint is unconditionally reachable, not merely "where local credentials are in use") |
| GET | `/api/v1/audit-log?entityType=&entityId=&page=&size=` | — | `{ items: [...], total, page, size }` | `403` below Administrator | Administrator |

Also exposed, **not as a public HTTP endpoint**: an in-process token-verification
function/middleware every other capability's backend unit imports to validate a bearer
token and extract its `role` claim locally (XD-0002). This is documented in § Handoff
notes for every downstream capability rather than listed as a row here, since it has no
independent path or method of its own.

### identity-access-ui (U2) — endpoints

None. U2 consumes every endpoint above; it produces no endpoints of its own.

## End-to-end flow diagrams

### Sign-in and first authenticated request

```
U2 (login form)                U1 (identity-access-api)         Any other capability's backend unit
      |  POST /auth/login              |                                    |
      |-------------------------------->|                                    |
      |  { accessToken, refreshToken } |                                    |
      |<--------------------------------|                                    |
      |  stores both tokens             |                                    |
      |  GET /search/... (Bearer <accessToken>)                              |
      |--------------------------------------------------------------------->|
      |                                 |     validates JWT locally (XD-0002)|
      |  200 result                                                          |
      |<----------------------------------------------------------------------|
```

| Step | Unit | Touches |
|------|------|---------|
| Login submit | U2 | — |
| Issue tokens | U1 | XD-0001 (token contract) |
| Store tokens client-side | U2 | XD-0001 |
| Call another capability's API with the bearer token | U2 → downstream unit | XD-0002 (role-claim contract) |
| Validate token locally, no call back to U1 | downstream unit | XD-0002 |

### Access-token expiry and silent refresh

```
U2                                     U1
 |  API call → 401 (token expired)      |
 |-------------------------------------->
 |  POST /auth/refresh { refreshToken } |
 |-------------------------------------->
 |  { accessToken, refreshToken } (new) |
 |<---------------------------------------
 |  retries original call with new token|
```

| Step | Unit | Touches |
|------|------|---------|
| Detect `401` from an expired access token | U2 | XD-0001 |
| Exchange the refresh token for a new pair | U1 | XD-0001 |
| Retry the original request | U2 | — |

### Logout and revocation

```
U2                                     U1
 |  POST /auth/logout { refreshToken }  |
 |-------------------------------------->
 |  204                                  |  invalidates the refresh-token record
 |<---------------------------------------
 |  (later) POST /auth/refresh with the same token → 401
```

| Step | Unit | Touches |
|------|------|---------|
| Request logout | U2 | XD-0001 |
| Invalidate the refresh token record | U1 | XD-0001 |
| Any later use of that refresh token fails | U1 | XD-0001 |

## Build and sequencing order

| Order | Unit | Blocked by | Why |
|-------|------|------------|-----|
| 1 | U1 identity-access-api | — | Nothing in this capability, or any other, can authenticate without it |
| 2 | U2 identity-access-ui | U1 designed | U2's login/session flow is written against U1's endpoint shapes |
| 3 | (cross-capability) every other capability's backend unit | U1 designed | Every mutating/protected endpoint elsewhere validates tokens per XD-0002 and writes audit entries per XD-0003 |

## Handoff notes to unit design

### identity-access-api (U1)

**Inherits as fixed:**
- `XD-0001` — the access-token/refresh-token contract and revocation model
- `XD-0002` — the `role` claim shape every other unit will read
- `XD-0003` — the audit-log entry shape
- The six endpoints listed above, as a closed contract

**Its own to decide:**
- Password hashing algorithm and parameters
- Refresh-token storage mechanism (hashed token record, JTI blocklist, or equivalent)
- Exact access-token TTL and refresh-token TTL values, within the "short-lived access + longer-lived, revocable refresh" shape XD-0001 fixes
- Internal audit-log write path (synchronous vs. queued)

### identity-access-ui (U2)

**Inherits as fixed:**
- `XD-0001` — must store and refresh tokens exactly per that contract
- The five consumer-facing endpoint shapes under U1

**Its own to decide:**
- Client-side token storage mechanism (memory vs. browser storage) and its own XSS/CSRF posture within `stack.md`'s NFR-SEC-4 requirements
- Login form UX, validation copy, and routing/guard implementation

## Open questions

| # | Question | Owner | Blocks |
|---|----------|-------|--------|
| 1 | Exact access-token and refresh-token TTL values are not yet set — XD-0001 fixes the shape (short-lived + revocable refresh) but not the numbers. | @MithunAcx | U1's `design.md` — needs a concrete value before it can state its own latency/security NFRs |

## Change log

| Date | Change | Units whose `design.md` must follow |
|------|--------|-------------------------------------|
