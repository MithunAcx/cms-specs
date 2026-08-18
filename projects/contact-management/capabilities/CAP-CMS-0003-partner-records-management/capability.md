---
id: CAP-CMS-0003
slug: partner-records-management
project: CMS
title: Partner Records Management
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Partner Records Management

## Original ask

> - Create and maintain brokerages (including their brokers, accounting/billing address, and status).
> - Create and maintain agencies (including their agents, flags, and notes).
> - Maintain CGA records.
> - Maintenance of reference lookups (states, broker types, agent types, broker statuses, task statuses).
>
> **FR-BRK-1** — The system shall let an Editor create a brokerage capturing: brokerage name, address, city, state, zip, phone, fax, tax id (FEIN), assigned underwriter, status (controlled list), contract-received date, and history flag.
>
> **FR-BRK-2** — On save, the system shall persist the brokerage (reusing the legacy `PPSP_AddBrokerageEntry` logic or an equivalent parameterized insert), obtain the new `ProducerNumber`, and navigate the user to the Brokerage Detail screen for the new record so brokers and activity can be added immediately.
>
> **FR-BRK-3** — Address entry shall be assisted by US address autocomplete (§5.8). A cancel action returns to the Directory.
>
> **FR-BRK-4** — The system shall let an Editor view and edit a brokerage's master details: name, address, city, state, zip, phone, fax, tax id, assigned underwriter, status, contract-received date, and history flag.
>
> **FR-BRK-5** — Phone and fax shall display in formatted `(nnn) nnn-nnnn` form and be normalized on save; the read-only ePay/AccountCode shall be displayed.
>
> **FR-BRK-6** — Saving shall update the record and confirm success.
>
> **FR-BRK-7** — The Brokerage Detail screen shall present, for the brokerage: a **Brokers/contacts grid** (list and inline add/edit of first name, last name, broker type/title, email, NPN, and disabled flag); a **Contact-activity grid** (owned by CAP-CMS-0004); and a **Policy-activity grid** (owned by CAP-CMS-0005).
>
> **FR-BRK-8** — The screen shall offer access to maintain the brokerage's separate **accounting/billing address**, and navigation back to search.
>
> **FR-BRK-9** — The system shall let an Editor maintain a brokerage's accounting address (contact name, address, city, state, zip) in a focused dialog, updating the brokerage's accounting fields on save.
>
> **FR-AGY-1** — The system shall let an Editor create an agency capturing: agency name, address, city, state, zip, phone, agency number, and a Premium Financing flag.
>
> **FR-AGY-2** — On save, the system shall persist the agency and run account-code generation (equivalent of `ppsp_add_accountcode`), then confirm via a dialog offering two choices: go to Agency Detail for the new agency, or add another agency.
>
> **FR-AGY-3** — Address entry shall use US autocomplete.
>
> **FR-AGY-4** — The system shall let an Editor view and edit an agency's master details: name, address, city, state, zip, phone, billing contact, billing contact phone, notes, agency number ("G1 Agency ID"), and the High Potential, Premium Financing, and History flags.
>
> **FR-AGY-5** — Phone numbers shall be normalized (punctuation stripped) on save.
>
> **FR-AGY-6** — The Agency Detail screen shall present, for the agency: an **Agents grid** (list and inline add/edit of first name, last name, agent type/title, phone, email, NPN, and history flag); a **Contact-activity grid** (owned by CAP-CMS-0004); and a **Policy-activity grid** (owned by CAP-CMS-0005).
>
> **FR-AGY-7** — The screen shall provide navigation to the "Specialty" area (where applicable to the user's role) and back to the Directory.
>
> **FR-CGA-1** — The system shall let an Editor view and edit CGA records in a grid keyed by CGA id, supporting inline add and edit of: agent name, address, city, state, zip, email, phone, and associated agency id.
>
> **FR-CGA-2** — Address entry shall use US autocomplete, filling city/state/zip for the edited row.
>
> **FR-CGA-3** — CGA inserts shall write to the **CGA table** (`PP_Agency_CGA`) — correcting the legacy bug that inserted into `pp_agent`.
>
> **FR-CGA-4** — CGA phone shall be handled as a string (not a float), preserving formatting; a back action returns to the Directory.
>
> **FR-REF-1** — The system shall maintain and serve lookup lists that populate dropdowns: US states, broker types, agent types, broker statuses, and task/activity statuses (the last filtered by `TskType_ID = 2` and ordered by `orderBy`).
>
> **FR-REF-2** — Administrators shall be able to view and maintain these lookups; all other roles consume them read-only.
>
> **NFR-VAL-1** — Centralized validators for phone (normalize to digits, display `(nnn) nnn-nnnn`), zip, email, FEIN, and dates.
>
> **NFR-VAL-2** — Required fields enforced (e.g. brokerage name, agency name) both client and server.
>
> **NFR-VAL-3** — Legacy quirks (float phone, mixed history flags, string/int agency id) handled without leaking to the UI.
>
> | Ref | Legacy defect | Required behavior in the new system |
> |---|---|---|
> | DR-1 | `CGAUpdate` inserts CGA data into `pp_agent`. | CGA create/update writes to `PP_Agency_CGA` only. |
> | DR-2 | `PP_Agency_CGA.Phone` typed `float`. | Treat CGA phone as a string end-to-end. |
> | DR-3 | `history`/`History` flags use mixed conventions (int `-1/0` vs `char(10)`). | The domain layer exposes a clean boolean `disabled`/`history`. |
> | DR-6 | `PP_Agency_CGA.Agency_ID` is `nvarchar` while `PP_Agent.Agency_ID` is `int`. | Handle both explicitly at the boundary. |
> | DR-7 | `PP_Broker_Status` declares no PK constraint. | Treat `Status_ID` as the logical key. |
>
> The new PostgreSQL schema will be a clean redesign following the raw ask's own §6.5
> domain model (`Brokerage`, `Broker`, `Agency`, `Agent`, `Cga`), not a column-for-column
> mirror of the legacy SQL Server tables — so DR-1..DR-8's *physical* bugs do not need to
> be reproduced or fixed in place; only their domain intent carries forward (intake Q1/A1).

## Outcome measures

| # | Measure | Baseline | Target | How measured | From |
|---|---------|----------|--------|--------------|------|
| M1 | Legacy capabilities reproduced for brokerage, agency, and CGA record management | 12 legacy capabilities enumerated in the raw ask's traceability matrix (§12) | All brokerage/agency/CGA-related capabilities (items 3–8, 12 of the matrix) reproduced and independently verified against the new system | Traceability check: every relevant legacy capability maps to ≥1 delivered requirement with a passing acceptance test | intake O1 |

## Outcome-level acceptance

- A1. Every field the legacy system captured for brokerages, agencies, and CGAs (per the raw ask §6.1 and `cms-data-schema.yaml`'s `used_by_app: true` columns) is representable and editable in the new system, in the clean domain-model shape of raw-ask §6.5.
- A2. CGA create/update writes only to the CGA entity — DR-1's mis-insert bug is not reproduced, verified by a dedicated regression test.
- A3. Optimistic concurrency control rejects a save when the underlying brokerage/agency/CGA/broker/agent record changed since it was loaded (intake Q10) — verified by a concurrent-edit test.
- A4. Reference lookups (states, broker types, agent types, broker statuses, task/activity statuses) are viewable by every role and maintainable only by Administrators.

## Non-goals

- Search/discovery of partners — owned by CAP-CMS-0002 (Partner Directory & Search); this capability starts from "I already know which brokerage/agency/CGA I want."
- Contact-activity logging against a brokerage or agency — owned by CAP-CMS-0004 (Contact Activity & Follow-up Tracking), even though its grid is embedded in the Brokerage/Agency Detail screens this capability owns.
- Policy display/deep-linking on the Brokerage/Agency Detail screens — owned by CAP-CMS-0005 (External Integrations).
- The US address-autocomplete mechanism itself (FR-BRK-3, FR-AGY-3, FR-CGA-2's "use US autocomplete" clauses) — owned by CAP-CMS-0005 (External Integrations); this capability only consumes that capability's suggest-and-fill contract on its address forms, and owns the surrounding navigation (e.g. cancel/back returns to the Directory) those same FR rows also specify.
- Promoting "Assigned Underwriter" to a managed reference entity — confirmed to stay free text (intake Q7); `BAssignedUW` remains a plain field on the brokerage record, not a lookup this capability administers.
- The one-time cutover of existing legacy data into this capability's new schema — owned by CAP-CMS-0006 (Legacy Data Migration); this capability defines the target schema and CRUD behavior, migration owns getting existing rows into it.
- Single sign-on, corporate identity-provider federation, and how requests are authenticated — owned by CAP-CMS-0001.

## Constraints

| Constraint | Source | Effect |
|---|---|---|
| Clean-redesign schema, no legacy physical-bug reproduction (DR-1..DR-8 as physical quirks) | intake Q1/A1 | The domain model in raw-ask §6.5 is the target shape, not the physical columns in `cms-data-schema.yaml` |
| Optimistic concurrency control on shared master records | intake Q10 | Every brokerage/agency/CGA/broker/agent update endpoint must carry and check a version/ETag; last-write-wins is not acceptable |
| No special PII retention/residency requirement beyond standard company policy | intake Q9 | FEIN, NPN, phone, email, address fields need no bespoke retention design |
| PostgreSQL 18, row-level security for tenant isolation | `stack.md` | Every table this capability owns needs an RLS policy authored alongside its migration — a table without one is an isolation gap |
| Small-scale volume: low hundreds of brokerages/agencies/CGAs | intake Q8 | Bounds expected data volume for schema/indexing decisions |

## Decomposition rationale

Brokerage, agency, and CGA management are kept in one capability rather than three,
because they are the same business capability — "maintain our distribution partner
records" — expressed over three partner *types* that a stakeholder would not naturally
split into separate domains; the modernization ask's own goal G9 ("near-duplicate
add/update/search code per partner type... shared, reusable services and components")
argues explicitly against treating them as separate products. Reference-lookup
maintenance (states, broker/agent types, statuses) is folded in here rather than given
its own capability because it has no independent business outcome — it exists purely to
support these records' controlled-value fields, and splitting it out would produce a
capability with no measurable acceptance criterion of its own (a smell explicitly called
out as "1 unit — it *is* the unit"). Splitting brokerages from agencies was considered
and rejected for the same reason as above: doing so would produce two capabilities with
nearly identical CRUD/validation/history-flag/audit shapes and no distinct acceptance
criterion between them.

## Dependencies

| Direction | What | Why |
|---|---|---|
| upstream | Identity & Access Control (CAP-CMS-0001) | Create/edit/delete requires Editor; lookup maintenance requires Administrator |
| upstream | Partner Directory & Search (CAP-CMS-0002) | Entry point into this capability's detail/edit screens, and the launch point for "Add New Agency"/"Add New Brokerage" |
| upstream | External Integrations (CAP-CMS-0005) | Address entry on every brokerage/agency/CGA/accounting form is assisted by the address-autocomplete contract that capability owns |
| downstream | Contact Activity & Follow-up Tracking (CAP-CMS-0004) | The activity grid embedded in Brokerage/Agency Detail screens is that capability's, attached to this capability's records |
| downstream | Legacy Data Migration (CAP-CMS-0006) | The migration's target schema is this capability's domain model |

## Open questions

| # | Question | Owner | Status |
|---|----------|-------|--------|

<!-- GENERATED:units — do not hand-edit below. Written by pm-state-rollup. -->
## Units

<!-- /GENERATED:units -->
