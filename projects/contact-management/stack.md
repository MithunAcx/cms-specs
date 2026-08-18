# Technology stack — Contact Management (CMS)

Authored by `pm-project-init` from answers the user gave **explicitly**. Read by
`architect-unit-design`, `architect-unit-interfaces`, `architect-unit-tasks` and
`ba-unit-handoff`.

**Nothing in this file may be inferred.** Every row is either a value the user stated, or
`UNRESOLVED` with an owner. A plausible default here is rewritten work downstream: a
guessed datastore throws away a storage contract, and a guessed runtime produces latency
requirements nobody can meet.

**No concrete endpoints.** Hostnames, URLs, ARNs, account numbers, regions, queue names
and connection strings belong to the engineering repo and its environments — not here.
Name the *service*, never its address.

**Note on divergence from `requirements/CMS-Modernization-Requirements.md`:** that
document specifies Angular + Python REST API + Microsoft SQL Server as a literal
functional-parity rebuild of the legacy system. The project owner explicitly chose a
different stack below (AWS + Node.js + PostgreSQL + React) for this build — confirmed
2026-08-18. Functional scope still traces to that requirements document; only the
technology choice departs from it.

## Decided

| Concern | Choice | Stated by | Date |
|---|---|---|---|
| cloud / hosting | AWS | @MithunAcx | 2026-08-18 |
| primary datastore | PostgreSQL | @MithunAcx | 2026-08-18 |
| datastore version or mode | PostgreSQL 18 | @MithunAcx | 2026-08-18 |
| tenant isolation mechanism | Row-level security (RLS) | @MithunAcx | 2026-08-18 |
| compute / runtime model | Serverless functions | @MithunAcx | 2026-08-18 |
| backend language and version | Node.js 22 (TypeScript) | @MithunAcx | 2026-08-18 |
| synchronous API surface | OpenAPI 3.1 REST | @MithunAcx | 2026-08-18 |
| event transport | SQS/SNS | @MithunAcx | 2026-08-18 |
| identity provider | None — self-issued JWT, no external IdP | @MithunAcx | 2026-08-18 |
| OAuth2 flows in use | None — custom JWT issuance/verification, not an OAuth2 flow | @MithunAcx | 2026-08-18 |
| rate limiting layer | API Gateway throttling | @MithunAcx | 2026-08-18 |
| provisioning tool | AWS CDK | @MithunAcx | 2026-08-18 |
| frontend framework | React + Vite + TypeScript | @MithunAcx | 2026-08-18 |

## Unresolved

Anything not yet decided. A unit that needs one of these cannot be designed or contracted
past the point where it bites — say which unit and which artifact it blocks.

| Concern | Why it is open | Blocks | Owner |
|---|---|---|---|

## Deliberately out of scope for now

Concerns the user has explicitly parked. Recorded so no skill treats the silence as an
invitation to choose.

| Concern | Parked because | Revisit when |
|---|---|---|
| Slack channel | Not set up yet | A channel is created for the team |

## Consequences for the spec tree

Where a stack choice changes what a spec may promise — a runtime whose cold starts bound
achievable latency, a store with no server-side filtering, a gateway that produces its own
error shape. This is the section that stops a requirement being written that the stack
cannot honour.

| Choice | Consequence | Affected artifact |
|---|---|---|
| Serverless functions (compute) | Cold starts bound achievable p50/p99 latency; NFRs must state a latency budget consistent with cold-start behavior, not assume always-warm compute | `requirements.md` NFR rows, `design.md` |
| Self-issued JWT, no external IdP | No SSO; token issuance, rotation, and revocation are this project's own responsibility rather than delegated to an identity provider | `requirements.md` auth NFRs, `interfaces/` |
| API Gateway throttling | Rate-limit behavior and error shape on throttling are gateway-defined, not service-defined | `interfaces/*.openapi.yaml` error responses |
| Row-level security (Postgres) | Every tenant-scoped table needs an RLS policy authored alongside its migration; a table without one is an isolation gap, not an oversight to fix later | `interfaces/*.sql` migrations |

## Change log

A stack change after any unit is `handed-off` invalidates contracts already generated
from it. Record every change, and name the units it forces back through
`ba-change-request`.

| Date | Change | Units affected |
|---|---|---|
