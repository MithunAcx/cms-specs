---
code: CMS
name: Contact Management
status: active
owner: "@MithunAcx"
team: cms
codeowners: ["@acxhange/cms"]
upstream: []
downstream: []
created: 2026-08-18
updated: 2026-08-18
---

# Contact Management

## What this is

Contact Management is the internal, staff-facing system used to maintain an insurance
carrier's directory of distribution partners — brokerages, individual brokers, agencies,
agents, and CGAs (contract general agents / general agencies) — along with the
underwriter assignments and contact-activity/follow-up history tracked against each.
Users are internal staff only (primarily underwriters and their operations/support
staff); there is no public or partner-facing access.

The project is being rebuilt for functional parity with a legacy ASP.NET Web Forms
system: every existing capability (search across partners by six modes plus an
assigned-underwriter filter, create/maintain brokerages, agencies, and CGAs, log and
manage contact activity, US address autocomplete, reference-lookup maintenance) is
reproduced, while first-class defects in the legacy build — SQL injection exposure,
hard-coded secrets, unused authorization, ad-hoc validation — are corrected rather than
carried forward. It also surfaces a read-only view of related policies with deep-links
into the external policy-administration system.

## Boundary

**In:**
- Brokerage, broker, agency, agent, and CGA record management (create, update, search)
- Contact activity / follow-up logging against agencies and brokerages
- Assigned-underwriter tracking and filtering
- US address autocomplete on address entry
- Reference/lookup data maintenance (states, broker/agent types, statuses)
- Role-based access control (Viewer / Editor / Administrator) and audit logging
- Read-only display of, and deep-linking to, related policies

**Out:**
- Creating or editing policies — belongs to the external policy-administration system
- HR, document-repository, and file-handler subsystems — inherited legacy plumbing never
  used by Contact Management, not carried into this rebuild
- Single sign-on / corporate identity-provider federation — this build issues and
  validates its own JWTs against CMS-specific credentials (see
  `intake/2026-08-18-cms-modernization.md` Q3); SSO is explicitly not in scope

## Context

| Direction | System | Interaction |
|---|---|---|
| upstream | External policy-administration system | Live, read-only call at request time for related-policy data; deep-links out to policy detail (routed by policy class). No data replication into this project's store. |

Identity is self-contained: this project issues and validates its own JWTs against
CMS-specific credentials (no SSO / corporate identity-provider dependency for this
build — see `intake/2026-08-18-cms-modernization.md` Q3).

<!-- GENERATED:capabilities — do not hand-edit below. Written by pm-state-rollup. -->
## Capabilities

| Capability | Title | Status | Units | Progress |
|------------|-------|--------|-------|----------|
| CAP-CMS-0001 | Identity & Access Control | decomposed | 2 | 0 / 2 |
| CAP-CMS-0002 | Partner Directory & Search | decomposed | 2 | 0 / 2 |
| CAP-CMS-0003 | Partner Records Management | decomposed | 2 | 0 / 2 |
| CAP-CMS-0004 | Contact Activity & Follow-up Tracking | decomposed | 2 | 0 / 2 |
| CAP-CMS-0005 | External Integrations | decomposed | 2 | 0 / 2 |
| CAP-CMS-0006 | Legacy Data Migration | decomposed | 2 | 0 / 2 |

<!-- /GENERATED:capabilities -->
