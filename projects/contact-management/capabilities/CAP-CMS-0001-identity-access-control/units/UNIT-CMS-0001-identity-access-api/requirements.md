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
| R1 | `POST /api/v1/auth/login` authenticates a `{ username, password }` pair against locally stored, hashed credentials and, on success, returns `{ accessToken, refreshToken, expiresIn }`. | AUTH-1, AUTH-2, FR-AUTH-1, CAP-CMS-0001/A2 | P0 |
| R2 | On successful login, the system resolves the username with any domain prefix stripped and the display name (first + last), and both are embedded in the session's token claims so every caller of `GET /api/v1/auth/me` and every audit-log write sees the same stripped identity. | AUTH-3, FR-AUTH-2 | P0 |
| R3 | The access token is a JWT carrying a `role` claim of exactly one of `viewer`, `editor`, `administrator`, verifiable locally by any other unit's backend without a call back to this unit. | XD-0002, CAP-CMS-0001/M1, AUTHZ-1 | P0 |
| R4 | `POST /api/v1/auth/refresh` exchanges a valid, unexpired, unrevoked refresh token for a new access/refresh token pair; the presented refresh token is invalidated in the same operation (rotation), per XD-0001. | AUTH-4, XD-0001 | P0 |
| R5 | `POST /api/v1/auth/logout` invalidates the presented refresh token; any subsequent use of that same token is rejected. | AUTH-4, XD-0001 | P0 |
| R6 | `GET /api/v1/auth/me` returns the caller's own `{ username, displayName, role }`, resolved from the caller's own access token — never from a request parameter. | AUTH-3, AUTHZ-1 | P1 |
| R7 | `POST /api/v1/auth/change-password` lets an authenticated caller change their own password by presenting their current password and a new one; this endpoint is unconditionally available, since every credential in this build is local (no SSO). | FR-AUTH-5 | P0 |
| R8 | `GET /api/v1/audit-log` returns audit-log entries filtered by `entityType` and `entityId`, restricted to the Administrator role. | AUTHZ-4, CAP-CMS-0001/M3, A3 | P0 |
| R9 | This unit exposes the audit-log write path — `{ actor, timestamp, entityType, entityId, action, metadata }` (XD-0003) — that every mutating endpoint in every capability of this project invokes; the write path is the sole owner of persisting an audit-log entry. | AUTHZ-4, NFR-AUD-1, CAP-CMS-0001/M3, A3 | P0 |
| R10 | The `actor` field of every audit-log entry is always the username resolved server-side from the caller's own validated token; no caller may supply `actor`, `timestamp`, or an entity's role through any request field. | AUTHZ-2, API-4 | P0 |
| R11 | Every endpoint in this unit declares its own minimum role, and a request from a caller below that role is rejected with `403` regardless of what a client UI would have allowed. | AUTHZ-1, M1, A1 | P0 |
| R12 | An unauthenticated request to any endpoint in this unit other than `/auth/login` and `/auth/refresh` is rejected with `401`. | AUTH-1, A2 | P0 |
| R13 | Every data-access path in the login/authentication flow — credential lookup, token issuance, token validation — uses parameterized queries or an ORM; no SQL is built by concatenating request input. | G1, M2 | P0 |

## Behaviour detail

**R1 — login failure shape.** A login attempt with an unknown username and one with a
known username but wrong password return the identical `401 invalid_credentials` shape,
so the response never discloses which part was wrong (no username enumeration).

**R1, R13 — credential storage.** Passwords are never stored or compared in clear text;
the stored form is a salted hash. The hashing algorithm and its parameters are this
unit's own to decide (per `capability-design.md` § Handoff notes) and are recorded once
chosen — an open question below until then.

**R4 — refresh-token reuse.** A refresh token that has already been rotated away (i.e.
presented a second time after `R4` already consumed it) is rejected with
`401 invalid_refresh_token`; it never issues a second token pair from the same
already-consumed token. This is the repetition-class case for the rotation flow: a
client retry, a duplicate tab, or a stolen-and-replayed token must not extend a session
that has already moved on to its next token.

**R4 vs R5 — expiry vs revocation.** An expired refresh token and a revoked (logged-out
or already-rotated) refresh token return the same `401 invalid_refresh_token` shape to
the caller — the distinction is not observable externally, only in the audit trail.

**R5 — logout idempotency.** Calling `/auth/logout` a second time with a token that was
already invalidated by the first call still returns `204` — the caller's goal ("this
token no longer works") is already satisfied, so a repeat call is not an error.

**R7 — change-password does not itself rotate sessions.** A successful password change
does not automatically invalidate the caller's own current access/refresh token pair;
other active sessions for the same user are unaffected. This is a deliberate minimal
scope — see Assumptions.

