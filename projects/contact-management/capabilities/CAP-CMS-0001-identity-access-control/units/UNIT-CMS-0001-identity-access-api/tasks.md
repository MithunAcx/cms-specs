---
unit: UNIT-CMS-0001
change: original
---

# Tasks — Identity Access API

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate server types/stubs and the bearer-token security scheme from `interfaces/openapi.yaml` — satisfies R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12

## Data

Schema and migration tasks from `interfaces/*.sql`, plus any backfill the design
flagged as its own task.

- [ ] Apply the `cms_user` table and its tenant-scoped row-level-security policy — satisfies R1, R2, R22
- [ ] Apply the `role_assignment` table and its tenant-scoped row-level-security policy, with its one-role-per-user uniqueness constraint — satisfies R3, R22
- [ ] Apply the `refresh_token` table and its tenant-scoped row-level-security policy, with its unique token-hash constraint — satisfies R4, R5, R19, R22
- [ ] Apply the `audit_log_entry` table and its tenant-scoped row-level-security policy, its entity and occurred-at indexes, and grant the application role INSERT/SELECT only (no UPDATE, no DELETE) — satisfies R22, R23
- [ ] Configure the one-time backfill of `role_assignment` from legacy `SV_UserRights` as a task tracked in `UNIT-CMS-0011`'s own `tasks.md` — not a migration statement here (design.md § Data model); confirm this unit's schema is ready to receive that backfill — satisfies R27

## Implementation

- [ ] Implement request validation for `POST /auth/login` (missing `username`/`password`) before any credential lookup — satisfies R1
- [ ] Implement the credential validator: strip the domain prefix from `username`, look up the credential within tenant scope, verify the password against the stored hash, returning an identical failure shape for "unknown username" and "wrong password" — satisfies R1, R13
- [ ] Implement the identity resolver: resolve display name and role, and embed `username`, `displayName`, `role`, `tenantId` as access-token claims — satisfies R2, R3, R22
- [ ] Implement the token issuer: mint an access token (15-minute TTL, per design.md § Approach) and a refresh token (30-day TTL, rotated on every use), creating one refresh-token-store record per issued refresh token — satisfies R1, R4, XD-0001
- [ ] Implement the atomic consume-once operation on the refresh-token record (conditional update from active to consumed, creating its successor in the same operation) — satisfies R4, R19
- [ ] Implement the reuse-detector: on a refresh call against an already-consumed token, reject it and revoke every other active refresh-token record for the same user — satisfies R4 (behaviour detail)
- [ ] Implement `POST /auth/logout`: mark the presented refresh token revoked, returning success whether or not it was already revoked or expired — satisfies R5
- [ ] Implement `GET /auth/me`: resolve `username`, `displayName`, `role` from the caller's own validated access-token claims only — satisfies R6
- [ ] Implement `POST /auth/change-password`: verify the presented current password against the caller's own stored hash (resolved from the token, never a request field), validate the new password against the strength policy, and replace the stored hash without rotating the caller's current token pair — satisfies R7
- [ ] Implement the audit writer: accept `{ actor, entityType, entityId, action, metadata }`, resolve `actor` and `timestamp` server-side, and append one immutable entry; make this unit's own mutating endpoints call it synchronously — satisfies R9, R10, R23
- [ ] Implement `GET /audit-log`: filter by `entityType`/`entityId`, cursor-paginate, and scope every result to the caller's own tenant — satisfies R8, R22
- [ ] Wire bearer-token authentication and the per-endpoint minimum-role check (`/audit-log` → Administrator, every other authenticated endpoint → Viewer-or-above) — satisfies R3, R11, R21
- [ ] Tune password-hash cost parameters to stay inside the stated latency budget at peak throughput, above the documented minimum-strength floor — satisfies R15, R16

## Validation and errors

