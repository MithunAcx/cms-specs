---
id: CAP-CMS-0001
slug: identity-access-control
project: CMS
title: Identity & Access Control
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Identity & Access Control

## Original ask

> **AUTH-1** — Every request to a functional screen or API endpoint must be authenticated; unauthenticated requests are rejected (API `401`) / redirected to sign-in (SPA).
>
> **AUTH-2** — The system must be **single-sign-on capable** against the corporate identity provider so staff are not issued separate CMS passwords where SSO is available.
>
> **AUTH-3** — On successful authentication the system resolves and retains, for the session: the **username** (bare, domain prefix stripped) and the user's **display name** (first + last). These identify the actor and are stamped onto activity records.
>
> **AUTH-4** — Sessions persist across a normal working day (long-lived, refreshable token/session) but expire and can be revoked.
>
> **AUTH-5** — The API is stateless with respect to business data; the front end holds no long-term secrets beyond the session/access token.
>
> Authorization is explicit and enforced **server-side** on every mutating endpoint (defense in depth; the UI additionally hides/disable controls the user may not use).
>
> | Role | Capabilities |
> |---|---|
> | **Viewer** | Search; view brokerage/agency/CGA detail; view brokers/agents, activity, and policies. No create/edit/delete. |
> | **Editor** | All Viewer rights, plus create and edit brokerages, agencies, brokers, agents, CGAs, accounting addresses; create/edit/delete contact activity; maintain flags and statuses. |
> | **Administrator** | All Editor rights, plus manage reference lookups (states, broker/agent types, statuses, task statuses) and manage user role assignments. |
>
> **AUTHZ-1** — Each API endpoint declares the minimum role required; the server enforces it independent of the UI.
>
> **AUTHZ-2** — Activity entries are always stamped with the acting user's username (`UsrName`); this stamp is server-derived and not client-supplied.
>
> **AUTHZ-3** — The "Specialty" group concept and any other named rights from the legacy `SV_UserRights` table map to RBAC roles/permissions; unused legacy rights are dropped.
>
> **AUTHZ-4** — All create/update/delete operations are recorded in an audit log (actor, timestamp, entity, action) — see §9.4.
>
> **FR-AUTH-1** — The system shall require authentication before any functional screen or data endpoint is served.
>
> **FR-AUTH-2** — On sign-in, the system shall capture the current user, strip any domain prefix from the username, resolve the display name, and retain both for the session.
>
> **FR-AUTH-3** — The system shall stamp the acting user's username onto every contact-activity record created.
>
> **FR-AUTH-5** — The system shall provide sign-out, and shall support change-password only where local credentials (not SSO) are in use.
>
> **NFR-SEC-3** — Authorization is enforced server-side on every mutating endpoint per §3.3 (G3).
>
> **NFR-SEC-4** — All traffic over HTTPS/TLS; standard web protections (CSRF where cookie-based, XSS output encoding, security headers, CORS restricted to the SPA origin).
>
> **NFR-AUD-1** — Every create/update/delete records actor, timestamp, entity, and action to an audit log.
>
> | # | Legacy issue | Modernization requirement |
> |---|---|---|
> | G1 | SQL built by string-concatenating user input (search, all add/update, login). | **All** data access uses parameterized queries / an ORM. No dynamic SQL from user input. |
> | G3 | Authentication enforced, but authorization essentially unused. | Role-based access control (RBAC) is a first-class requirement; view/edit/delete permissions defined explicitly. |
>
> **API-4** — No endpoint accepts client-supplied `UsrName`, timestamps, or role — those are server-derived.

## Outcome measures

| # | Measure | Baseline | Target | How measured | From |
|---|---------|----------|--------|--------------|------|
| M1 | Mutating API endpoints that declare and server-side-enforce a minimum role | Legacy: authorization essentially unused | 100% of mutating endpoints enforce a declared minimum role, independent of the UI | Endpoint-by-endpoint audit against the role table in the raw ask §3.3 | intake O4 |
| M2 | Login/authentication data-access paths built with parameterized queries / an ORM | Legacy: login query built by string-concatenating user input | 0% string-concatenated SQL in the login/auth path | Code review of every auth data-access path | intake O2 |
| M3 | Create/update/delete operations recorded in the audit log with actor, timestamp, entity, and action | Legacy: no audit log | 100% of mutating operations across the system produce a matching audit-log entry | Audit-log completeness check against a sample of mutating operations across all capabilities | derived directly from raw ask AUTHZ-4/NFR-AUD-1 — not separately numbered as an intake `O<n>`; see Open questions |