**R8 — audit-log pagination.** Follows the platform-wide cursor convention
(`10-platform.md` Pagination): `limit`/`cursor` in, `items`/`next_cursor` out; default
limit 25, maximum 100.

**R9 — audit write path durability.** The audit-log write is performed synchronously,
within the same operation as the mutation it records, so a mutation that succeeds but
whose audit entry fails to persist is itself treated as a failed operation — see
`design.md` for the exact ordering. This closes the partial-failure class for "the
business write succeeded but the audit entry never landed."

**R11 — role check is per-endpoint, not per-unit.** Each of this unit's own endpoints
states its minimum role in the table above; `GET /audit-log` requires Administrator,
every other authenticated endpoint requires Viewer-or-above. This requirement does not
claim to enforce role checks on any other unit's endpoints — that is each of those
units' own R-ID, validated against the shared `role` claim contract this unit issues
(XD-0002).

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R14 | availability | Platform default; this unit has no external dependency of its own (self-issued JWT, no external IdP per `stack.md`), so its availability is not bounded by anything outside this project's own compute and datastore. |
| R15 | latency | p95 ≤ 500 ms, p99 ≤ 1500 ms for every synchronous operation, inclusive of serverless cold start (per `stack.md`'s cold-start consequence). ASSUMPTION: no measured baseline exists yet; ceiling chosen to keep login/refresh from being a perceptible delay on top of every other unit's own call. |
| R16 | throughput | Peak figure: ≤50 requests/second across all endpoints in this unit, derived from intake Q8's "<50 concurrent staff" figure (one login/refresh/me call per active staff member is the dominant traffic shape). ASSUMPTION, not a measured figure — label per `30-nfr-floor.md` and revisit if traffic proves otherwise. |
| R17 | surge | At 2× peak (~100 rps), API Gateway throttling (`stack.md`) sheds excess requests with `429` + `Retry-After`. `/auth/login` and `/auth/refresh` are never exempted from shedding — an authentication surge is exactly the case rate limiting exists to protect against. |
| R18 | idempotency | `POST /auth/login` — no key; a duplicate call with the same credentials issues a fresh, independent token pair (R1). `POST /auth/refresh` is explicitly **not** idempotent — it rotates the token on every valid call (R4); a duplicate call with the same (now-consumed) token is rejected (R4 behaviour detail), not silently repeated. `POST /auth/logout` is idempotent by construction (R5 behaviour detail) — the key is the presented refresh token itself, a value fixed before execution. `POST /auth/change-password` — no key; a duplicate call after the first succeeds is evaluated against the new password and fails naturally. |
| R19 | concurrency | Two concurrent `POST /auth/refresh` calls presenting the same refresh token: exactly one succeeds and rotates the token; the other observes the token as already-consumed and receives `401 invalid_refresh_token` (R4 behaviour detail) — enforced by a storage-level atomic consume-once operation on the refresh-token record, not by application-level check-then-act, since a read-then-write here would let both calls succeed. |
| R20 | rate limits | Per caller and per endpoint, enforced by API Gateway throttling (`stack.md`); response is `429` with `Retry-After`, matching the shared error envelope. `/auth/login` additionally has no legitimate reason for high per-caller frequency, so its throttle threshold is set tighter than this unit's other endpoints — exact figure is this unit's own operational tuning, not a spec-level number. |
| R21 | authorization | Minimum role per endpoint is stated in the Requirements table (R11). Ownership rule: every endpoint in this unit is called with the caller's own user-session token; no service-credential caller is defined for this unit today (see Assumptions). |
| R22 | tenant isolation | Every `User`/`Credential`, `RefreshToken`, and `RoleAssignment` record is scoped by `tenant_id`; the access token additionally carries a `tenantId` claim so every other unit's backend can enforce isolation locally without a callback, the same mechanism XD-0002 defines for `role`. `GET /audit-log` returns only entries whose `tenant_id` matches the caller's own token — enforced by the row-level security policy on the audit-log table (`stack.md`), never by an application-level filter alone. |
| R23 | audit | `AuditLogEntry` records `{ actor, timestamp, entityType, entityId, action, metadata }` (XD-0003) for every create/update/delete across every capability, including this unit's own mutating endpoints (login is a read of credentials, not itself audited; change-password, logout, and role changes are). Immutability is enforced by the storage contract permitting no `UPDATE` or `DELETE` statement against the audit-log table — only `INSERT` — so a correction is a new entry, never an edited one. Retention follows standard company policy (`stack.md` / capability Constraints — no bespoke period). |
| R24 | observability | Metrics: login success/failure count, token-refresh count, refresh-reuse-rejection count, audit-log write latency. Structured log fields: caller id (once authenticated), tenant id, endpoint, outcome code. Passwords, raw tokens, and refresh-token values never appear in a log line (R25). Trace span boundary: the audit-log write is its own span, since R9 makes it a synchronous dependency of every mutating call across the project. |
| R25 | data classification | `username`, `displayName` — personal data, not special category. `passwordHash` — never logged, never returned in any response body. `accessToken`/`refreshToken` values — never logged in full; only a token identifier (e.g. its `jti`) may appear in an audit or diagnostic record. `AuditLogEntry.metadata` must never carry special-category data — the shared write path (R9) is documented for every consuming unit as never accepting a special-category field in that column. |
| R26 | retention and deletion | Session/token and audit-log retention follow standard company policy (no bespoke period per capability Constraints). Erasure path: on a subject-erasure request, the `User` record's personal fields (`username`, `displayName`) are severed while the row and its `RoleAssignment`/`AuditLogEntry` references survive — audit entries are financial/regulatory-adjacent records that must remain immutable and attributable to *an* actor even after that actor's personal fields are severed, per `20-compliance.md`'s retention-versus-erasure tension. The severed placeholder value and the exact erasure trigger are this unit's own to design — flagged as an open question below. |
| R27 | migration and backfill | Legacy `SV_UserRights` rows map to this unit's RBAC roles per AUTHZ-3; unused legacy rights are dropped, not carried forward. This is a one-time backfill task for `UNIT-CMS-0011` (Legacy Data ETL), not a runtime behaviour of this unit — recorded here only as a Data note; see Dependencies. |
| R28 | feature flag | N/A — no flagged rollout is planned for this unit; it is a hard dependency every other unit needs from day one, per the capability's Build and sequencing order. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| User/Credential | Owned | Username (domain-stripped), display name, password hash, tenant id. Personal data (R25). |
| RefreshToken | Owned | One record per issued refresh token; carries revoked/consumed state for R4/R5/R19's atomic consume-once behaviour. |
| RoleAssignment | Owned | One role (`viewer`/`editor`/`administrator`) per user; source of the `role` claim (R3, XD-0002). |
| AuditLogEntry | Owned | `{ actor, timestamp, entityType, entityId, action, metadata }` (XD-0003); append-only (R23). Written both by this unit's own mutating endpoints and, via the shared write path, by every other capability's backend unit. |
| Legacy `SV_UserRights` | Read (migration-time only) | Read once during `UNIT-CMS-0011`'s ETL to seed `RoleAssignment`; not read at runtime by this unit (R27). |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0011 (Legacy Data ETL) | data | Backfills `RoleAssignment` from legacy `SV_UserRights` per AUTHZ-3/R27; this unit's RBAC is meaningless for existing staff until that backfill runs. |
| Every other capability's backend unit | contract (downstream) | Every one of them validates the `role` claim locally (XD-0002) and calls this unit's shared audit-log write path (XD-0003) on every mutating operation — documented here as the platform-wide contract this unit is upstream of. |

## Assumptions

- Password-hashing algorithm and parameters are not yet chosen (capability-design.md § Handoff notes leaves this to this unit); `design.md` will name one, recorded as an open question below until then.
- Access-token and refresh-token TTL values are not yet set (capability-design.md Open question #1); R15's latency budget and R19's concurrency window do not depend on the exact TTL figure, so this unit proceeds without it and the open question is carried forward rather than duplicated.
- No lockout/throttle-after-N-failed-attempts requirement is specified by the raw ask; only the platform-wide rate limit (R17, R20) applies to repeated login attempts. If brute-force lockout is wanted, it is a new requirement, not implied by anything already asked.
- A password change does not invalidate the caller's other active sessions (behaviour detail under R7) — minimal scope per the raw ask, which does not request session-wide invalidation on password change.
- No service-credential (machine-to-machine) caller is defined for this unit today (R21); only user-session callers are in scope, matching AUTH-5's "front end holds no long-term secrets" framing rather than a service-to-service token flow.
- "Tenant" for this capability means the CMS-operating organization boundary consistent with every other unit's row-level-security model (`stack.md`); the raw ask does not distinguish multiple tenants explicitly, but `10-platform.md`'s tenancy rule applies uniformly across the project, so R22 is stated to match rather than assumed absent.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
| 1 | Exact access-token and refresh-token TTL values (capability-design.md Open question #1 restated here since it is this unit's own to close). | `design.md`'s latency/security NFR framing (informational only — does not block drafting) | @MithunAcx | open — non-blocking |
| 2 | Password-hashing algorithm and parameter choice. | `design.md`, `interfaces/openapi.yaml` (informational only) | @MithunAcx | open — non-blocking, `design.md` will name a specific algorithm |
| 3 | Exact erasure-path mechanics for a severed `User` record (R26) — what placeholder value replaces `username`/`displayName`, and what triggers severance. | `design.md`'s data-model section | @MithunAcx | open — non-blocking, `design.md` proceeds on a stated placeholder convention, revisited on first real erasure request |
