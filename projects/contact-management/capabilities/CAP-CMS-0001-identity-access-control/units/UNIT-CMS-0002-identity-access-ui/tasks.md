---
unit: UNIT-CMS-0002
change: original
---

# Tasks — Identity Access UI

## Contracts and generated code

- [ ] Generate client types and call stubs for the five consumed operations from `interfaces/UNIT-CMS-0001.openapi.yaml` (`authLogin`, `authRefresh`, `authLogout`, `authGetCurrentUser`, `authChangePassword`) — satisfies R2, R3, R6, R7, R8, R9, R10
- [ ] Wire the generated client's bearer-auth scheme to read the access token from the session holder (design.md § Components — Session holder) on every call — satisfies R18
- [ ] Re-generate the client from `interfaces/UNIT-CMS-0001.openapi.yaml` once it is re-copied from UNIT-CMS-0001's own authoritative contract (currently a provisional derivation — see that file's header) — no R-ID of its own; a prerequisite check, not a behaviour

## Data

None — this unit owns no persistent server-side entity (`requirements.md` § Data; `design.md` § Data model). No migration or backfill task applies.

## Implementation

- [ ] Implement the session holder holding the in-memory token pair and resolved identity (username, display name, role), scoped to the tab's lifetime, per ADR-0001 — satisfies R3, R22, R23
- [ ] Implement the sign-in flow: submit-disable on first click, call `authLogin`, populate the session holder from the response, navigate to the originally-requested route or the default landing route — satisfies R2
- [ ] Implement the route guard that reads the session holder before rendering any route other than sign-in and redirects to sign-in when no valid session exists, recording the originally-requested route — satisfies R1
- [ ] Implement the role-gate that renders a control hidden, visible-disabled, or enabled against the role table in `requirements.md`'s Behaviour detail, given the session holder's role, failing closed on an unrecognized role value — satisfies R4, R5
- [ ] Implement the sign-out control: call `authLogout`, clear the session holder unconditionally regardless of that call's outcome, navigate to sign-in — satisfies R6
- [ ] Implement the change-password form: call `authChangePassword`, show inline confirmation on success while remaining signed in — satisfies R7
- [ ] Implement the refresh coordinator as the single shared in-flight-refresh reference for the tab, per design.md § State and idempotency's invariant — satisfies R9, R16
- [ ] Implement the authenticated-call wrapper: on `401`, join an in-flight refresh via the refresh coordinator or start one if none exists; on refresh success, retry the original request exactly once with the new access token; on refresh failure, clear the session holder and navigate to sign-in — satisfies R8, R10
- [ ] Enforce the retry ceiling: a request retried after a successful refresh that itself returns `401` again does not trigger a further refresh — satisfies R8
- [ ] Implement the stale-write guard on refresh completion: before writing a resolved refresh's new token pair into the session holder, confirm the session holder is still in the refreshing state (not cleared by a concurrent logout) — satisfies R9, per design.md § Concurrency matrix (logout-during-refresh row)
- [ ] Implement the diagnostic emitter firing on a failed login, refresh, or logout with endpoint, HTTP status, and correlation ID (`trace_id` when present) and never username, password, or token value — satisfies R21

## Validation and errors

- [ ] Sign-in: on `401` from `authLogin`, show the one generic credential-rejected message, retain the username field, clear and refocus the password field — satisfies R2
- [ ] Sign-in: on any other error status, timeout, or network unavailability from `authLogin`, show the distinct retry-eligible error, retain username, clear password — satisfies R2
- [ ] Sign-in: if the token write to the session holder fails after a successful `authLogin`, discard any partially-written token and show the retry-eligible error — satisfies R2
- [ ] Refresh: on a `401` from `authRefresh`, clear the session holder entirely and abandon every waiting caller's retry — satisfies R10
- [ ] Refresh: on a timeout or network-unavailable response from `authRefresh` (dependency-did-not-answer), abandon the in-flight refresh without clearing the session holder, and surface a retry-eligible error to each waiting caller — satisfies R8, per design.md's dependency-did-not-answer vs. dependency-answered-no distinction
- [ ] Logout: on any `authLogout` failure, timeout, or network unavailability, still clear the session holder and navigate to sign-in — satisfies R6
- [ ] Change-password: on `401` from `authChangePassword`, show a field-level error under the old-password field, clear and refocus it, retain the new-password value — satisfies R7
- [ ] Change-password: on `400` from `authChangePassword`, show a field-level error under the new-password field, clear and refocus it, retain the old-password value — satisfies R7
- [ ] Change-password: on timeout or network unavailability, show a form-level retry-eligible error and clear both password fields — satisfies R7
- [ ] Rate limiting: on a `429` from any consumed operation, surface a retry-eligible error honouring the response's `Retry-After` value rather than an immediate silent retry — satisfies R17

## Cross-cutting

