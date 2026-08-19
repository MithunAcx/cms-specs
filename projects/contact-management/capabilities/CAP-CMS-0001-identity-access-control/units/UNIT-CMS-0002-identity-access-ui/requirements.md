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
| R1 | An unauthenticated request for any route other than sign-in is redirected to the sign-in screen before any protected content renders. | CAP-CMS-0001/A2, AUTH-1 | Must |
| R2 | The sign-in screen accepts a username and password and submits them to `POST /auth/login`; on `200` it stores the returned access token and refresh token client-side and navigates to the route originally requested, or a default landing route if none was requested. | CAP-CMS-0001/A2, AUTH-1, AUTH-3 | Must |
| R3 | On successful sign-in, the display name and role returned by `GET /auth/me` (or the login response, whichever the design selects) are held for the session and are what the UI reads to decide what to show — never a client-computed or client-supplied value. | AUTH-3, CAP-CMS-0001/M1 | Must |
| R4 | For every role (`viewer`, `editor`, `administrator`), a control whose action requires a higher role than the current session holds is hidden or disabled, per the role table in `capability.md`'s original ask. | CAP-CMS-0001/M1, AUTHZ-1 | Must |
| R5 | Hiding or disabling a control per R4 is a UI-only convenience; this unit makes no claim that it substitutes for server-side enforcement, and no requirement in this unit may be read as satisfying AUTHZ-1 on its own. | CAP-CMS-0001/A1 | Must |
| R6 | Selecting sign-out calls `POST /auth/logout` with the current refresh token, clears all client-held token state regardless of the call's outcome, and navigates to the sign-in screen. | AUTH-4, AUTH-5 | Must |
| R7 | The change-password form is reachable to any authenticated session (Viewer and above), submits `{ oldPassword, newPassword }` to `POST /auth/change-password`, and on `204` shows a confirmation and leaves the session signed in. | FR-AUTH-5 | Must |
| R8 | When an API call made with the current access token is rejected `401` for reasons other than a login attempt, the unit calls `POST /auth/refresh` once with the stored refresh token, and — if that succeeds — retries the original request exactly once with the new access token before surfacing any error to the user. | AUTH-4, XD-0001 | Must |
| R9 | Concurrent `401`s arriving from more than one in-flight request within the same session coalesce into a single `POST /auth/refresh` call; every waiting request retries with the one resulting access token rather than each triggering its own refresh call. | XD-0001 | Must |
| R10 | If `POST /auth/refresh` itself returns `401` (refresh token invalid, expired, or revoked), the unit clears all client-held token state and redirects to sign-in; no further request is attempted with the stale tokens. | AUTH-4, XD-0001 | Must |

## Behaviour detail

**R2 — login failure cases.** A `401` from `/auth/login` shows one generic
credential-rejected message; the response never distinguishes "unknown username" from
"wrong password" (avoids username enumeration via the UI). A network failure or a
non-`401`/`200` status (e.g. `5xx`, `429`, timeout) shows a distinct
retry-eligible error and leaves the form's entered username intact but never the
password. The submit control is disabled from first submission until a response (or a
client-side timeout) arrives, so a duplicate click cannot fire two concurrent login
calls for the same form state (repetition class).

**R3 — role source.** The unit never infers role from anything other than what the
API returns for the current session (`GET /auth/me` or the login response). It holds
no local mapping from username to role and performs no client-side role computation.

**R4 — role table.** Per `capability.md`'s original ask:

| Role | Controls visible |
|---|---|
| Viewer | search, view-only detail screens |
| Editor | Viewer's, plus create/edit/delete controls on brokerages, agencies, brokers, agents, CGAs, accounting addresses, contact activity, flags/statuses |
| Administrator | Editor's, plus reference-lookup maintenance entry points and user role-assignment entry points |

This unit renders the show/hide state; the screens themselves belong to their own
frontend units, which read the same session role.

**R6 — logout resilience (dependency class).** If `POST /auth/logout` times out, is
rate-limited, or the network is unavailable, the client still clears its own token
state and navigates to sign-in — a failed server-side call to invalidate the refresh
token does not leave the user stuck in an apparently-signed-in browser tab. This is a
deliberate asymmetry: server-side revocation may lag, but the client's own session
must end deterministically on the user's action.

**R8/R9 — refresh coalescing and ordering.** Refresh-token rotation (XD-0001: each
`/auth/refresh` call rotates the refresh token) means two concurrent, uncoalesced
refresh calls would race — the second to arrive at UNIT-CMS-0001 would find its
refresh token already rotated out from under it and receive `401`, incorrectly ending
a session that was in fact still valid. R9 exists specifically to prevent that
ordering hazard; it is not a performance optimization.

**R8 — retry ceiling.** Exactly one retry per originally-failed request. A second
`401` after the retried call (i.e., the newly-issued access token is itself rejected)
is treated as R10 — refresh/session failure — not as a reason to refresh again. This
bounds retry storms against a misbehaving or compromised token.

**R10 — clock skew (time class).** The unit does not decide token expiry from a
locally computed clock; it acts only on what the server's `401` tells it. This avoids
a client/server clock-skew false-positive or false-negative on expiry.

