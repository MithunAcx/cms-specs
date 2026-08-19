---
unit: UNIT-CMS-0001
updated: 2026-08-18
---

# Design — Identity Access API

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

A single stateless authentication/authorization/audit service standing in front of every
other unit in the project. It issues a short-lived access token and a longer-lived,
individually revocable refresh token per XD-0001; the access token carries `role` and
`tenantId` claims (XD-0002, R3, R22) so every other unit's backend validates a caller
locally, with no callback into this unit on the request path. It also owns the one audit
write path (XD-0003) every mutating endpoint across every capability calls synchronously.

Two decisions this unit was left to make (`capability-design.md` § Handoff notes) are
fixed here rather than deferred further, since a design with a placeholder TTL cannot
state a concrete latency or security NFR:

- **Access-token TTL: 15 minutes. Refresh-token TTL: 30 days**, rotated on every use
  (XD-0001, R4). Fifteen minutes bounds the blast radius of a leaked access token to a
  short window without forcing a re-login inside a normal working session (AUTH-4); thirty
  days matches "persists across a normal working day" with headroom for someone who does
  not touch the system daily, while still being revocable well inside that window via
  logout (R5) or reuse detection (below). This closes `requirements.md` Open question #1.
- **Password hashing: a memory-hard, salted hash function (e.g. the Argon2 family), with
  parameters tuned to the unit's own latency budget (R15) at its expected login rate
  (R16).** The exact algorithm and cost parameters are an engineering-repo configuration
  choice within this constraint, not a spec-level number. This closes `requirements.md`
  Open question #2 as far as a design commitment goes; the parameter tuning itself is a
  build-time task.

**Refresh-token reuse is treated as a signal, not merely a rejected call.** Because
XD-0001 makes the refresh token the sole revocation lever, a token presented a second
time after having already been rotated away (R4 behaviour detail) means one of two
things: a client bug (retried the same call twice) or a stolen, replayed token. This
design cannot distinguish the two from a single presentation, so it does the safe thing
observable at the boundary: reject with `401 invalid_refresh_token` (already required by
R4) and revoke every other still-active refresh token issued to that same user, forcing a
fresh login everywhere. The alternative considered — reject only the reused token and
leave the rest of that user's sessions alone — was rejected because it is silently unsafe
in the theft case, which is exactly the case reuse detection exists to catch; a client bug
that retries harmlessly pays the cost of one extra login, which is a fair trade against a
silent session-hijack window.

The alternative to the whole shape — validating every request against this unit
synchronously (a callback per call, rather than a locally-verifiable claim) — was
rejected because it would make every other unit's call latency additive with this unit's
own, and would make this unit a single point of failure for every request in the project
rather than only for login, refresh, and audit writes. XD-0002 already fixed this
project-wide; this design carries it through rather than reopening it.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Credential validator | Looks up the stored credential by username, verifies the presented password against the stored hash, without ever branching observably on which check failed | R1, R13, R25 |
| Identity resolver | Strips the domain prefix from the raw username, resolves the display name, and embeds both plus `role` and `tenantId` into the issued token pair | R2, R3, R22 |
| Token issuer | Mints the access token (short-lived JWT with claims) and the refresh token (opaque, individually revocable) as one pair; performs rotation on every valid refresh call | R1, R4, R18 |
| Refresh-token store | Holds one record per issued refresh token with its consumed/revoked state; the atomic consume-once operation R4/R19 depend on lives here | R4, R5, R19 |
| Reuse-detector | On a refresh call against an already-consumed token, rejects it and revokes every other active refresh token for that user | R4 (behaviour detail) |
| Role/claim resolver | Reads the caller's `RoleAssignment` and embeds it as the token's `role` claim; exposes the local-verification contract every other unit's backend imports | R3, XD-0002 |
| Audit writer | The single write path — `{ actor, timestamp, entityType, entityId, action, metadata }` — invoked synchronously by this unit's own mutating endpoints and by every other capability's backend unit | R9, R10, R23 |
| Audit reader | Serves `GET /audit-log`, filtered by `entityType`/`entityId`, scoped to the caller's tenant, restricted to Administrator | R8, R22 |
| Password changer | Verifies the current password, then replaces the stored hash; does not touch the caller's existing token pair | R7 |