- [ ] Return `400 invalid_request` for a malformed `POST /auth/login` or `POST /auth/refresh` body — satisfies R1, R4
- [ ] Return `401 invalid_credentials` for an unknown username or a wrong password on login, using the identical shape for both — satisfies R1
- [ ] Return `401 invalid_refresh_token` for a refresh token that is not found, expired, revoked, or already consumed (including the reuse case) — satisfies R4, R19
- [ ] Return `204` from `/auth/logout` unconditionally, including when the presented token was already revoked or expired — satisfies R5
- [ ] Return `401` for an unauthenticated request to any endpoint other than `/auth/login` and `/auth/refresh` — satisfies R12
- [ ] Return `401 invalid_credentials` from `/auth/change-password` when the presented current password does not match, and `400 weak_password` when the new password fails the strength policy — satisfies R7
- [ ] Return `403 insufficient_role` from `/audit-log` for a caller below Administrator — satisfies R8, R11
- [ ] Confirm every data-access path in the login/refresh/change-password flows uses parameterized queries only — satisfies R13

## Observability

- [ ] Emit metrics: login success/failure count, token-refresh count, refresh-reuse-rejection count, audit-log write latency — satisfies R24
- [ ] Emit structured logs with caller id (once authenticated), tenant id, endpoint, and outcome code — with no password, raw access/refresh token, or special-category value ever logged — satisfies R24, R25
- [ ] Instrument the audit-log write as its own trace span — satisfies R9, R24

## Tests

- [ ] Unit tests covering every R-ID branch listed above
- [ ] Contract tests generated from `interfaces/openapi.yaml` pass
- [ ] Test: login with an unknown username and login with a known username but wrong password produce byte-identical error bodies (R1)
- [ ] Test: two concurrent `POST /auth/refresh` calls with the same refresh token — exactly one succeeds, the other is rejected as already-consumed (R19)
- [ ] Test: a refresh token reused after rotation is rejected, and every other active refresh token for that user is revoked (R4 behaviour detail)
- [ ] Test: `POST /auth/logout` called twice with the same token returns `204` both times (R5)
- [ ] Test: `/audit-log` never returns an entry belonging to another tenant (R22)
- [ ] Test: no `UPDATE` or `DELETE` statement can succeed against the audit-log table under the application's own database role (R23)

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Login request-validation task; credential-validator task; token-issuer task; `cms_user` migration task; error tasks; enumeration test |
| R2 | Identity-resolver task; `cms_user` migration task |
| R3 | Identity-resolver task; bearer-token/role-check wiring task; `role_assignment` migration task |
| R4 | Token-issuer task; consume-once task; `refresh_token` migration task; error tasks; reuse test |
| R5 | Logout task; error task; logout-idempotency test |
| R6 | `/auth/me` task |
| R7 | Change-password task; error task |
| R8 | `/audit-log` task; error task; per-endpoint role-check wiring task |
| R9 | Audit-writer task; observability trace-span task |
| R10 | Audit-writer task |
| R11 | Bearer-token/role-check wiring task; `/audit-log` error task |
| R12 | Unauthenticated-401 task |
| R13 | Credential-validator task; parameterized-query confirmation task |
| R14 | — no task; platform-default statement, not a build item |
| R15 | Password-hash tuning task |
| R16 | Password-hash tuning task |
| R17 | — no task; enforced by API Gateway configuration outside this unit's build |
| R18 | — no task; inherent to independent, non-deduplicated login calls, covered by contract tests |
| R19 | Consume-once task; concurrency test |
| R20 | — no task; enforced by API Gateway configuration outside this unit's build |
| R21 | Bearer-token/role-check wiring task |
| R22 | Every table's RLS-policy migration task; identity-resolver task; `/audit-log` task; tenant-isolation test |
| R23 | Audit-writer task; `audit_log_entry` migration task (INSERT/SELECT-only grant); no-UPDATE/DELETE test |
| R24 | Observability tasks |
| R25 | Observability logging task; credential-validator/change-password tasks (never logging secrets) |
| R26 | — no task; erasure-path mechanics are an open question in `requirements.md`, to be tasked once resolved |
| R27 | Backfill-coordination task — the backfill itself is `UNIT-CMS-0011`'s task, not this unit's |
| R28 | — no task; N/A per `requirements.md` |
