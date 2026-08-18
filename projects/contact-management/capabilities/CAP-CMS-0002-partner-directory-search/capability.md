---
id: CAP-CMS-0002
slug: partner-directory-search
project: CMS
title: Partner Directory & Search
status: decomposed
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Partner Directory & Search

## Original ask

> The Directory screen is the hub. The user types a term, selects one search mode, and runs the search; matches render in a results list where each row deep-links to the appropriate detail screen.
>
> **FR-SEARCH-1** — The system shall support six mutually exclusive search modes:
>
> | Mode | Matches on | Result columns | Row opens |
> |---|---|---|---|
> | **By Brokerage** | brokerage name contains term | Brokerage, Address (city/state/zip), Assigned UW, State | Brokerage Detail |
> | **By Broker** | broker person name contains term | First, Last, Brokerage, Title/Type, Email (mailto), Disabled flag | Brokerage Detail (of that broker's brokerage) |
> | **By State (Broker)** | brokerage state | same as By Brokerage | Brokerage Detail |
> | **By Agency** | agency + address text contains term | Agency, Address, Agent | Agency Detail |
> | **By CGA** | CGA agent name or address | CGA Agent, Address | CGA Detail |
> | **By State (Agent)** | agency/agent state | Agency, Address, Agent | Agency Detail |
>
> **FR-SEARCH-2** — The system shall provide an **Assigned Underwriter** filter — a dropdown populated with the underwriters currently assigned to at least one brokerage. Selecting one immediately lists that underwriter's brokerages.
>
> **FR-SEARCH-3** — The system shall require a non-empty search term before running a name/keyword search, showing an inline validation message when empty. (State/UW modes may run without a free-text term.)
>
> **FR-SEARCH-4** — Each result set shall show a clear "No records to display" empty state, and shall show a result count.
>
> **FR-SEARCH-5** — The Broker results shall render email as a `mailto:` link and show an Active/Disabled status indicator.
>
> **FR-SEARCH-6** — From the Directory the user shall be able to launch **Add New Agency** and **Add New Brokerage**.
>
> **FR-SEARCH-7** — Results shall be paginated or virtualized for large result sets, with server-side filtering (search executes on the API, not the client).
>
> **FR-SEARCH-8** — The results view shall be responsive: a table on desktop and stacked cards on mobile.
>
> **FR-AUTH-4** — The application landing route shall be the **Directory / Search** screen; the root path redirects there (replacing the legacy `Default.aspx → brokerage.aspx` redirect).
>
> **NFR-PERF-1** — Search returns first results within ~1s for typical datasets; large sets are paginated/virtualized server-side.
>
> **API-1** — Pagination via `page`/`size`; responses include total count and page metadata.
>
> Appendix A — Search-mode behavior (detail):
>
> | Mode | Term required? | Backing read model | Notes |
> |---|---|---|---|
> | By Brokerage | Yes | `PPV_BrokerSelect` | name contains term |
> | By Broker | Yes | `ppv_brokerqq` | person name contains term; row → brokerage detail |
> | By State (Broker) | No (state instead) | `PPV_BrokerSelect` | filter by state |
> | By Agency | Yes | `PPV_AgencySelect` | agency + address text |
> | By CGA | Yes | `PP_Agency_CGA` | agent name or address |
> | By State (Agent) | No (state instead) | `PPV_AgencySelect` | filter by state |
> | Assigned-UW filter | No | brokerage/UW list | immediate list on select |
>
> `BAssignedUW` is a free-text column (not a managed lookup); the search UW filter is populated from distinct values currently in use, not from a maintained list (intake Q7 — confirmed to remain free text).

## Outcome measures

| # | Measure | Baseline | Target | How measured | From |
|---|---------|----------|--------|--------------|------|
| M1 | Search first-results latency for a typical dataset | Legacy: unmeasured | First results returned within ~1s for a typical dataset at the confirmed small-scale volume (low hundreds of brokerages/agencies/CGAs, <50 concurrent staff — intake Q8) | Load-test measurement against a representative seeded dataset sized to Q8's figures | intake O5 |

## Outcome-level acceptance

- A1. All six search modes (By Brokerage, By Broker, By State (Broker), By Agency, By CGA, By State (Agent)) return correct result sets matching the legacy backing-read-model semantics in Appendix A, verified against representative test data.
- A2. The Assigned Underwriter filter lists every underwriter currently assigned to ≥1 brokerage and, on selection, returns exactly that underwriter's brokerages.
- A3. Search executes server-side (results are paginated/virtualized via the API, not filtered client-side), and M1's latency target holds under the confirmed volume.

## Non-goals

- Creating or editing brokerages, agencies, brokers, agents, or CGAs — this capability only finds and routes to them; record CRUD is CAP-CMS-0003 (Partner Records Management). "Add New Agency" / "Add New Brokerage" (FR-SEARCH-6) are launch points only — the dialogs and their persistence belong to CAP-CMS-0003.
- Promoting "Assigned Underwriter" to a managed reference entity — confirmed to stay free text (intake Q7); if that ever changes it is a change request against this capability's FR-SEARCH-2 and CAP-CMS-0003's reference-data scope together.
- Contact-activity or policy display for a found partner — this capability's job ends at opening the correct detail screen; what that screen shows belongs to CAP-CMS-0003, CAP-CMS-0004, and CAP-CMS-0005 respectively.

## Constraints

| Constraint | Source | Effect |
|---|---|---|
| Small-scale volume: low hundreds of brokerages/agencies/CGAs, <50 concurrent staff at peak | intake Q8 | Sets the load-test baseline for M1; sizing is not "hundreds of thousands of records" |
| Serverless compute (cold starts) | `stack.md` | The ~1s NFR-PERF-1 budget must account for cold-start behavior on the search endpoint, not assume an always-warm instance |
| PostgreSQL row-level security for tenant isolation | `stack.md` | Every search query must run under the RLS policy — a query that bypasses it to hit a latency target is not an acceptable trade |

## Decomposition rationale

Partner Directory & Search is split from Partner Records Management even though both
concern the same underlying entities, because "finding a partner" and "maintaining a
partner's record" are independently acceptable outcomes: search can be measured and
accepted purely on correctness and latency (six modes, ~1s first-results) without any
brokerage/agency/CGA field ever being edited, and record management can be measured purely
on CRUD completeness without touching search ranking or read-model performance. Folding
search into Partner Records Management was considered and rejected — it would make a
capability meant to be measured on data-model completeness also carry a latency NFR that
has nothing to do with data correctness, diluting both outcome measures. The alternative
of splitting search further, by search mode, was also rejected: all six modes share one
UI (the Directory screen), one underwriter filter, and one measurable latency target, so
splitting them apart would produce six capabilities with no independent business meaning.

## Dependencies

| Direction | What | Why |
|---|---|---|
| upstream | Identity & Access Control (CAP-CMS-0001) | Every search endpoint requires an authenticated Viewer-or-above request |
| upstream | Partner Records Management (CAP-CMS-0003) | This capability's search reads CAP-CMS-0003's brokerage/agency/CGA data read-only (capability-design XD-0002) — it depends on that schema existing, and cannot search records that capability hasn't defined. Search results also deep-link into detail screens owned there, and "Add New Agency"/"Add New Brokerage" launch that capability's create flow. |

## Open questions

| # | Question | Owner | Status |
|---|----------|-------|--------|

<!-- GENERATED:units — do not hand-edit below. Written by pm-state-rollup. -->
## Units

| Unit | Title | Kind | Target repo | Status | Since |
|------|-------|------|--------------|--------|-------|
| UNIT-CMS-0003 | Partner Search API | backend | CMS-partner-directory-search | draft | 2026-08-18 |
| UNIT-CMS-0004 | Partner Directory UI | frontend | CMS-web | draft | 2026-08-18 |

<!-- /GENERATED:units -->