**Multi-tab state (concurrency class).** Each browser tab holds its own copy of the
token pair independently; this unit makes no cross-tab synchronization guarantee. A
tab that had a stale refresh token invalidated by a sign-out in another tab discovers
this on its own next `401` → refresh → `401` sequence (R10), not immediately. This is
a stated limitation, not a defect: a stronger guarantee (immediate cross-tab
invalidation) would require a mechanism (e.g. a shared-storage event) that no
requirement above asked for and that is out of scope unless requested.

**Stale role after a mid-session role change (state class).** If an administrator
changes a signed-in user's role, that user's already-issued access token keeps the
old role claim until it next expires and is refreshed (R8) or the user signs in
again. This unit does not poll for role changes. Recorded as a stated limitation
consistent with AUTH-5 (API is stateless with respect to business data; the front end
does not maintain a live subscription to its own authorization state).

**Storage failure (partial-failure class).** If the browser rejects writing the
returned tokens to client-side storage (e.g. storage disabled or quota exceeded), the
sign-in is treated as failed — the user is shown the same retry-eligible error as a
network failure (R2), and no partial token state is left in place; if one token wrote
and the other did not, the successfully written one is explicitly cleared before the
error is surfaced.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R11 | availability | This unit has no server-side component of its own to be unavailable; it is available whenever the static assets are served and degrades to a hard failure state (R2's retry-eligible error) whenever UNIT-CMS-0001 is unavailable. No independent SLO is meaningful beyond the hosting platform's own. |
| R12 | latency | Route-guard redirect (R1) completes with no perceptible network round trip — it is a local decision against already-held session state. The login round trip's latency is UNIT-CMS-0001's NFR to state; this unit adds no processing latency of its own beyond rendering the response. |
| R13 | throughput | N/A — this unit issues requests at human interaction rate (one login, one refresh-on-401, one logout per session lifecycle event); it has no batch or bulk operation and generates no load concern of its own. |
| R14 | surge | N/A — see R13; a traffic surge is a concern for UNIT-CMS-0001 and the API Gateway throttling layer, not for this client. |
| R15 | idempotency | `POST /auth/refresh` is coalesced (R9) precisely because it is **not** idempotent (it rotates the refresh token, per capability-design's Unified API contract); every other call this unit makes (login, logout, change-password) is fired at most once per user action per R2's/R6's submit-disable behaviour. |
| R16 | concurrency | Two simultaneous `401`s within one tab must observe exactly one refresh call and one resulting token pair (R9); two browser tabs are independent per the stated multi-tab limitation above and must never corrupt each other's in-memory state, since each tab owns its own copy. |
| R17 | rate limits | This unit does not itself rate-limit; a `429` from any endpoint (API Gateway throttling, per `stack.md`) is surfaced to the user as a retry-eligible error honouring the `Retry-After` header rather than an immediate silent retry. |
| R18 | authorization | This unit holds no authorization decision of its own — R4/R5 explicitly state its show/hide behaviour is not an enforcement point. The only "ownership" rule is that a browser tab's session belongs to whichever user last completed R2 in that tab; there is no service-credential path in this unit. |
| R19 | tenant isolation | This unit is not tenant-scoped by itself — it holds no data of its own to isolate. Every tenant-scoped read or write happens in the API units it calls, which enforce isolation server-side per `10-platform.md`. This unit must never accept or transmit a client-supplied tenant identifier — the session's tenant is whatever the server derives from the token. |
| R20 | audit | This unit produces no audit-log entries itself (UNIT-CMS-0001 owns the write path per XD-0003); it must not attempt to write one, and must not log special-category or credential data (passwords, tokens) to any client-side console, error report, or analytics event. |
| R21 | observability | On a failed login, refresh, or logout, the unit emits a client-side diagnostic event carrying the endpoint, the HTTP status, and a correlation ID (if the response carried a `trace_id`) — never the username, password, or token value. |
| R22 | data classification | Username is personal data; password and both tokens are credential material. Password is never stored beyond the single submission; the access and refresh tokens are held only in the client-side storage mechanism `design.md` selects, never logged, never included in an error report, and never sent anywhere other than `Authorization` headers to endpoints under this contract. |
| R23 | retention and deletion | Client-held tokens are cleared on sign-out (R6), on refresh failure (R10), and are held for no longer than the browser session/storage mechanism `design.md` selects. There is no server-side retention question for this unit — session and audit retention are UNIT-CMS-0001's rows. |
| R24 | migration and backfill | N/A — greenfield unit; no prior client state exists to migrate. |
| R25 | feature flag | N/A — no feature flag was requested for this unit's rollout; if one is added later it is scoped by a change request, not assumed here. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Session token pair (access token, refresh token) | Held, not owned | Client-side only, for the lifetime of the tab/session; the token records themselves are owned and issued by UNIT-CMS-0001 |
| Session identity (username, display name, role) | Read | Read from `GET /auth/me`/the login response for the duration of the session; never computed or cached beyond that session |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth endpoints (XD-0001) must exist before this unit can be designed against them: `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`, `POST /auth/change-password` |

## Assumptions

- The client-side token storage mechanism (in-memory vs. browser storage, and its XSS/CSRF posture within `stack.md`'s NFR-SEC-4) is `design.md`'s decision, per capability-design's Handoff notes — not fixed here as a requirement.
- A default landing route exists for a successful login with no originally-requested route; its exact identity is a design/UX decision, not a requirement of this unit.
- Access/refresh token TTL values (capability-design open question #1, owned by UNIT-CMS-0001) do not block this unit's requirements, because every requirement above reacts to a `401` response rather than to a locally-computed expiry time.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