## Flows

### Login — satisfies R1, R2, R3, R11, R12, R13, R22

1. Caller sends `POST /api/v1/auth/login` with `{ username, password }`.
2. Credential validator strips any domain prefix, looks up the credential by the
   stripped username within the tenant the credential belongs to, and verifies the
   password against the stored hash.
3. Identity resolver resolves the display name and role, and the token issuer mints an
   access token (embedding `username`, `displayName`, `role`, `tenantId`) and a refresh
   token, both tied to a new refresh-token-store record.
4. Response returns `{ accessToken, refreshToken, expiresIn }`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 1 — malformed body (missing `username` or `password`) | `400 invalid_request`, no lookup attempted |
| 2 — unknown username, or known username with wrong password | `401 invalid_credentials` — identical shape for both, so the response never discloses which part was wrong |
| 2 — credential belongs to a tenant, lookup itself uses parameterized access only | no dynamic SQL from `username`/`password` at any point (R13) |

### Token refresh — satisfies R4, R18, R19

1. Caller sends `POST /api/v1/auth/refresh` with `{ refreshToken }`.
2. Refresh-token store atomically checks the token is present, unexpired, and
   **not already consumed**, and — in the same atomic step — marks it consumed and
   creates its successor record. This is the storage-level enforcement R19 requires;
   a read-then-mark sequence here would let two concurrent callers both succeed.
3. Token issuer mints a new access/refresh pair from the successor record.
4. Response returns the new `{ accessToken, refreshToken, expiresIn }`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — token not found, expired, or previously revoked (logout) | `401 invalid_refresh_token` |
| 2 — token was already consumed by an earlier, successful refresh (reuse) | `401 invalid_refresh_token`, **and** the reuse-detector revokes every other active refresh-token record for that user, per Approach |
| 2 — two concurrent callers present the same still-valid token | exactly one wins the atomic consume-once step (R19); the other is treated identically to "already consumed" above |

### Logout — satisfies R5

1. Caller sends `POST /api/v1/auth/logout` with `{ refreshToken }`.
2. Refresh-token store marks the token (and, if still valid, its whole chain-successor
   state) revoked.
3. Response returns `204`, whether or not the token was already revoked or expired
   (R5 behaviour detail — idempotent).

Failure paths:

| Step fails | Behaviour |
|---|---|
| 1 — unauthenticated (no valid access token on the call) | `401` |
| 2 — token unknown, already revoked, or already expired | still `204` — logout's postcondition ("this token no longer works") already holds |

### Get current session — satisfies R6

1. Caller sends `GET /api/v1/auth/me` with a bearer access token.
2. Identity resolver reads `username`, `displayName`, `role` directly from the
   validated token's own claims — no datastore lookup, no request parameter consulted.
3. Response returns `{ username, displayName, role }`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 1 — missing/invalid/expired access token | `401` |

### Change password — satisfies R7

1. Caller sends `POST /api/v1/auth/change-password` with `{ oldPassword, newPassword }`
   and a valid access token.
2. Password changer verifies `oldPassword` against the stored hash for the caller
   resolved from the token (never from a request field).
3. `newPassword` is validated against the password-strength policy; if it passes, the
   stored hash is replaced.
4. Response returns `204`. The caller's current access/refresh token pair is left
   untouched (Approach — minimal scope; see `requirements.md` Assumptions).

Failure paths:

| Step fails | Behaviour |
|---|---|
| 1 — unauthenticated | `401` |
| 2 — `oldPassword` does not match | `401 invalid_credentials` |
| 3 — `newPassword` fails the strength policy | `400 weak_password` |

### Audit-log write (invoked by this unit and by every other unit) — satisfies R9, R10, R23

1. A mutating operation (in this unit or any other) completes its own business write.
2. It calls the audit writer synchronously with `{ actor, entityType, entityId, action,
   metadata }`; `actor` is resolved server-side from the caller's own validated token,
   never accepted as a field (R10). `timestamp` is server-assigned at write time.