- [ ] Confirm no tenant identifier is ever accepted from or transmitted by this unit; every call carries only the access token and lets the server derive tenant scope — satisfies R19
- [ ] Confirm no client-side log, error report, or diagnostic event ever includes a password, access token, or refresh token value — satisfies R20, R22
- [ ] Confirm client-side form validation is advisory only and never substitutes for the server's `400`/`401` response — satisfies design.md § Cross-cutting (validation row); no independent R-ID beyond R2, R7 already covered above

No task for migration/backfill (R24) or feature flag (R25) — both rows are explicitly N/A in `requirements.md` (greenfield unit; no flag requested).

## Observability

- [ ] Confirm the diagnostic emitter (Implementation section) is the only client-side telemetry this unit produces, and that it carries no personal or credential data — satisfies R20, R21

## Tests

- [ ] Unit tests for the route guard: valid session renders the route; no session redirects and records the originally-requested route — satisfies R1
- [ ] Unit tests for sign-in: success path, credential-rejected path, retry-eligible path, submit-disable-preventing-duplicate-submission — satisfies R2
- [ ] Unit tests for the role-gate against every role in the table (Viewer, Editor, Administrator) and the fail-closed case for an unrecognized role — satisfies R4, R5
- [ ] Unit tests for sign-out: session cleared and navigation happens regardless of the logout call's simulated outcome (success, failure, timeout) — satisfies R6
- [ ] Unit tests for change-password: success, old-password-401, new-password-400, retry-eligible paths — satisfies R7
- [ ] Unit tests for the refresh coordinator: two concurrent `401`s produce exactly one `authRefresh` call and both callers retry with its result — satisfies R9, R16
- [ ] Unit tests for the retry ceiling: a post-refresh retry that itself gets `401` does not trigger a second refresh — satisfies R8
- [ ] Unit tests for the refresh-failure path: session cleared, all waiting callers abandon retry — satisfies R10
- [ ] Unit tests for the dependency-did-not-answer path on refresh: session holder is not cleared on a refresh timeout/network failure — satisfies R8
- [ ] Unit test for the logout-during-refresh race: a refresh that resolves after logout has already cleared the session holder does not resurrect a signed-in state — satisfies R9
- [ ] Contract tests against `interfaces/UNIT-CMS-0001.openapi.yaml` for all five consumed operations — satisfies R2, R3, R6, R7, R8, R9, R10
- [ ] Accessibility tests per `ux/a11y.md`: keyboard map, focus order (including on-error and on-terminal-outcome focus), and semantics for every frame in `ux/wireframes/UNIT-CMS-0002-identity-access-ui.html` — satisfies R1, R2, R4, R5, R6, R7
- [ ] Rate-limit handling test: a `429` response is surfaced as retry-eligible and honours `Retry-After` — satisfies R17

## Coverage check

| R-ID | Task(s) |
|---|---|
| R1 | Route guard implementation task; route-guard unit tests; a11y tests |
| R2 | Sign-in codegen task; sign-in flow implementation; sign-in validation/error tasks (3); sign-in unit tests; a11y tests |
| R3 | Session holder implementation task; codegen task |
| R4 | Role-gate implementation task; role-gate unit tests; a11y tests |
| R5 | Role-gate implementation task; role-gate unit tests; a11y tests |
| R6 | Sign-out implementation task; logout validation/error task; sign-out unit tests; a11y tests |
| R7 | Change-password implementation task; change-password validation/error tasks (3); change-password unit tests; a11y tests |
| R8 | Authenticated-call wrapper task; retry-ceiling task; refresh dependency-did-not-answer error task; retry-ceiling unit test; dependency-did-not-answer unit test |
| R9 | Refresh coordinator task; stale-write guard task; refresh-coordinator unit tests; logout-during-refresh unit test |
| R10 | Authenticated-call wrapper task; refresh-401 error task; refresh-failure unit tests |
| R11 | Covered by design.md § Cross-cutting (performance) — no independent task; inherent to the route guard's local-only check (Implementation section) |
| R12 | Covered by design.md § Cross-cutting (performance) — no independent task; see route guard implementation |
| R13 | N/A — no batch/bulk task exists in this unit's scope (design.md § Approach) |
| R14 | N/A — see R13 |
| R15 | Refresh coordinator task; retry-ceiling task |
| R16 | Refresh coordinator task; refresh-coordinator unit tests |
| R17 | Rate-limit validation task; rate-limit test |
| R18 | Codegen wiring task (bearer-auth scheme) |
| R19 | Tenant-identifier cross-cutting confirmation task |
| R20 | Diagnostic-emitter implementation task; observability confirmation task; credential-data confirmation task |
| R21 | Diagnostic-emitter implementation task; observability confirmation task |
| R22 | Session holder implementation task; credential-data confirmation task |
| R23 | Session holder implementation task |
| R24 | N/A — no migration/backfill task; stated explicitly in Cross-cutting section |
| R25 | N/A — no feature-flag task; stated explicitly in Cross-cutting section |
