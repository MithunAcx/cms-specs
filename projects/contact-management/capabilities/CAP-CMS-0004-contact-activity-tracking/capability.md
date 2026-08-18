---
id: CAP-CMS-0004
slug: contact-activity-tracking
project: CMS
title: Contact Activity & Follow-up Tracking
status: decomposed
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# Contact Activity & Follow-up Tracking

## Original ask

> - Log, edit, and delete contact activity / follow-ups against agencies and brokerages.
>
> **FR-ACT-1** — Across agencies and brokerages the system shall maintain a running activity log so staff can track outreach and follow-ups.
>
> **FR-ACT-2** — For each entry the system shall capture: task type/status (controlled list scoped to the entity type, i.e. `TskType_ID = 2`), date entered, free-text note, follow-up (FU) date, a completed indicator with auto-set completion date, and the acting user's username.
>
> **FR-ACT-3** — Entries can be added, edited, and deleted (delete gated to Editor+).
>
> **FR-ACT-4** — Marking an entry complete shall set the completion date server-side to the current timestamp.
>
> **FR-ACT-5** — The follow-up date and completed flag together shall support a "what is owed this partner next" workflow (e.g. sortable/filterable by follow-up date and open/closed state).
>
> From the Brokerage/Agency Detail screens (owned by CAP-CMS-0003): a **Contact-activity grid** — list, add, edit, and delete activity (task type/status, follow-up date, note, entered date, completed flag); new entries stamped with the logged-in user.
>
> **AUTHZ-2** — Activity entries are always stamped with the acting user's username (`UsrName`); this stamp is server-derived and not client-supplied.
>
> **NFR-AUD-2** — Activity records retain the `UsrName` stamp (server-derived) as the legacy system did.
>
> `PP_TskData` is polymorphic — the same table stores both agency activity (via
> `Agency_id`) and brokerage activity (via `Brokerage_id`). The clean domain model exposes
> this as one `Activity { id, parentType(agency|brokerage), parentId, statusId, note,
> followUpDate, enteredDate, completed, completedDate, userName(readonly) }` resource.
>
> Deleting an activity entry is a **soft delete** — the row is retained with a deleted
> flag/timestamp; both the row and the audit log show history (intake Q6).

## Outcome measures

| # | Measure | Baseline | Target | How measured | From |
|---|---------|----------|--------|--------------|------|
| M1 | Activity records carrying a server-derived, client-unsuppliable `UsrName`/actor stamp | Legacy: `UsrName` stamped on insert, but never validated as server-derived — a client-supplied value was structurally possible | 100% of activity create/update operations carry a `UsrName` set by the server from the authenticated request, with zero code paths accepting a client-supplied value | Code review of every activity write path, plus a contract test asserting a client-supplied `UsrName` is ignored/rejected | raw ask AUTHZ-2/NFR-AUD-2 directly — not a numbered intake `O<n>`; this capability's own audit-log-entry production (previously double-counted here) is CAP-CMS-0001/M3's measure, not a separate claim of this capability's — see Open questions |

## Outcome-level acceptance

- A1. Every activity entry created, edited, or soft-deleted carries a server-derived username — no client-supplied `UsrName` is ever accepted (API-4).
- A2. Marking an entry complete sets its completion date server-side to the current timestamp; no client-supplied completion date is accepted.
- A3. A "what's owed next" view can sort/filter activity by follow-up date and open/closed (completed) state, across both agency and brokerage parents.
- A4. Deleting an activity entry soft-deletes it — the row is retained with a deleted flag/timestamp, not physically removed.

## Non-goals

- Which entity (brokerage or agency) an activity entry is attached to, and that entity's own lifecycle — owned by CAP-CMS-0003 (Partner Records Management); this capability owns the activity log itself, not its parent.
- The task-type/status controlled list's maintenance — owned by CAP-CMS-0003's reference-lookup scope (FR-REF-1/2); this capability only consumes `TskType_ID = 2` values.
- Policy activity — despite the similar "grid on the detail screen" shape, policy display is read-only reference data owned by CAP-CMS-0005 (External Integrations), not an activity log entry.
- Hard-deleting activity data for any reason (e.g. GDPR-style erasure) — out of scope; intake Q9 found no special retention/erasure requirement, and Q6 confirmed soft delete only.

## Constraints

| Constraint | Source | Effect |
|---|---|---|
| Soft delete only | intake Q6 | The activity schema needs a deleted-flag/timestamp column; no hard-delete code path is acceptable |
| No special PII retention/residency requirement | intake Q9 | Notes and follow-up data need no bespoke retention design beyond standard policy |
| PostgreSQL row-level security for tenant isolation | `stack.md` | The activity table needs its own RLS policy, scoped consistently with its parent brokerage/agency |

## Decomposition rationale

Contact activity is split out from Partner Records Management even though it is displayed
embedded in that capability's Brokerage/Agency Detail screens, because it is a genuinely
independent business capability: "track outreach and follow-ups with a partner" has its
own measurable outcome (audit-trail completeness, a working "what's owed next" view) that
does not require touching a single brokerage or agency field, and — per the raw ask's own
data model — the same activity log spans two different parent types (agency and
brokerage), which is itself evidence it is not naturally *part of* either parent's record.
Folding activity into Partner Records Management was rejected because it would tie a
polymorphic, audit-focused log to a capability whose acceptance criteria are about
record-field completeness, diluting both. Splitting activity into two capabilities — one
for agency activity, one for brokerage activity — was also rejected: they share one
schema, one soft-delete rule, and one audit outcome; the only difference is which parent
column is set, which is an implementation detail, not a capability boundary.

## Dependencies

| Direction | What | Why |
|---|---|---|
| upstream | Identity & Access Control (CAP-CMS-0001) | Editor role required to create/edit/delete; every mutation's audit-log entry lands in that capability's audit trail |
| upstream | Partner Records Management (CAP-CMS-0003) | Every activity entry must reference an existing brokerage or agency record owned there |
| downstream | Legacy Data Migration (CAP-CMS-0006) | That capability migrates existing activity records into this capability's schema, including its soft-delete convention (XD-0002 of this capability's design) |

## Open questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | Resolved 2026-08-18, recorded for history: M1 previously restated CAP-CMS-0001/M3's system-wide audit-log-entry claim for the Activity entity specifically, duplicating that promise. Reconciled per pm-spec-review (PR #2 and #5 findings): M1 is now scoped to the UsrName-stamp fact alone; the audit-log-entry claim belongs solely to CAP-CMS-0001/M3, which now correctly cites intake O6. | @MithunAcx | resolved |

<!-- GENERATED:units — do not hand-edit below. Written by pm-state-rollup. -->
## Units

| Unit | Title | Kind | Target repo | Status | Since |
|------|-------|------|--------------|--------|-------|
| UNIT-CMS-0007 | Activity API | backend | CMS-contact-activity-tracking | draft | 2026-08-18 |
| UNIT-CMS-0008 | Activity Grid UI | frontend | CMS-web | draft | 2026-08-18 |

<!-- /GENERATED:units -->