## Outcome-level acceptance

- A1. Every API endpoint in the system declares a minimum role, and a request below that role is rejected with `403` regardless of what the UI would have allowed.
- A2. No unauthenticated request reaches a functional screen or a data endpoint; every such attempt returns `401` (API) or redirects to sign-in (SPA).
- A3. Every create, update, and delete operation across every capability produces one audit-log entry naming the actor, timestamp, entity, and action, and no entry names a client-supplied username, timestamp, or role.

## Non-goals

- Single sign-on / corporate identity-provider federation — explicitly out of scope for this build (intake Q3); this capability issues and validates its own JWTs against CMS-specific credentials.
- Reference-lookup maintenance UI itself — the Administrator role gets the *permission* to maintain lookups here, but the lookup screens and their data belong to CAP-CMS-0003 (Partner Records Management).
- Which specific fields are logged per entity type — the audit-log *shape* (actor, timestamp, entity, action) is fixed here; per-entity field-level change tracking, if ever wanted, is a separate ask.

## Constraints

| Constraint | Source | Effect |
|---|---|---|
| Self-issued JWT: short-lived access token + server-side-revocable refresh token; revocation = invalidating the refresh token | intake Q4 | Bounds the auth unit's token design — a purely stateless long-lived JWT does not satisfy AUTH-4's "can be revoked" |
| No SSO / corporate IdP | intake Q3 | Change-password (FR-AUTH-5) is **unconditionally** required, since this build is local-credentials-only, not conditional on "where local credentials are in use" as the raw ask frames it |
| API Gateway throttling is the rate-limiting layer | `stack.md` | Rate-limit error shape on this capability's endpoints is gateway-defined, not service-defined |
| Serverless compute (cold starts) | `stack.md` | Auth endpoints' latency budget must account for cold-start behavior, not assume always-warm compute |
| No special data-retention/residency requirement beyond standard company policy | intake Q9 | Session/token and audit-log retention follow standard policy; no bespoke retention period to design against |

## Decomposition rationale

Identity & Access Control is split out as its own capability because it is the one domain
every other capability depends on but none of them owns: authentication, authorization,
and the audit trail are cross-cutting concerns consumed by Partner Directory & Search,
Partner Records Management, Contact Activity Tracking, External Integrations, and Legacy
Data Migration alike. Folding it into whichever capability happened to need it first (most
naturally Partner Records Management, since RBAC's Editor/Administrator distinctions are
most visible there) was rejected: it would make every other capability depend on an
internal detail of one particular domain, rather than on a shared platform capability all
of them can cite identically. Splitting authentication from authorization from audit
logging into three separate capabilities was also considered and rejected — they share one
actor model (the authenticated user and their role) and one measurable outcome (can we
prove who did what, and did the system enforce what they were allowed to do), so keeping
them together is the natural business-capability seam.

## Dependencies

| Direction | What | Why |
|---|---|---|
| downstream | Partner Directory & Search, Partner Records Management, Contact Activity Tracking, External Integrations | Every one of these capabilities' endpoints declares a minimum role against this capability's RBAC model and relies on its authentication to resolve the acting user |

## Open questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| Q1 | M3 (audit-log completeness) traces to AUTHZ-4/NFR-AUD-1 directly rather than to a numbered intake `O<n>` — the intake's candidate outcomes (O1–O6) did not include a standalone audit-trail outcome distinct from RBAC enforcement. Should the intake be amended with an addendum `O<n>` for this, so future capabilities can cite it the same way the others cite O1–O6? | @MithunAcx | open — non-blocking, recorded for `ba-requirements-intake` to consider on its next pass |

<!-- GENERATED:units — do not hand-edit below. Written by pm-state-rollup. -->
## Units

<!-- /GENERATED:units -->
