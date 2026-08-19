---
unit: UNIT-CMS-0002
updated: 2026-08-18
---

# Design — Identity Access UI

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

This unit is a thin session/guard layer that every other frontend unit sits inside.
It holds no server of its own and no persistent data; its entire responsibility is:
obtain a token pair from UNIT-CMS-0001, hold it for the life of the browser tab,
attach it to outgoing requests, transparently refresh it exactly once when it is
rejected, and gate which routes and controls the current session may reach.

Two decisions anchor the design, both because `requirements.md` and the capability
design's Handoff notes left them explicitly open here:

**Token storage — in-memory, not persistent browser storage.** The access and
refresh tokens are held only in memory for the lifetime of the tab; nothing is
written to a persistent client-side store. Rejected alternative: persistent
storage (so a reload does not force a fresh login). Persistent storage was rejected
because it is readable by any script running in the page's origin, which turns
NFR-SEC-4's XSS protection into the *only* thing standing between an injected script
and both tokens; an in-memory-only credential is unreachable by anything that runs
after the page has already unloaded, and a reload correctly requiring a fresh
sign-in is consistent with AUTH-5 ("the front end holds no long-term secrets") read
literally. The cost — a page reload always re-prompts for sign-in — is treated as an
acceptable, explicit trade against the security property. This is a contested,
consequential, hard-to-reverse call (switching later invalidates the XSS threat
model this design's cross-cutting section relies on) and is recorded as ADR-0001.

**Refresh coalescing via a single in-flight refresh reference.** Every module that
makes an authenticated call shares one refresh state: the first `401` starts a
refresh and every other caller observes and awaits that same in-flight refresh
rather than starting its own (R9). This is the only way to avoid the rotation race
described in `requirements.md`'s Behaviour detail for R8/R9 — since
`POST /auth/refresh` rotates the refresh token, a second concurrent call would
present an already-superseded token and fail, incorrectly ending a session that was
still good.

Rejected alternative: let every caller refresh independently and treat a `401` on
refresh as "session over". Rejected because it makes the failure rate of a session
non-zero any time two or more requests happen to expire together — which, at a UI
that fires several calls on route change, is common rather than rare.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Session holder | Holds the in-memory token pair and the resolved identity (username, display name, role) for the tab's lifetime; the single source every other component reads | R3, R18, R22 |
| Route guard | Inspects the session holder before rendering a route; redirects to sign-in when no valid session exists | R1 |
| Sign-in form | Collects credentials, calls the login contract, populates the session holder on success, navigates to the originally requested route or the default landing route | R2 |
| Sign-out control | Calls the logout contract, clears the session holder unconditionally, navigates to sign-in | R6 |
| Change-password form | Collects old/new password, calls the change-password contract, surfaces the result | R7 |
| Authenticated-call wrapper | Attaches the current access token to every outgoing call to any capability's API; on `401`, drives the shared refresh-and-retry sequence | R8, R9, R10, R15, R16, R17 |
| Refresh coordinator | The single shared in-flight-refresh reference every caller of the authenticated-call wrapper observes | R9, R15, R16 |
| Role-gate | Given the session holder's role, decides whether a control renders enabled, disabled, or hidden, against the role table in `requirements.md`'s Behaviour detail | R4, R5 |
| Diagnostic emitter | Emits the non-sensitive failure event described in R21 on a failed login, refresh, or logout | R21 |

## Flows

### Sign-in — satisfies R2, R3

1. User submits username and password on the sign-in form.
2. The submit control disables immediately (prevents a duplicate concurrent
   submission — repetition class).
3. The unit calls `POST /auth/login` with the entered credentials.
4. On `200`, the session holder is populated with the returned access token and
   refresh token, and with the identity (username, display name, role) taken from
   the login response or a follow-up `GET /auth/me` call — never computed locally.
5. The unit navigates to the route the user originally requested (the one the
   route guard redirected from), or the default landing route if none was
   recorded.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 3 returns `401` | One generic credential-rejected message shown; username field retained, password field cleared; submit control re-enabled |
| Step 3 returns any other error status, times out, or the network is unavailable | A distinct retry-eligible error shown; username field retained, password field cleared; submit control re-enabled |
| Step 4's token write to memory fails (should not normally occur for in-memory storage, but covers a hostile or corrupted execution context) | Treated identically to a login failure: nothing partially populated is left in the session holder, the retry-eligible error is shown |

### Silent refresh with coalescing — satisfies R8, R9, R10

1. The authenticated-call wrapper makes a call carrying the current access token.
2. The call returns `401`.
3. The wrapper checks the refresh coordinator for an in-flight refresh.
   - If none exists, it starts one: call `POST /auth/refresh` with the current
     refresh token, and register this as the in-flight refresh so any other
     caller reaching step 3 while it is pending observes it instead of starting
     its own.
   - If one exists, it awaits that shared refresh instead of calling
     `/auth/refresh` itself.
4. When the shared refresh resolves:
   - **Success** (`200`, new access + refresh token pair): the session holder is
     updated with the new pair; every caller waiting on the refresh — including
     the one that triggered it — retries its original request exactly once with
     the new access token.
   - **Failure** (`401` — refresh token invalid, expired, or revoked): the session
     holder is cleared entirely; every caller waiting on the refresh abandons its
     retry and the unit navigates to sign-in.
5. A request retried in step 4 that itself returns `401` again is **not** fed back
   into another refresh (bounds the retry to exactly one per originally-failed
   request, per R8's retry ceiling) — it is surfaced to the caller as a failure.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Refresh call (step 3) times out or the network is unavailable | Treated as a dependency-did-not-answer case, distinct from a `401` (dependency-answered-no): the in-flight refresh is abandoned, waiting callers surface a retry-eligible error, and the session holder is **not** cleared — a future call may still succeed since the existing tokens were never confirmed invalid |
| Refresh succeeds but a waiting caller's retried request itself fails for an unrelated reason (e.g. `5xx`) | That caller surfaces its own error; it does not affect the session holder or any other waiting caller |

### Logout — satisfies R6

1. User selects sign-out.
2. The unit calls `POST /auth/logout` with the current refresh token.
3. Regardless of that call's outcome (success, failure, timeout, or network
   unavailable), the session holder is cleared immediately.
4. The unit navigates to sign-in.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 fails, times out, or is unreachable | No effect on steps 3–4 — the client-side session still ends deterministically, by design (see Behaviour detail in `requirements.md`); the server-side refresh-token record may remain valid until its own expiry, which is an accepted, stated limitation, not a defect |

### Change password — satisfies R7

1. Authenticated user (any role) opens the change-password form and submits old
   and new password.
2. The unit calls `POST /auth/change-password`.
3. On `204`, a confirmation is shown; the session is left signed in and unchanged.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Step 2 returns `401` (bad old password) | Field-level error against the old-password field; session unaffected |
| Step 2 returns `400` (weak new password) | Field-level validation error against the new-password field; session unaffected |
| Step 2 times out or the network is unavailable | Retry-eligible error; form values retained except both password fields, which are cleared |

### Route-guard and role-gated rendering — satisfies R1, R4, R5

1. Before rendering any route other than sign-in, the route guard reads the
   session holder.
2. No valid session (never signed in, or cleared by logout/refresh-failure) →
   redirect to sign-in, recording the originally requested route so Sign-in flow
   step 5 can return to it.
3. Valid session → route renders; every control on it consults the role-gate
   against the session holder's role to decide hidden/disabled/enabled, per the
   role table in `requirements.md`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| Session holder holds a role the role-gate does not recognise (e.g. a future role value this unit was not updated for) | Fail closed — treat as the lowest-privilege (Viewer) rendering, never fail open to a broader one |

## Data model

This unit owns no persistent entity — see `requirements.md` § Data. The only
state is the in-memory session record, scoped to the browser tab and never
serialized to any store.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| In-memory session record | tab lifetime (no persistent key) | access token, refresh token, username, display name, role | Cleared on logout (flow above), on refresh failure, or when the tab/process ends — never written to any persistent client-side store (ADR-0001) |

## Contracts

This unit exposes no contract of its own — `capability-design.md`'s Unified API
contract lists no endpoint under identity-access-ui. It consumes UNIT-CMS-0001's
five endpoints as a closed contract. Per `shared-spec-conventions`, a consumer-only
unit carries a **copy** of the producer's contract file, never an original:

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| UNIT-CMS-0001's auth API (login, refresh, logout, me, change-password) | sync HTTP, consumed | `interfaces/UNIT-CMS-0001.openapi.yaml` (copy of UNIT-CMS-0001's own `interfaces/openapi.yaml`, the five endpoints this unit calls) | R2, R3, R6, R7, R8, R9, R10 |

