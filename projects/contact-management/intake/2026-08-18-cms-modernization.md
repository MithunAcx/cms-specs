# Intake — CMS Modernization

**Source:** `requirements/CMS-Modernization-Requirements.md`, `requirements/database-specification.md`, and `requirements/cms-data-schema.yaml`, supplied by the project owner (@MithunAcx) via the repo's `requirements/` folder, 2026-08-18. The modernization requirements document is itself an SRS authored against a reverse-engineering of the legacy ASP.NET application; the two supporting documents are its own cited references (§1.4).
**Project:** CMS
**Status:** ready

## Raw ask

> # Contact Management System (CMS) — Modernization Requirements Specification
>
> **Target platform:** Angular (single-page application) front end + Python REST API back end + Microsoft SQL Server (`PolicyPlus`)
> **Document type:** Software Requirements Specification (SRS) for a functional-parity rebuild
> **Status:** Draft v1.0
> **Date:** 6 August 2026
>
> ## 1. Introduction
>
> ### 1.1 Purpose
>
> This document specifies the requirements for a modern replacement of the existing Contact Management System (CMS), an internal, staff-facing web application used by the insurance carrier **Doxa** to maintain its directory of distribution partners — brokerages, individual brokers, agencies, agents, and CGAs (contract general agents / general agencies) — along with the underwriter assignments, contact-activity history, and read-only policy activity associated with each.
>
> The legacy system is an ASP.NET **Web Forms** application in **VB.NET** on **.NET Framework 4.8**, using server-side `GridView`/`SqlDataSource` binding, the AJAX Control Toolkit, jQuery UI, the SmartyStreets US Autocomplete Pro API, and Microsoft SQL Server (primarily the `PolicyPlus` database). The replacement will deliver **the same business functionality** on a modern stack: an **Angular** SPA talking to a **Python REST API**, backed by the same SQL Server data.
>
> ### 1.2 Scope
>
> The new application must reproduce every capability of the legacy CMS:
>
> - Authenticated, staff-only access with the logged-in user stamped onto activity records.
> - Search across distribution partners by six modes plus an assigned-underwriter filter.
> - Create and maintain brokerages (including their brokers, accounting/billing address, and status).
> - Create and maintain agencies (including their agents, flags, and notes).
> - Maintain CGA records.
> - Log, edit, and delete contact activity / follow-ups against agencies and brokerages.
> - US address autocomplete on all address forms.
> - Read-only display of related policies with deep-links into the external policy-administration system.
> - Maintenance of reference lookups (states, broker types, agent types, broker statuses, task statuses).
>
> Out of scope (unchanged from legacy): creating or editing policies (owned by the external policy system), the HR/FileHandler/DocumentRepos subsystems that were inherited plumbing but never used by the CMS pages.
>
> ### 1.3 Definitions
>
> | Term | Meaning |
> |---|---|
> | **Brokerage** | A distribution firm; keyed by `ProducerNumber`. |
> | **Broker** | An individual person (employee) attached to a brokerage. |
> | **Agency** | A distribution firm of a second type; keyed by `PP_Agency_ID`. |
> | **Agent** | An individual person attached to an agency. |
> | **CGA** | Contract General Agent / General Agency record. |
> | **Contact Activity / Task** | A logged interaction or follow-up recorded against an agency or brokerage. |
> | **UW** | Underwriter (assigned to brokerages). |
> | **FEIN** | Federal Employer Identification Number (tax id). |
> | **NPN** | National Producer Number. |
> | **Producer** | Generic term for a brokerage/agency in the policy system. |
>
> ### 1.4 References
>
> - `requirements.md` — reverse-engineered functional requirements of the legacy app.
> - `database-specification.md` — databases, tables, views, and stored procedures the legacy app touches.
> - `cms-data-schema.yaml` — the physical `PolicyPlus` schema (verbatim column types) for the tables the CMS uses.
> - `contactmanagement-angular-mockup.html` — indicative UI redesign (search landing + add dialogs).
>
> ## 2. Modernization Goals and Principles
>
> The rebuild is a **functional-parity** effort — no business capability is dropped — while the following defects and constraints observed in the legacy code are corrected as first-class requirements.
>
> | # | Legacy issue | Modernization requirement |
> |---|---|---|
> | G1 | SQL built by string-concatenating user input (search, all add/update, login). | **All** data access uses parameterized queries / an ORM. No dynamic SQL from user input. |
> | G2 | SmartyStreets credentials and SQL host hard-coded in source. | All secrets, endpoints, and connection strings externalized to secure configuration / secret store. |
> | G3 | Authentication enforced, but authorization essentially unused. | Role-based access control (RBAC) is a first-class requirement; view/edit/delete permissions defined explicitly. |
> | G4 | Hard-coded server names, UNC paths, magic producer id (`2105941587`), environment URLs. | Everything environment-specific is configurable per environment. |
> | G5 | Minimal validation; ad-hoc phone normalization in SQL. | Centralized server-side validation and normalization (phone, zip, email, FEIN, dates). |
> | G6 | Web Forms, jQuery 1.4/2.0, table layouts, logic in code-behind. | Clean separation: Angular presentation, REST API, and a distinct domain/service layer. |
> | G7 | Exceptions swallowed silently or shown via `MsgBox`. | Consistent structured logging and user-facing error handling. |
> | G8 | CGA insert targets the wrong table (`pp_agent`); CGA `Phone` typed `float`; mixed `history` flag conventions. | Corrected in the data-access layer and migration (see §6.4). |
> | G9 | Near-duplicate add/update/search code per partner type. | Shared, reusable services and components across entity types. |
>
> **Principle:** the physical `PolicyPlus` schema is preserved (faithful parity) so migration is low-risk, but the **application** treats data cleanly — normalizing on write, coercing legacy quirks on read, and never depending on the known bugs.
>
> ## 3. Actors, Roles, and Authorization
>
> ### 3.1 Actors
>
> **Authenticated staff user** is the only human actor — internal insurance-company staff, primarily underwriters and their operations/support staff. There is no public or partner-facing access. Every functional screen requires authentication.
>
> ### 3.2 Authentication (technology-neutral requirements)
>
> The specific identity technology is left to the build team; the following requirements hold regardless of the choice:
>
> - **AUTH-1** — Every request to a functional screen or API endpoint must be authenticated; unauthenticated requests are rejected (API `401`) / redirected to sign-in (SPA).
> - **AUTH-2** — The system must be **single-sign-on capable** against the corporate identity provider so staff are not issued separate CMS passwords where SSO is available.
> - **AUTH-3** — On successful authentication the system resolves and retains, for the session: the **username** (bare, domain prefix stripped) and the user's **display name** (first + last). These identify the actor and are stamped onto activity records.
> - **AUTH-4** — Sessions persist across a normal working day (long-lived, refreshable token/session) but expire and can be revoked.
> - **AUTH-5** — The API is stateless with respect to business data; the front end holds no long-term secrets beyond the session/access token.
>
> ### 3.3 Authorization (RBAC)
>
> Authorization is explicit and enforced **server-side** on every mutating endpoint (defense in depth; the UI additionally hides/disable controls the user may not use).
>
> | Role | Capabilities |
> |---|---|
> | **Viewer** | Search; view brokerage/agency/CGA detail; view brokers/agents, activity, and policies. No create/edit/delete. |
> | **Editor** | All Viewer rights, plus create and edit brokerages, agencies, brokers, agents, CGAs, accounting addresses; create/edit/delete contact activity; maintain flags and statuses. |
> | **Administrator** | All Editor rights, plus manage reference lookups (states, broker/agent types, statuses, task statuses) and manage user role assignments. |
>
> - **AUTHZ-1** — Each API endpoint declares the minimum role required; the server enforces it independent of the UI.
> - **AUTHZ-2** — Activity entries are always stamped with the acting user's username (`UsrName`); this stamp is server-derived and not client-supplied.
> - **AUTHZ-3** — The "Specialty" group concept and any other named rights from the legacy `SV_UserRights` table map to RBAC roles/permissions; unused legacy rights are dropped.
> - **AUTHZ-4** — All create/update/delete operations are recorded in an audit log (actor, timestamp, entity, action) — see §9.4.
>
> ## 4. System Architecture Overview
>
> **Layering requirements**
>
> - **ARCH-1** — The Angular SPA contains no business rules beyond presentation/validation UX; all authoritative rules live in the API's service layer.
> - **ARCH-2** — The API exposes a versioned REST contract (`/api/v1/...`) returning JSON; it never returns raw SQL errors.
> - **ARCH-3** — Data access is isolated in a repository layer using parameterized queries or an ORM against `PolicyPlus` (and the rights source). Existing stored procedures may be reused where they add value, but always invoked with parameters.
> - **ARCH-4** — The address-autocomplete provider is called **from the server** (or a server proxy) so provider credentials never reach the browser.
> - **ARCH-5** — Configuration (connection strings, provider keys, external policy base URL, the producer id used for policy lookups) is read from environment/secret configuration, never hard-coded.
>
> ## 5. Functional Requirements
>
> Requirements are grouped by module. Each is written as "the system shall …" and carries an ID for traceability (§12).
>
> ### 5.1 Authentication and Session (FR-AUTH)
>
> - **FR-AUTH-1** — The system shall require authentication before any functional screen or data endpoint is served.
> - **FR-AUTH-2** — On sign-in, the system shall capture the current user, strip any domain prefix from the username, resolve the display name, and retain both for the session.
> - **FR-AUTH-3** — The system shall stamp the acting user's username onto every contact-activity record created.
> - **FR-AUTH-4** — The application landing route shall be the **Directory / Search** screen; the root path redirects there (replacing the legacy `Default.aspx → brokerage.aspx` redirect).
> - **FR-AUTH-5** — The system shall provide sign-out, and shall support change-password only where local credentials (not SSO) are in use.
>
> ### 5.2 Search — Directory Landing (FR-SEARCH)
>
> The Directory screen is the hub. The user types a term, selects one search mode, and runs the search; matches render in a results list where each row deep-links to the appropriate detail screen.
>
> - **FR-SEARCH-1** — The system shall support six mutually exclusive search modes:
>
>   | Mode | Matches on | Result columns | Row opens |
>   |---|---|---|---|
>   | **By Brokerage** | brokerage name contains term | Brokerage, Address (city/state/zip), Assigned UW, State | Brokerage Detail |
>   | **By Broker** | broker person name contains term | First, Last, Brokerage, Title/Type, Email (mailto), Disabled flag | Brokerage Detail (of that broker's brokerage) |
>   | **By State (Broker)** | brokerage state | same as By Brokerage | Brokerage Detail |
>   | **By Agency** | agency + address text contains term | Agency, Address, Agent | Agency Detail |
>   | **By CGA** | CGA agent name or address | CGA Agent, Address | CGA Detail |
>   | **By State (Agent)** | agency/agent state | Agency, Address, Agent | Agency Detail |
>
> - **FR-SEARCH-2** — The system shall provide an **Assigned Underwriter** filter — a dropdown populated with the underwriters currently assigned to at least one brokerage. Selecting one immediately lists that underwriter's brokerages.
> - **FR-SEARCH-3** — The system shall require a non-empty search term before running a name/keyword search, showing an inline validation message when empty. (State/UW modes may run without a free-text term.)
> - **FR-SEARCH-4** — Each result set shall show a clear "No records to display" empty state, and shall show a result count.
> - **FR-SEARCH-5** — The Broker results shall render email as a `mailto:` link and show an Active/Disabled status indicator.
> - **FR-SEARCH-6** — From the Directory the user shall be able to launch **Add New Agency** and **Add New Brokerage**.
> - **FR-SEARCH-7** — Results shall be paginated or virtualized for large result sets, with server-side filtering (search executes on the API, not the client).
> - **FR-SEARCH-8** — The results view shall be responsive: a table on desktop and stacked cards on mobile.
>
> ### 5.3 Brokerage Management (FR-BRK)
>
> #### 5.3.1 Add Brokerage
>
> - **FR-BRK-1** — The system shall let an Editor create a brokerage capturing: brokerage name, address, city, state, zip, phone, fax, tax id (FEIN), assigned underwriter, status (controlled list), contract-received date, and history flag.
> - **FR-BRK-2** — On save, the system shall persist the brokerage (reusing the legacy `PPSP_AddBrokerageEntry` logic or an equivalent parameterized insert), obtain the new `ProducerNumber`, and navigate the user to the Brokerage Detail screen for the new record so brokers and activity can be added immediately.
> - **FR-BRK-3** — Address entry shall be assisted by US address autocomplete (§5.8). A cancel action returns to the Directory.
>
> #### 5.3.2 Update Brokerage
>
> - **FR-BRK-4** — The system shall let an Editor view and edit a brokerage's master details: name, address, city, state, zip, phone, fax, tax id, assigned underwriter, status, contract-received date, and history flag.
> - **FR-BRK-5** — Phone and fax shall display in formatted `(nnn) nnn-nnnn` form and be normalized on save; the read-only ePay/AccountCode shall be displayed.
> - **FR-BRK-6** — Saving shall update the record and confirm success.
> - **FR-BRK-7** — The Brokerage Detail screen shall present, for the brokerage:
>   - **Brokers/contacts grid** — list and inline add/edit of first name, last name, broker type/title, email, NPN, and disabled flag.
>   - **Contact-activity grid** — list, add, edit, and delete activity (task type/status, follow-up date, note, entered date, completed flag); new entries stamped with the logged-in user.
>   - **Policy-activity grid** — list related policies (policy id, status, term, insured, class/subclass), color-coded by status, each openable in the external policy system (healthcare vs underwriter routing by class).
> - **FR-BRK-8** — The screen shall offer access to maintain the brokerage's separate **accounting/billing address**, and navigation back to search.
>
> #### 5.3.3 Accounting / Billing Address
>
> - **FR-BRK-9** — The system shall let an Editor maintain a brokerage's accounting address (contact name, address, city, state, zip) in a focused dialog, with US autocomplete and a state dropdown, updating the brokerage's accounting fields on save.
>
> ### 5.4 Agency Management (FR-AGY)
>
> #### 5.4.1 Add Agency
>
> - **FR-AGY-1** — The system shall let an Editor create an agency capturing: agency name, address, city, state, zip, phone, agency number, and a Premium Financing flag.
> - **FR-AGY-2** — On save, the system shall persist the agency and run account-code generation (equivalent of `ppsp_add_accountcode`), then confirm via a dialog offering two choices: **go to Agency Detail** for the new agency, or **add another agency**.
> - **FR-AGY-3** — Address entry shall use US autocomplete.
>
> #### 5.4.2 Update Agency
>
> - **FR-AGY-4** — The system shall let an Editor view and edit an agency's master details: name, address, city, state, zip, phone, billing contact, billing contact phone, notes, agency number ("G1 Agency ID"), and the High Potential, Premium Financing, and History flags.
> - **FR-AGY-5** — Phone numbers shall be normalized (punctuation stripped) on save.
> - **FR-AGY-6** — The Agency Detail screen shall present, for the agency:
>   - **Agents grid** — list and inline add/edit of first name, last name, agent type/title, phone, email, NPN, and history flag.
>   - **Contact-activity grid** — list, add, edit, and delete activity (task type/status, entered date, note, follow-up date, completed flag); new entries stamped with the user; completed date set automatically when marked complete.
>   - **Policy-activity grid** — related policies, color-coded, openable in the external policy system (healthcare vs underwriter by class).
> - **FR-AGY-7** — The screen shall provide navigation to the "Specialty" area (where applicable to the user's role) and back to the Directory.
>
> ### 5.5 CGA Management (FR-CGA)
>
> - **FR-CGA-1** — The system shall let an Editor view and edit CGA records in a grid keyed by CGA id, supporting inline add and edit of: agent name, address, city, state, zip, email, phone, and associated agency id.
> - **FR-CGA-2** — Address entry shall use US autocomplete, filling city/state/zip for the edited row.
> - **FR-CGA-3** — CGA inserts shall write to the **CGA table** (`PP_Agency_CGA`), correcting the legacy bug that inserted into `pp_agent` (see §6.4).
> - **FR-CGA-4** — CGA phone shall be handled as a string (not a float), preserving formatting; a back action returns to the Directory.
>
> ### 5.6 Contact Activity / Follow-up Tracking (FR-ACT)
>
> - **FR-ACT-1** — Across agencies and brokerages the system shall maintain a running activity log so staff can track outreach and follow-ups.
> - **FR-ACT-2** — For each entry the system shall capture: task type/status (controlled list scoped to the entity type, i.e. `TskType_ID = 2`), date entered, free-text note, follow-up (FU) date, a completed indicator with auto-set completion date, and the acting user's username.
> - **FR-ACT-3** — Entries can be added, edited, and deleted (delete gated to Editor+).
> - **FR-ACT-4** — Marking an entry complete shall set the completion date server-side to the current timestamp.
> - **FR-ACT-5** — The follow-up date and completed flag together shall support a "what is owed this partner next" workflow (e.g. sortable/filterable by follow-up date and open/closed state).
>
> ### 5.7 Reference / Lookup Data (FR-REF)
>
> - **FR-REF-1** — The system shall maintain and serve lookup lists that populate dropdowns: US states, broker types, agent types, broker statuses, and task/activity statuses (the last filtered by `TskType_ID = 2` and ordered by `orderBy`).
> - **FR-REF-2** — Administrators shall be able to view and maintain these lookups; all other roles consume them read-only.
>
> ### 5.8 Address Autocomplete (FR-ADDR)
>
> - **FR-ADDR-1** — On every address-entry form (add/update brokerage, add/update agency, CGA, accounting address) the system shall offer US address autocomplete.
> - **FR-ADDR-2** — As the user types a street address, suggestions shall be fetched (via the server/proxy) and selecting one shall auto-fill street, city, state, and zip for that address/row.
> - **FR-ADDR-3** — State shall populate into either a text field or a state dropdown depending on the form.
> - **FR-ADDR-4** — Provider credentials shall never be exposed to the browser (§ARCH-4, G2).
>
> ### 5.9 Policy System Integration — Read-Only (FR-POL)
>
> - **FR-POL-1** — For a given brokerage or agency, the system shall display related policies drawn from policy-administration data (policy id, status, term, insured, class/subclass).
> - **FR-POL-2** — The user shall be able to open a selected policy's full detail in the external policy-administration web application; the target page is chosen by policy **class** — healthcare classes (15/16/17) route to the healthcare detail page, all others to the underwriter detail page.
> - **FR-POL-3** — The external system base URL and the producer id used in the policy lookup shall be configuration values, replacing the hard-coded literal `2105941587` (G4).
> - **FR-POL-4** — The CMS shall neither create nor edit policies; this is navigation/reference only.
>
> ## 6. Data Model (Faithful Parity + Fixes)
>
> The new API reads and writes the existing `PolicyPlus` tables verbatim; column names/types are preserved so migration is a straight cut-over. The application layer normalizes data and never relies on the legacy defects. Types below are transcribed from `cms-data-schema.yaml`.
>
> ### 6.1 Core entities and key columns
>
> **PP_Brokerage** (PK `ProducerNumber` int identity) — `Brokerage`, `BAddress`/`BAddress1`/`BAddress2`, `BCity`, `BState`, `BZip`, `BPhoneNumber`, `BFaxNumber`, `BTax_ID`, `BAssignedUW`, `Status_ID` (→ PP_Broker_Status), `History`, `BContractRecvd`, `AccountCode` (read-only, populated by account-code generation), `BAccounting_AddName`, `BAccounting_Address`, `BAccounting_City`, `BAccounting_State` (→ PP_States), `BAccounting_Zip`.
>
> **PP_BrokerEmployees** (PK `EmployeeNumber`) — `ProducerNumber` (→ PP_Brokerage), `FirstName`, `LastName`, `BrokerType` (→ PP_BrokerType), `B_Email`, `BrokerNPN`, `History`.
>
> **PP_Agency** (PK `PP_Agency_ID`) — `Agency`, `Agy_Address`, `Agy_City`, `Agy_State` (→ PP_States), `Agy_Zip`, `Agy_Phone`, `Agy_Bill_Contact`, `Agy_Bill_Phone`, `Agy_Notes`, `AgencyNo` (G1 Agency ID), `HighPotential`, `PF_Flag`, `history`, `AccountCode`.
>
> **PP_Agent** (PK `PP_Agent_ID`) — `Agt_First`, `Agt_Last`, `Agt_Type_ID` (→ PP_AgentType), `Agt_Phone`, `Agt_Email`, `Agt_ID` (from agency's `AgencyNo`), `Agency_ID` (→ PP_Agency), `AgentNPN`, `history`.
>
> **PP_Agency_CGA** (PK `CGA_ID`) — `CGA_Agt`, `address`, `City`, `State`, `Zip`, `Email`, `Phone`, `Agency_ID`.
>
> **PP_TskData** (PK `PP_TskData_ID`) — polymorphic activity log: `Agency_id` (agency activity), `Brokerage_id` (brokerage/broker activity), `TskStatus_ID` (→ PP_TskStatus), `FUDate`, `Note`, `inputDate`, `ModifiedDate`, `CompletedDate`, `UsrName`.
>
> **PP_PolicyData** (PK `Policy_ID`, read-only) — `Class_ID` (drives healthcare vs UW routing), `Producer_ID`.
>
> **Web_Accounts** (PK `User_ID`) — `User_Name`, `Display_Name`, `Insurer_ID`, `InsurerID` (read to resolve the logged-in user).
>
> ### 6.2 Lookups
>
> `PP_States` (`State_ID`, `State`), `PP_BrokerType` (`BrokerType_ID`, `Broker_Type`), `PP_AgentType` (`PP_AgentType_ID`, `PP_AgentType`), `PP_Broker_Status` (`Status_ID`, `Status`), `PP_TskStatus` (`PP_TskStatus_ID`, `TskStatus`, `TskType_ID`, `orderBy`).
>
> ### 6.3 Views (read models)
>
> The legacy read models are preserved as read-only sources for search and detail loads: `PPV_BrokerSelect` (brokerage search), `ppv_brokerage` (single brokerage load), `ppv_brokerqq` (broker search), `PPV_AgencySelect` (agency search). The API may back these with the views or equivalent parameterized queries.
>
> ### 6.4 Defect remediation carried into the build
>
> | Ref | Legacy defect | Required behavior in the new system |
> |---|---|---|
> | DR-1 | `CGAUpdate` inserts CGA data into `pp_agent`. | CGA create/update writes to `PP_Agency_CGA` only. |
> | DR-2 | `PP_Agency_CGA.Phone` typed `float`. | Treat CGA phone as a string end-to-end; on read, coerce any legacy float value to a formatted string; plan a migration to a string column (§11). |
> | DR-3 | `history`/`History` flags use mixed conventions (int `-1/0` vs `char(10)`). | The domain layer exposes a clean boolean `disabled`/`history`; the repository maps to/from each table's physical convention. |
> | DR-4 | Hard-coded `Producer_ID = 2105941587` in policy lookups. | Producer id resolved from the record/config, never hard-coded. |
> | DR-5 | `Web_Accounts` has two insurer columns (`Insurer_ID`, `InsurerID`). | Both read; their distinct meaning documented; expose named fields rather than ambiguous duplicates. |
> | DR-6 | `PP_Agency_CGA.Agency_ID` is `nvarchar` while `PP_Agent.Agency_ID` is `int`. | Handle both explicitly; validate/convert at the boundary; document intended type for a future schema cleanup. |
> | DR-7 | `PP_Broker_Status` declares no PK constraint. | Treat `Status_ID` as the logical key; recommend adding a PK in migration. |
> | DR-8 | Phone normalization done ad hoc in SQL. | Centralize phone/zip normalization in the service layer with unit tests. |
>
> ### 6.5 Domain model (clean projection over the physical schema)
>
> To satisfy G6/G9 the API exposes clean resources that hide physical quirks:
>
> - `Brokerage { id, name, address{line1,line2,city,state,zip}, phone, fax, taxId, assignedUw, statusId, contractReceivedDate, disabled, accountCode(readonly), accounting{name,line1,city,stateId,zip} }`
> - `Broker { id, brokerageId, firstName, lastName, typeId, email, npn, disabled }`
> - `Agency { id, name, address{...}, phone, billing{contact,phone}, notes, agencyNo, highPotential, premiumFinancing, disabled, accountCode(readonly) }`
> - `Agent { id, agencyId, firstName, lastName, typeId, phone, email, npn, disabled }`
> - `Cga { id, agencyId, agentName, address{...}, email, phone }`
> - `Activity { id, parentType(agency|brokerage), parentId, statusId, note, followUpDate, enteredDate, completed, completedDate, userName(readonly) }`
> - `Policy { policyId, status, term, insured, classId, subclass }` (read-only)
>
> ## 7. REST API Specification
>
> Base path `/api/v1`. All responses JSON. All mutating endpoints require the noted minimum role and return validation errors as structured `400` payloads. Authentication via the chosen scheme (bearer token/session); unauthenticated → `401`; insufficient role → `403`.
>
> [Full endpoint tables: Auth & session, Search, Brokerages, Agencies, CGAs, Activity, Lookups & address — see §7.1–7.7 of the source document for the complete method/path/role/purpose listing.]
>
> - **API-1** — Pagination via `page`/`size`; responses include total count and page metadata.
> - **API-2** — Validation errors return `400` with a field-keyed error map; not-found returns `404`; conflicts `409`.
> - **API-3** — All write endpoints are idempotent where the verb implies it (PUT), and audited (§9.4).
> - **API-4** — No endpoint accepts client-supplied `UsrName`, timestamps, or role — those are server-derived.
> - **API-5** — Policy endpoints are read-only; there is no write path to `PP_PolicyData`.
>
> ## 8. Angular Front-End Architecture
>
> [Routes, component map, and FE-1..FE-6 — SPA-framework-specific; superseded for this build by the React/Vite/TypeScript stack decision in `stack.md`. The underlying UX/interaction requirements (reactive validation, inline grid editing, read-only color-coded policy grid, reusable address-autocomplete control, role-driven UI, responsive/accessible layout) carry over regardless of framework.]
>
> ## 9. Non-Functional Requirements
>
> ### 9.1 Security
>
> - **NFR-SEC-1** — All data access uses parameterized queries / an ORM; no user input is concatenated into SQL (G1).
> - **NFR-SEC-2** — Secrets and endpoints (DB connection strings, address-provider key, external policy URL, producer id) live in secure configuration / a secret store, never in source (G2, G4).
> - **NFR-SEC-3** — Authorization is enforced server-side on every mutating endpoint per §3.3 (G3).
> - **NFR-SEC-4** — All traffic over HTTPS/TLS; standard web protections (CSRF where cookie-based, XSS output encoding, security headers, CORS restricted to the SPA origin).
> - **NFR-SEC-5** — Input is validated and normalized server-side before persistence (G5).
>
> ### 9.2 Validation & data integrity
>
> - **NFR-VAL-1** — Centralized validators for phone (normalize to digits, display `(nnn) nnn-nnnn`), zip, email, FEIN, and dates.
> - **NFR-VAL-2** — Required fields enforced (e.g. brokerage name, agency name) both client and server.
> - **NFR-VAL-3** — Legacy quirks (float phone, mixed history flags, string/int agency id) handled per §6.4 without leaking to the UI.
>
> ### 9.3 Performance
>
> - **NFR-PERF-1** — Search returns first results within ~1s for typical datasets; large sets are paginated/virtualized server-side.
> - **NFR-PERF-2** — Detail screens load master + first tab within ~1s; secondary tabs load on demand.
>
> ### 9.4 Auditability & logging
>
> - **NFR-AUD-1** — Every create/update/delete records actor, timestamp, entity, and action to an audit log.
> - **NFR-AUD-2** — Activity records retain the `UsrName` stamp (server-derived) as the legacy system did.
> - **NFR-LOG-1** — Structured application logging replaces silent exception swallowing / `MsgBox` (G7); users see friendly errors, operators see diagnostics.
>
> ### 9.5 Configurability & environments
>
> - **NFR-CFG-1** — All environment-specific values are configuration; no server names, UNC paths, magic ids, or URLs in code (G4).
> - **NFR-CFG-2** — Distinct dev/test/prod configurations; the address provider, policy base URL, and DB target are all switchable per environment.
>
> ### 9.6 Accessibility & browser support
>
> - **NFR-A11Y-1** — WCAG 2.1 AA: keyboard navigation, focus management in dialogs, ARIA labels, sufficient contrast in both themes.
> - **NFR-BROWSER-1** — Latest evergreen browsers (Chrome, Edge, Firefox, Safari); responsive down to ~360px.
>
> ### 9.7 Maintainability
>
> - **NFR-MAINT-1** — Clear separation of Angular presentation, API controllers, service/domain layer, and repository (G6).
> - **NFR-MAINT-2** — Shared services/components eliminate the per-type duplication of the legacy app (G9).
> - **NFR-MAINT-3** — Automated tests: unit tests for validators/normalizers and services; integration tests for endpoints; e2e for the primary search→detail→edit flows.
>
> ## 10. External Integrations
>
> ### 10.1 US Address Autocomplete
>
> Server-proxied US street autocomplete (the legacy SmartyStreets US Autocomplete Pro capability). The provider is called from the API with credentials held in configuration; the browser calls only `/address/suggest`. Selecting a suggestion fills street/city/state/zip.
>
> ### 10.2 External Policy Administration (read-only deep-link)
>
> Related policies are read from policy-administration data and displayed read-only. Opening a policy deep-links into the external policy web application, choosing the healthcare detail page for classes 15/16/17 and the underwriter detail page otherwise. Base URL and the producer id used for the lookup are configuration.
>
> ### 10.3 Identity Provider
>
> SSO-capable integration with the corporate identity provider (technology-neutral, per §3.2). Username and display name are resolved at sign-in.
>
> ## 11. Data Migration
>
> - **MIG-1** — The `PolicyPlus` schema is preserved; the new API cuts over to the same tables — no bulk data migration is required for go-live.
> - **MIG-2** — Recommended (non-blocking) schema clean-ups, staged after parity is proven: convert `PP_Agency_CGA.Phone` from `float` to a string type (DR-2); normalize `history`/`History` flags to a single boolean convention (DR-3); add a primary key to `PP_Broker_Status` (DR-7); reconcile the dual insurer columns in `Web_Accounts` (DR-5); reconcile CGA `Agency_ID` typing (DR-6).
> - **MIG-3** — A data-quality pass should identify CGA rows previously mis-inserted into `pp_agent` (DR-1) and reconcile them into `PP_Agency_CGA`.
> - **MIG-4** — Reference lookups (`PP_States`, `PP_BrokerType`, `PP_AgentType`, `PP_Broker_Status`, `PP_TskStatus`) are used as-is.
>
> ## 12. Requirements Traceability Matrix
>
> [Legacy capability → new requirement ID mapping — see source §12. Twelve legacy capabilities plus two "new" cross-cutting requirements (explicit RBAC; parameterized data access / secrets externalized), each mapped to its FR-*/NFR-*/G* IDs.]
>
> ## 13. Appendices
>
> Search-mode behavior detail (term-required/backing-read-model per mode), policy status color-coding (status-distinguishable, theme-consistent, exact map is a UI concern), and the reference-lookup source list. Appendix D restates that the G1..G9 / DR-1..DR-8 defect remediations are requirements, not optional improvements.
>
> *End of specification.*

**Also captured, as cited supporting material (not paraphrased, summarized here since they are already data dictionaries rather than prose asks):**

`database-specification.md` enumerates: the CMS uses two SQL Server databases in practice (`PolicyPlus` for all business data, `Security` for `SV_UserRights` authorization data) out of seven declared connection strings, the other five being unused inherited plumbing (`DocumentRepos`, `FH`, `HR`, `PolicyTransactions2`, `ApplicationServices`); eight base tables, five lookup tables, four read-only views, and ten stored procedures the legacy app touches; a page-by-page cross-reference of which objects each `.aspx` page uses; and a "data-model observations" section flagging `PP_TskData`'s polymorphic parent, the two different producer/agency id styles, the CGA-insert bug, the hard-coded policy producer id, and the dual `Web_Accounts` insurer columns.

`cms-data-schema.yaml` gives the verbatim DDL-derived column list, SQL type, nullability, and identity flag for every table the CMS touches, flagging per-column whether the app actually uses it (`used_by_app`) — this shows many legacy columns (license/EO-certificate tracking, marketing dates, ASP.NET membership fields) exist physically but are never read or written by the CMS pages themselves, and are candidates for exclusion from a clean rebuild.

## Reading

This is a request to rebuild an internal, insurance-carrier staff tool that manages a
directory of distribution partners (brokerages and their brokers, agencies and their
agents, and CGAs), the underwriter assignments on each, and a shared follow-up/activity
log — while also showing (read-only) the policies tied to each partner, deep-linking out
to a separate policy-administration system that this project does not own or touch.

The request casts itself as **functional-parity migration**: reproduce every capability
of a specific legacy ASP.NET/VB.NET/SQL Server application, on a modern stack, while
fixing a list of named security and data-hygiene defects (SQL injection exposure,
hard-coded secrets, unenforced authorization, ad-hoc validation, a specific CGA insert
bug, and several data-typing inconsistencies) as first-class, non-optional requirements.

Critically, the source document's own target stack (Angular + Python + the *same*
SQL Server `PolicyPlus` database, migrated with a "no data migration required" claim
because the tables are reused verbatim) is **not** the stack this project has actually
committed to (`stack.md`: AWS, Node.js/TypeScript, PostgreSQL, React). That means the
functional requirements (what the system must do) transfer directly, but a chunk of the
"modernization goals" prose that assumes the legacy database stays in place (§2's parity
principle, all of §6's "preserved schema" framing, and MIG-1's "no migration required")
does **not** transfer as written and needs the project owner's explicit call — see
Clarifications below.

## Findings

| # | Class | Finding | Impact |
|---|-------|---------|--------|
| F1 | Conflict | The raw ask's target stack (Angular, Python REST API, Microsoft SQL Server reusing the existing `PolicyPlus` tables) conflicts with the project's already-decided stack (`stack.md`: AWS, Node.js/TypeScript, PostgreSQL, React, Lambda). | Functional requirements still apply; architecture (§4, §8), the "faithful parity" data-model framing (§6, §6.3 views), and MIG-1's "no migration" claim do not. Needs an explicit resolution — see Q1. |
| F2 | Conflict | AUTH-2 requires SSO capability against a corporate identity provider; `stack.md` records a self-issued JWT with no external identity provider. | Auth unit's requirements and interface contract cannot be written until this is resolved — see Q3. |
| F3 | Conflict | AUTH-4 requires sessions that "expire and can be revoked"; a self-issued, stateless JWT (per `stack.md`) cannot normally be revoked before its own expiry without added state (blocklist, refresh-token rotation, etc.). | Auth unit needs an explicit revocation mechanism and TTL — see Q4. |
| F4 | Gap | MIG-1 assumes zero data migration because the same SQL Server tables are reused. Since the datastore is now PostgreSQL, some migration is unavoidable, but its scope is undefined: exact schema mirror (carrying legacy quirks DR-1..DR-8 forward) vs. the clean domain model the SRS itself proposes in §6.5. | Determines the data-model capability's boundary and the migration unit's requirements — see Q1. |
| F5 | Gap | Related-policy data (FR-POL-1..4) is read from `PP_PolicyData`, which lives in the same legacy SQL Server database as everything else per `database-specification.md` §3.7. If Contact Management's own data moves to PostgreSQL, the mechanism for still reading that policy data (live cross-system call, replica/sync, or something else) is unstated. | Blocks the external-policy-integration capability's design and interface — see Q2. |
| F6 | Gap | No volume/scale figures anywhere in the source material — number of brokerages/agencies/CGAs/brokers/agents, concurrent staff users, or searches per day. NFR-PERF-1/2 give a latency target (~1s) with no load baseline. | Needed to size the serverless compute concurrency, PostgreSQL instance, and to write a testable NFR — see Q8. |
| F7 | Gap | No data-retention or residency requirement is stated for PII fields collected (FEIN, NPN, phone, email, address). | Needed to write the compliance NFR row and any data-lifecycle requirement — see Q9. |
| F8 | Gap | The SRS does not describe concurrent-edit handling for shared master records (two staff editing the same brokerage/agency at once). | Needed for the brokerage/agency update units' requirements — see Q10. |
| F9 | Ambiguity | FR-ACT-3 permits Editors to delete a contact-activity entry; NFR-AUD-1 requires every delete to be logged. Whether "delete" means the row is physically removed (audit log is the only remaining record) or soft-deleted/retained is not stated. | Affects the activity unit's data model — see Q6. |
| F10 | Ambiguity | `BAssignedUW` is a free-text column today (not a managed lookup); the "Assigned Underwriter" search filter (FR-SEARCH-2) is populated from distinct values currently in use, not from a maintained list. Whether the rebuild should promote Underwriter to a first-class managed reference entity is unstated. | Affects reference-data capability scope and the search filter's interface — see Q7. |
| F11 | Gap | The legacy address-autocomplete vendor (SmartyStreets US Autocomplete Pro) is named, but whether the rebuild keeps that vendor or picks a different one is not stated. | Affects the address-autocomplete capability's external dependency — see Q5. |
| F12 | Assumption | The legacy schema's own defects (CGA→wrong-table insert, `Phone` typed `float`, mixed `history` flag conventions, dual `Web_Accounts` insurer columns, mismatched `Agency_ID` types) are legacy-physical-schema artifacts. Since a new PostgreSQL schema is being authored rather than reusing the SQL Server tables verbatim, none of DR-1..DR-8 need be replicated as physical bugs — only their *domain intent* (e.g. "CGA phone is a string", "one boolean disabled/history flag") carries forward. Recorded as an assumption; PM must be able to object. | Simplifies the data-model capability considerably versus a literal parity read of §6.4/§6.5, assuming Q1 confirms a clean-schema rebuild. |
| F13 | Assumption | The Angular-specific frontend architecture (§8: routes, component tree, Angular reactive forms) does not transfer; only the underlying UX/interaction requirements it encodes (inline grid editing, role-driven UI, responsive/accessible layout, reusable address-autocomplete control) do, to be re-expressed against React. | Frontend units are scoped by the UX requirements, not the Angular component names in §8.2. |
| F14 | Out of scope | Creating/editing policies (owned by the external policy-administration system) — explicit in the raw ask. | Excluded from every capability in this project. |
| F15 | Out of scope | HR, DocumentRepos, and FileHandler subsystems — inherited legacy plumbing, confirmed by `database-specification.md` §2 as declared-but-unused connection strings. | Excluded; no capability should reference these databases. |
| F16 | Out of scope | Standard ASP.NET membership/profile/role providers (`ApplicationServices` connection) — confirmed unused; the legacy app actually authenticates against `web_accounts` plus AD/Forms auth. | Not carried into the rebuild; irrelevant to the new auth design given F2/F3 are already open. |

## Clarifications

| # | Question | Owner | Blocks | Status | Answer |
|---|----------|-------|--------|--------|--------|
| Q1 | Given the datastore is PostgreSQL (not the legacy SQL Server `PolicyPlus`), should the new schema be a clean redesign per the SRS's own §6.5 domain model (dropping legacy physical quirks), and does that require a one-time ETL migration of existing brokerage/agency/CGA/activity/policy-reference data at go-live? | @MithunAcx | decomposition of the data-model capability; the migration unit's requirements | answered | Clean redesign following the §6.5 domain model, plus a one-time ETL migration of existing legacy data at go-live. |
| Q2 | How does Contact Management obtain "related policy" data (FR-POL-1..4) once its own store is PostgreSQL, given that data lives in the legacy SQL-Server-based policy-administration system: a live read-only call to that system, a periodic sync/replica into Postgres, or something else? | @MithunAcx | decomposition of the external-policy-integration capability | answered | Live read-only call to the policy-administration system at request time; no replication of policy data into Postgres. |
| Q3 | Is SSO against the corporate identity provider (AUTH-2) genuinely out of scope for this build — i.e., staff get CMS-specific credentials via the self-issued JWT recorded in `stack.md` — or does the JWT need to sit behind/federate with the corporate IdP? | @MithunAcx | decomposition of the auth capability | answered | Out of scope. CMS issues its own JWT against CMS-specific credentials; no SSO/corporate-IdP federation in this build. |
| Q4 | What token/session TTL and revocation mechanism should the self-issued JWT auth use to satisfy AUTH-4 ("expire and can be revoked")? | @MithunAcx | the auth unit's requirements and interfaces | answered | Short-lived JWT access token plus a longer-lived, server-side-revocable refresh token; revocation = invalidating the refresh token. |
| Q5 | Should the rebuild continue with SmartyStreets for US address autocomplete, or select a different provider? | @MithunAcx | the address-autocomplete capability's external dependency | answered | Keep SmartyStreets. |
| Q6 | Is deleting a contact-activity entry (FR-ACT-3) a hard delete (row removed; the audit log is the only remaining record) or a soft delete (row retained/flagged)? | @MithunAcx | the activity-tracking unit's data model | answered | Soft delete — row retained with a deleted flag/timestamp; both the row and the audit log show history. |
| Q7 | Should "Assigned Underwriter" become a first-class managed reference entity (admin-maintained list with ids), or remain free text as in the legacy system? | @MithunAcx | reference-data capability scope; the search filter's interface | answered | Remain free text, as in the legacy system; the search filter is populated from distinct values in use. |
| Q8 | What are today's approximate volumes (brokerages, agencies, CGAs, brokers, agents, concurrent staff users, searches/day), and any known growth expectations? | @MithunAcx | NFR-PERF baselines; serverless-concurrency and database sizing | answered | Small scale: low hundreds of brokerages/agencies/CGAs, fewer than 50 concurrent staff users at peak. No specific growth figures given. |
| Q9 | Is there a specific data-retention period or residency requirement for the PII collected (FEIN, NPN, phone, email, address) beyond "keep while the record is active"? | @MithunAcx | the compliance NFR row | answered | No special retention or residency requirement beyond standard company data-handling policy while a record is active. |
| Q10 | Should concurrent edits to the same brokerage/agency master record be protected with optimistic concurrency control (reject a stale write), or is last-write-wins acceptable, matching legacy behavior? | @MithunAcx | the brokerage/agency update units' requirements | answered | Optimistic concurrency control — reject a save if the record changed since it was loaded. |

## Answers 2026-08-18

All ten clarifications (Q1–Q10) and assumptions A1–A3 were answered/acknowledged by
@MithunAcx in the same session. Answers are recorded in the Clarifications table above
and the Assumptions table below; verbatim summary:

- **Q1 (schema/migration):** clean redesign per §6.5's domain model + one-time ETL migration at go-live.
- **Q2 (policy data):** live read-only call to the policy-administration system; no replica in Postgres.
- **Q3 (SSO):** out of scope; CMS-specific credentials via self-issued JWT.
- **Q4 (JWT lifecycle):** short-lived access token + server-side-revocable refresh token.
- **Q5 (address vendor):** keep SmartyStreets.
- **Q6 (activity delete):** soft delete.
- **Q7 (underwriter entity):** stays free text, as in the legacy system.
- **Q8 (volumes):** small scale — low hundreds of brokerages/agencies/CGAs, <50 concurrent staff.
- **Q9 (PII retention):** no special requirement beyond standard company policy.
- **Q10 (concurrency):** optimistic concurrency control on shared master records.
- **A1–A3:** all acknowledged as stated.

This moves the project boundary in one place: Contact Management now explicitly
**consumes** the external policy-administration system via a live read-only call (not a
data sync), which is reflected in `project.md`'s Context section.

## Candidate outcomes

| # | Outcome | Baseline | Target | How measured |
|---|---------|----------|--------|--------------|
| O1 | Full functional parity with the legacy CMS | 12 legacy capabilities enumerated in the traceability matrix (§12) | All 12 reproduced and independently verified against the new system | Traceability check: every legacy capability maps to ≥1 delivered requirement, each with a passing acceptance test |
| O2 | SQL-injection surface eliminated | 100% of legacy search/add/update/login paths built by string-concatenating user input (G1) | 0% — all data access parameterized or via an ORM | Static/code review of every data-access path; zero string-concatenated SQL from user input |
| O3 | No hard-coded secrets or environment-specific values in source | SmartyStreets credentials and SQL host hard-coded (G2); server names, UNC paths, magic producer id, environment URLs hard-coded (G4) | 100% of secrets/endpoints in secure configuration or a secret store | Code review + secret-scanning check in CI |
| O4 | Server-side RBAC enforced on every mutating endpoint | Authentication exists in the legacy system; authorization is essentially unused | 100% of mutating endpoints declare and enforce a minimum role, independent of the UI | Endpoint-by-endpoint audit against the role table in §3.3 |
| O5 | Search responsiveness | Unmeasured in the legacy system | First results within ~1s for typical datasets (NFR-PERF-1) | Load-test measurement against a representative dataset (size to be set once Q8 is answered) |
| O6 | Complete audit trail for all mutations | No audit log in the legacy system | 100% of create/update/delete operations recorded with actor, timestamp, entity, and action | Audit-log completeness check against a sample of mutating operations |

## Candidate non-functional requirements

| Category | Expectation | Source |
|---|---|---|
| Security | All data access parameterized/ORM; no dynamic SQL from user input | G1, NFR-SEC-1 |
| Security | Secrets/endpoints externalized to secure configuration or a secret store | G2, G4, NFR-SEC-2 |
| Security | Authorization enforced server-side on every mutating endpoint | G3, NFR-SEC-3 |
| Security | HTTPS/TLS everywhere; CSRF/XSS/security-header protections; CORS restricted to the SPA/frontend origin | NFR-SEC-4 |
| Security | Server-side input validation and normalization before persistence | G5, NFR-SEC-5 |
| Validation | Centralized phone/zip/email/FEIN/date validators and normalizers | NFR-VAL-1, NFR-VAL-2 |
| Performance | Search first-results and detail-screen-load latency budgets | NFR-PERF-1, NFR-PERF-2 |
| Auditability | Every create/update/delete logged with actor/timestamp/entity/action | AUTHZ-4, NFR-AUD-1 |
| Auditability | Activity records retain a server-derived `UsrName`-equivalent stamp | AUTHZ-2, NFR-AUD-2 |
| Logging | Structured application logging; no silently swallowed exceptions | G7, NFR-LOG-1 |
| Configurability | All environment-specific values in configuration, none in code | G4, NFR-CFG-1, NFR-CFG-2 |
| Accessibility | WCAG 2.1 AA — keyboard nav, focus management, ARIA labels, contrast in both themes | NFR-A11Y-1 |
| Browser support | Latest evergreen browsers; responsive to ~360px | NFR-BROWSER-1 |
| Maintainability | Clean layering (presentation / API / service / repository); shared services eliminate per-entity-type duplication; unit/integration/e2e test coverage | G6, G9, NFR-MAINT-1..3 |
| Auth lifecycle *(new — implicit)* | Token/session TTL and a revocation mechanism compatible with a self-issued JWT (no external IdP to delegate revocation to) | Derived from AUTH-4 vs. `stack.md`'s auth choice — see Q4 |
| Data lifecycle *(new — implicit)* | Retention/residency policy for PII fields (FEIN, NPN, phone, email, address) | Derived from the presence of regulated-adjacent PII with no stated policy — see Q9 |
| Concurrency *(new — implicit)* | A stated concurrency-control policy (optimistic locking or accepted last-write-wins) for shared master records | Derived from absence of any stated behavior — see Q10 |

## Assumptions

| # | Assumption | Acknowledged by |
|---|------------|-----------------|
| A1 | The new PostgreSQL schema will be a clean redesign following the SRS's own §6.5 domain model, not a column-for-column mirror of the legacy SQL Server tables — so DR-1..DR-8's *physical* bugs (float phone column, mixed history-flag types, wrong-table CGA insert, dual insurer columns, mismatched id types) do not need to be reproduced or fixed in place; only their domain intent carries forward. | @MithunAcx, 2026-08-18 (via Q1) |
| A2 | The Angular-specific frontend architecture in §8 (routes, component names, Angular reactive forms) is superseded by the React/Vite/TypeScript stack decision; only the UX/interaction requirements it encodes carry forward. | @MithunAcx, 2026-08-18 |
| A3 | The five unused legacy database connections (`DocumentRepos`, `FH`, `HR`, `PolicyTransactions2`, `ApplicationServices`) and the standard ASP.NET membership schema are dropped entirely, per `database-specification.md`'s own recommendation. | @MithunAcx, 2026-08-18 |

## Out of scope

- Creating or editing policies — owned by the external policy-administration system (explicit in the raw ask, §1.2).
- The HR subsystem — inherited legacy plumbing, confirmed unused by the CMS (database-specification.md §2).
- The FileHandler (`FH`) and DocumentRepos subsystems — inherited legacy plumbing, confirmed unused by the CMS (database-specification.md §2).
- The `PolicyTransactions2` database — inherited legacy plumbing, confirmed unused by the CMS (database-specification.md §2).
- Standard ASP.NET membership/profile/role providers (`ApplicationServices`) — configured but non-functional in the legacy system; the CMS actually authenticates via `web_accounts` (database-specification.md §8).

## READY verdict

**READY** — all ten clarifications (Q1–Q10) are answered by the project owner and all
three assumptions (A1–A3) are explicitly acknowledged. Outstanding: none. `Q8`'s volume
figure is a rough order of magnitude ("small scale") rather than an exact count — this is
sufficient to write a testable NFR-PERF baseline and is not a blocker; a precise figure
can be supplied later without re-opening intake. `ba-capability-split` may proceed.