3. Audit writer appends one immutable entry.
4. The calling operation's own response is only returned once the audit write has
   completed (or definitively failed — see below).

Failure paths:

| Step fails | Behaviour |
|---|---|
| 3 — the audit write fails after the business write already committed | the calling operation's overall result is treated as failed and reported to its own caller as a `5xx`, even though its business data change already landed; this is the accepted trade-off for R9's "every mutating operation produces a matching audit-log entry" — an audit-less mutation is a worse outcome than a mutation the caller is told to retry (retrying is safe because the underlying operation states its own idempotency behaviour independently) |
| 3 — the write is attempted twice for the same logical mutation (upstream retry) | permitted — two audit entries for two attempts is correct; audit is a record of what was attempted and its outcome, not deduplicated against the business operation's own idempotency key |

### Read audit log — satisfies R8, R22

1. Caller (Administrator) sends `GET /api/v1/audit-log?entityType=&entityId=&limit=&cursor=`.
2. Audit reader restricts the result set to the caller's own tenant (row-level security,
   R22) and to the given filters, returning a cursor page.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 1 — caller role below Administrator | `403` |
| 1 — unauthenticated | `401` |

## Data model

Entities, keys, relationships, ownership, retention. The machine-readable form
lives in `interfaces/*.sql` and `interfaces/*.schema.json`.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| User/Credential | unique per tenant + stripped username | password hash, display name, tenant id | Personal fields severed on erasure request; row survives (R26) |
| RefreshToken | unique token identifier | consumed/revoked state, issued-from predecessor reference (for chain revocation), expiry | Standard policy; expired/revoked records are eligible for periodic purge — not a retention obligation in the regulatory sense, since the token itself is not the record of what happened |
| RoleAssignment | one per user | role value (`viewer`/`editor`/`administrator`) | Standard policy |
| AuditLogEntry | append-only, insert-order key | actor, timestamp, entityType, entityId, action, metadata, tenant id | Standard policy (no bespoke period); immutable after write — see Cross-cutting → errors/validation for how that immutability is enforced |

## Contracts

What this unit exposes and consumes. Each row must correspond to a file in
`interfaces/`.

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Auth and audit API | sync HTTP | `interfaces/openapi.yaml` | R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12 |
| Identity/RBAC/audit schema | storage | `interfaces/*.sql` | R22, R23, R26 |

Also documented in `interfaces/openapi.yaml`'s security scheme description, not as its
own file: the local-verification contract (XD-0002) — the token's public signature
material and claim shape every other unit's backend needs to validate a bearer token
without calling this unit. It has no independent path or method, matching the pattern
`capability-design.md` already used for this same fact.

## State and idempotency

**RefreshToken state machine.** States: `active` (issued, not yet consumed) →
`consumed` (used to mint a successor, terminal for this record — R4) or `revoked`
(logout, or swept by reuse-detection — R5, R4 behaviour detail) or `expired` (TTL
elapsed, never consumed — R4). `consumed`, `revoked`, and `expired` are all terminal;
there is no transition back to `active`. **Invariant:** at most one successor token is
ever minted from a given refresh-token record, enforced by the atomic consume-once
operation (R19) rather than by an application-level "check then write" — a datastore
construct that makes the consume-and-create-successor step a single atomic operation on
that record, so two callers racing on the same token can never both see it `active`.

**Idempotency walk.**