## State and idempotency

**State machine.** The session holder has three states:

- `signed-out` — no tokens held. Initial state, and the state reached after
  logout or a failed refresh.
- `signed-in` — a token pair is held and has not (yet) been rejected.
- `refreshing` — a `401` has been observed and a refresh is in flight; this is
  the state that exists *because* the refresh is asynchronous and other callers
  must be able to observe it rather than each independently discovering the
  expired token.

Transitions: `signed-out → signed-in` (successful login); `signed-in →
refreshing` (a `401` observed and no refresh yet in flight); `refreshing →
signed-in` (refresh succeeded, new pair stored); `refreshing → signed-out`
(refresh rejected); `signed-in → signed-out` (logout, at any time). `refreshing`
is not re-entered from itself — a second `401` observed while already
`refreshing` does not start a second refresh; it joins the existing one (this is
the invariant).

**Invariant:** at most one refresh call is in flight for the tab at any time. This
is enforced by the refresh coordinator being the single shared reference every
caller consults before calling `/auth/refresh` itself — not by convention, since
the entire reason this component exists is that two independently-written callers
cannot be trusted to check a convention under real concurrency.

**Idempotency walk** for the retry in the silent-refresh flow (the one operation
in this unit with a repeat-effect hazard):

| Path that could refresh | Collapses to one call because |
|---|---|
| First `401` observed by the caller that happens to fire first | Registers itself as the in-flight refresh before calling `/auth/refresh` |
| A second caller's `401` arriving microseconds later, same tab | Observes the already-registered in-flight refresh and awaits it instead of calling `/auth/refresh` |
| A caller's own retry (post-refresh) itself getting `401` again | Explicitly excluded from re-triggering refresh (R8's retry ceiling) — surfaced as a failure instead |
| Two browser tabs each holding their own copy | Each tab has its own, independent in-flight-refresh reference — this is not a shared key across tabs, and is not claimed to be (see `requirements.md`'s stated multi-tab limitation) |

There is no idempotency key derived from request content here, because the
operation being protected against duplication is "call `/auth/refresh` more than
once concurrently for the same tab" — the coordination is by shared in-memory
reference (a value fixed the instant the first `401` is observed, before any
network call happens), not by a key attached to the request.

## Concurrency matrix

| Scenario | Who wins / what happens | Enforcement |
|---|---|---|
| Two authenticated calls in the same tab both receive `401` near-simultaneously | Exactly one refresh call is made; both retry with its result | Application-level, via the single shared refresh-coordinator reference (no storage layer is involved — this unit has none) |
| A refresh succeeds while a third caller is mid-flight on the *old* access token (not yet failed) | That third caller is unaffected until/unless it also receives `401`; it does not get force-cancelled | No enforcement needed — old and new access tokens are not required to be mutually exclusive by XD-0001's contract shape |
| Logout is triggered in one tab while a refresh is in flight in that same tab | Logout clears the session holder immediately (flow above); the in-flight refresh, if it later resolves, still writes into a session holder that logout already cleared — the write is stale and must be discarded rather than resurrecting a signed-in state | Application-level: the refresh completion handler checks the session holder is still in `refreshing` state (not `signed-out`) before writing the new pair; a state check immediately before a write is a read-then-write, but the two only ever run on the tab's single execution thread, so no interleaving can occur between the check and the write here |
| Two browser tabs, one logs out, the other keeps using its own token pair | The other tab is unaffected until its own next `401` → refresh → `401` sequence (stated limitation, `requirements.md`) | None — deliberately out of scope; no cross-tab mechanism was requested |

## Cross-cutting

| Concern | Decision |
|---|---|
| tenant isolation | This unit holds no tenant-scoped data and makes no tenant-scoping decision; every call it makes carries only the access token, and the tenant is resolved server-side from that token by the API units it calls (R19) |
| authn/authz | This unit performs no authentication or authorization decision of its own. It calls UNIT-CMS-0001's endpoints for authentication, and its role-gate is a rendering convenience, never an enforcement point (R4, R5, R18) |
| validation | Client-side validation on the login and change-password forms (required fields, minimum password shape) is a UX convenience only; the server's `400`/`401` response is authoritative and always re-checked, never assumed satisfied by passing client-side validation |
| errors | Every failure path above maps to one of: a field-level error (change-password), a generic credential-rejected message (login `401`, to avoid enumeration), or a retry-eligible error (anything from the dependency-did-not-answer class) — no other error shape is introduced by this unit |
| observability | The diagnostic emitter (R21) fires on a failed login, refresh, or logout, carrying endpoint, HTTP status, and correlation ID (`trace_id` if present) — never username, password, or token value |
| performance | The route guard's decision (R1) is a synchronous check against in-memory state with no network call; login/refresh/logout latency is inherited from UNIT-CMS-0001's own NFRs and this unit adds no material processing time |
| migration/backfill | None — greenfield unit, no prior client state exists (R24) |
| feature flag | None requested; not designed for here (R25) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| In-memory-only token storage means any full page reload forces a fresh sign-in | User-visible friction; could tempt a future engineer to "fix" it by moving to persistent storage without revisiting the XSS threat model this design relies on | Recorded as ADR-0001, with the reversal condition stated explicitly, so the trade is visible rather than silently reverted |
| Refresh coordination is a shared in-memory reference | If UNIT-CMS-0002 is ever built as more than one independent execution context sharing no memory (e.g. a service worker plus a page, or multiple frames), the "single in-flight refresh" invariant would need a cross-context mechanism this design does not provide | Accepted for the current single-page scope this unit's requirements describe; flagged for the engineering repo to raise a change request if such a split execution context is ever introduced |
| Stale role after a mid-session role change by an administrator | A user could act (in the UI, though never server-side) on a role that has since been revoked, until their token naturally refreshes or expires | Accepted per `requirements.md`'s stated limitation; the server remains the actual enforcement point (R5), so the worst case is a UI showing a control the server will still reject |
| Multi-tab desynchronization after a logout in one tab | A second tab can appear signed-in for up to one more failed-call cycle after the user believed they signed out everywhere | Accepted per `requirements.md`'s stated limitation; no requirement asked for cross-tab synchronization |

## Decisions

| ADR | Decision |
|---|---|
| ADR-0001 | In-memory-only token storage over persistent browser storage |

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Flows § Route-guard and role-gated rendering |
| R2 | Flows § Sign-in |
| R3 | Flows § Sign-in; Data model |
| R4 | Flows § Route-guard and role-gated rendering; Cross-cutting (authn/authz) |
| R5 | Cross-cutting (authn/authz); Flows § Route-guard and role-gated rendering |
| R6 | Flows § Logout |
| R7 | Flows § Change password |
| R8 | Flows § Silent refresh with coalescing; State and idempotency (idempotency walk) |
| R9 | Flows § Silent refresh with coalescing; State and idempotency (state machine, invariant); Concurrency matrix |
| R10 | Flows § Silent refresh with coalescing |
| R11 | Cross-cutting (performance) |
| R12 | Cross-cutting (performance) |
| R13 | Approach (no batch/bulk operation in this unit's scope — Components table shows no such component) |
| R14 | Approach (see R13) |
| R15 | State and idempotency (idempotency walk) |
| R16 | Concurrency matrix |
| R17 | Cross-cutting (errors) |
| R18 | Cross-cutting (authn/authz) |
| R19 | Cross-cutting (tenant isolation) |
| R20 | Cross-cutting (observability); Data model (no audit write path in this unit) |
| R21 | Cross-cutting (observability) |
| R22 | Data model; Cross-cutting (errors) |
| R23 | Data model (retention column) |
| R24 | Cross-cutting (migration/backfill) |
| R25 | Cross-cutting (feature flag) |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