| Path | Effect performed once, how |
|---|---|
| First `POST /auth/login` attempt | Issues a fresh token pair every time by design (R18) — login is not itself idempotent in the sense of returning the same tokens twice, and does not need to be; each call is an independent new session. |
| Client retries `POST /auth/login` after a timeout with no response seen | A second, independent token pair is issued; both are valid until one is used. No dedupe key needed — this is the accepted behaviour, not a gap (R18). |
| `POST /auth/refresh` called once, succeeds | The one refresh-token record consumed becomes `consumed`; exactly one successor pair exists. |
| `POST /auth/refresh` retried by the client after a timeout, having actually succeeded server-side | The retry presents the now-`consumed` token; rejected per the reuse path — the client must use the successor pair from the original response, which is why the response is the only place the successor is revealed. This is a deliberate boundary: a lost response after a successful rotation requires a fresh login (or use of the still-active previous-generation token if the client cached it, which it will not have since rotation replaced it) — flagged as a Risk below. |
| Two concurrent `POST /auth/refresh` calls, same token, both genuinely in flight | Exactly one succeeds (the atomic consume-once step); the other observes `consumed` and is rejected (R19). |
| `POST /auth/logout` called once | Token moves `active`/`consumed` → `revoked` (or is already terminal). |
| `POST /auth/logout` retried (client retry, double-click) | No-op past the first call — the token is already terminal, response is still `204` (R5). The key here is the refresh token itself, a value fixed before execution and never regenerated by the retry. |
| Audit write retried by an upstream caller's own retry logic | A second, independent entry is written — correct, since each represents a real attempt (see Flows → audit-log write failure paths). |

**Concurrency matrix.**

| Two things at once | Who wins / what holds |
|---|---|
| Two refresh calls, same refresh token | Exactly one consumes it; storage-level atomic operation, not application logic (R19) |
| A refresh call and a logout call, same token, racing | Whichever the store serializes first wins; the other sees a terminal (`consumed` or `revoked`) token and is rejected — no half-applied state is observable either way |
| Two change-password calls for the same user, racing | Whichever is applied second overwrites the first's hash; both may have validated against the pre-change hash, so the last write wins on the stored value — a benign outcome since it is the same user acting on their own credential, not a cross-actor conflict |
| A mutating call and an audit-log read, same tenant | The read may or may not observe the just-written entry depending on transaction visibility timing; no requirement demands read-your-writes across independent HTTP calls, so this is acceptable and not treated as a defect |

**Answers that can change.** This unit issues tokens and writes audit entries; it does
not consume any upstream answer about the past that could later be revised (unlike
`UNIT-CMS-0010`'s upstream policy read). Not applicable.

## Cross-cutting

| Concern | Decision |
|---|---|
| authn/authz | Bearer access-token JWT, `role` and `tenantId` claims validated locally by every other unit (XD-0002); this unit's own endpoints each declare their own minimum role per R11 — `/audit-log` requires Administrator, every other authenticated endpoint requires Viewer-or-above; `/login` and `/refresh` require no prior authentication |
| validation | Request body/query shape validated before any datastore lookup or credential check (R1 behaviour detail); `parentType`-style closed enums used wherever a field has a fixed value set (e.g. `role`) |
| errors | Shared envelope `{ error: { code, message, details, trace_id } }`; `401 invalid_credentials`/`invalid_refresh_token` never discloses which half of a check failed (R1, R4); audit-log immutability is enforced by the storage contract permitting only `INSERT`, never `UPDATE`/`DELETE`, against the audit table — a developer who reimplements this as "don't call the update method" loses the guarantee, so it must be a store-level constraint |
| observability | Metrics: login success/failure count, refresh count, reuse-rejection count, audit-write latency (R24). Logs: caller id, tenant id, endpoint, outcome code — never a password, raw token value, or refresh-token value (R24, R25). The audit write is its own trace span, since every other unit's mutating call now depends on it synchronously (R9, R24) |
| performance | p95 ≤ 500 ms / p99 ≤ 1500 ms inclusive of cold start (R15); password-hash cost parameters are tuned to stay inside this budget at the stated peak throughput (R16) rather than chosen for hashing strength alone |
| migration/backfill | `RoleAssignment` seeded once from legacy `SV_UserRights` by `UNIT-CMS-0011`'s ETL, mapped per AUTHZ-3, unused legacy rights dropped (R27) — a one-time task, not a runtime path of this unit |
| feature flag | N/A — no flagged rollout planned; this unit is a hard day-one dependency for the whole project (R28) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| A client's `POST /auth/refresh` response is lost after the server-side rotation already succeeded | The client is left holding a now-consumed token and cannot recover without a fresh login | Accepted rather than engineered around: a mid-air-lost-response window is rare, and the alternative (a grace window where a just-rotated token still works once more) directly weakens R19's reuse-detection guarantee. Flagged here rather than solved, since a grace window is a security/availability trade-off for the BA to decide if it proves to matter in practice. |
| Reuse-detection revokes every active session for a user on a single reused-token event, including a benign client-retry double-fire | A legitimate user is logged out everywhere by their own client's bug, not an attacker | Accepted per Approach's stated trade-off — a false-positive full logout is cheaper than a false-negative missed session hijack. Observability (R24) records reuse-rejection events so a spike traceable to one client bug (rather than many distinct users) is visible operationally. |
| Password-hash cost parameters tuned for R15's latency budget may be weaker than a security review would independently choose | Slightly reduced resistance to offline cracking if a hash dump were ever exfiltrated | Tuning is bounded below by a documented minimum-strength floor at build time (an engineering-repo task, not a spec-level number here); revisit if the peak-throughput assumption (R16) changes |
| Legacy `SV_UserRights` mapping (R27, AUTHZ-3) may not have a clean 1:1 mapping for every legacy right | Some staff could end up under- or over-privileged immediately after cutover | `UNIT-CMS-0011`'s migration validation should spot-check a sample of migrated role assignments against legacy behaviour, matching the same pattern `UNIT-CMS-0010`'s design used for its own migration risk |

## Decisions

Anything consequential gets an ADR in `decisions/`. List them here.

| ADR | Decision |
|---|---|
| — | None recorded. The TTL and password-hashing choices above are fixed inline in this design rather than as ADRs, because `capability-design.md` already named them as this unit's own tuning parameters within a fixed shape (XD-0001), not as contested alternatives with a real chance of reversal debate. The refresh-token reuse-detection behaviour was considered for an ADR (it is a real design choice with a rejected alternative) but is recorded here in Approach instead, since it fits entirely within this unit's own boundary and does not bind any other unit's contract the way `UNIT-CMS-0010`'s producer-id resolution did. |

## Requirement coverage

Every R-ID in `requirements.md` must appear here.

| R-ID | Covered by |
|------|-----------|
| R1 | Flow: Login; Credential validator; Token issuer |
| R2 | Flow: Login; Identity resolver |
| R3 | Flow: Login; Role/claim resolver; Contracts (security scheme) |
| R4 | Flow: Token refresh; Refresh-token store; State and idempotency (state machine, idempotency walk) |
| R5 | Flow: Logout; State and idempotency (idempotency walk) |
| R6 | Flow: Get current session |
| R7 | Flow: Change password; Password changer |
| R8 | Flow: Read audit log; Audit reader |
| R9 | Flow: Audit-log write; Audit writer; Failure paths |
| R10 | Flow: Audit-log write, step 2; Audit writer |
| R11 | Cross-cutting → authn/authz |
| R12 | Cross-cutting → authn/authz; Flow failure paths across Login/Refresh/Logout/Me/Change-password/Audit-log |
| R13 | Flow: Login, failure paths; Approach |
| R14 | Cross-cutting → performance (no external dependency, platform default) |
| R15 | Cross-cutting → performance |
| R16 | Cross-cutting → performance (password-hash tuning) |
| R17 | Cross-cutting → errors (gateway-level, not unit-designed) |
| R18 | State and idempotency (idempotency walk) |
| R19 | Flow: Token refresh; State and idempotency (state machine invariant, concurrency matrix) |
| R20 | Cross-cutting → errors (gateway-level) |
| R21 | Cross-cutting → authn/authz |
| R22 | Flow: Login (tenant-scoped lookup); Flow: Read audit log; Data model |
| R23 | Flow: Audit-log write; Data model; Cross-cutting → errors (immutability enforcement) |
| R24 | Cross-cutting → observability |
| R25 | Cross-cutting → observability; Data model |
| R26 | Data model (User/Credential retention) |
| R27 | Cross-cutting → migration/backfill; Risks |
| R28 | Cross-cutting → feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
