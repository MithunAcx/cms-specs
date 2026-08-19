---
id: UNIT-CMS-0006
slug: partner-records-ui
project: CMS
capability: CAP-CMS-0003
title: Partner Records UI
kind: frontend
target_repo: CMS-web
owner: "@MithunAcx"
engineering:
  frontend: { applicable: true }
  api:      { applicable: false }
created: 2026-08-18
updated: 2026-08-18
---

# Partner Records UI

## Scope

Brokerage/Agency Detail screens (tabs for master details, brokers/agents grid,
accounting address), the CGA management grid, and the reference-lookup admin screens.
Embeds UNIT-CMS-0008's activity grid and calls UNIT-CMS-0009/0010's address-suggest and
policy-read contracts directly on these same screens. Consumes UNIT-CMS-0005's full
CRUD contract as a closed shape.

**In scope:**
- Brokerage/Agency Detail screens, CGA grid, accounting-address dialog, reference-lookup admin screens
- Inline add/edit for brokers/agents; optimistic-concurrency conflict handling in the UI
- Embedding UNIT-CMS-0008's activity grid and UNIT-CMS-0009/0010's address-suggest/policy-read widgets on these screens
- The "Add New Agency"/"Add New Brokerage" create forms themselves (launched by UNIT-CMS-0004)

**Out of scope:**
- Record CRUD logic, validation, or persistence (UNIT-CMS-0005)
- Search/discovery landing (UNIT-CMS-0004)
- The activity grid's own logic (UNIT-CMS-0008) and the address-suggest/policy-read logic (UNIT-CMS-0009/0010) — this unit only embeds those components

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | The Add New Brokerage form captures: brokerage name, address, city, state, zip, phone, fax, tax id (FEIN), assigned underwriter, status (from the broker-status lookup), contract-received date, and history flag. | CAP-CMS-0003/M1 (FR-BRK-1) | Must |
| R2 | The address fields on the Add New Brokerage form are assisted by UNIT-CMS-0009's US address-suggest widget; accepting a suggestion fills line1, line2, city, state, and zip in the XD-0004 shape without a further round trip. | CAP-CMS-0003/M1 (FR-BRK-3) | Must |
| R3 | On successful save of a new brokerage, the UI navigates the user to that brokerage's Detail screen. | CAP-CMS-0003/M1 (FR-BRK-2) | Must |
| R4 | A Cancel action on the Add New Brokerage form discards entered data and returns the user to the Directory without calling the create endpoint. | CAP-CMS-0003/M1 (FR-BRK-3) | Must |
| R5 | The Brokerage Detail screen's master-details panel displays and allows editing of: name, address, city, state, zip, phone, fax, tax id, assigned underwriter, status, contract-received date, and history flag. | CAP-CMS-0003/M1 (FR-BRK-4) | Must |
| R6 | Phone and fax fields on the Brokerage Detail screen display in `(nnn) nnn-nnnn` form; on save the UI sends the digits-only normalized value UNIT-CMS-0005 expects. | CAP-CMS-0003/M1 (FR-BRK-5, NFR-VAL-1) | Must |
| R7 | The Brokerage Detail screen displays the ePay/AccountCode field read-only; no control on the screen allows editing it. | CAP-CMS-0003/M1 (FR-BRK-5) | Must |
| R8 | Saving an edited brokerage shows a success confirmation once UNIT-CMS-0005 returns 200, and leaves the user on the same Detail screen with the updated values displayed. | CAP-CMS-0003/M1 (FR-BRK-6) | Must |
| R9 | The Brokerage Detail screen presents a Brokers grid listing every broker on the brokerage, supporting inline add and inline edit of first name, last name, broker type/title (from the broker-type lookup), email, NPN, and disabled flag. | CAP-CMS-0003/M1 (FR-BRK-7) | Must |
| R10 | The Brokerage Detail screen embeds UNIT-CMS-0008's Contact-activity grid and UNIT-CMS-0010's Policy-activity grid as separate tabs or panels, passing the brokerage id as the sole linking context. | CAP-CMS-0003/M1 (FR-BRK-7) | Must |
| R11 | The Brokerage Detail screen provides a control that opens the accounting/billing address dialog, and a control that navigates back to the Directory. | CAP-CMS-0003/M1 (FR-BRK-8) | Must |
| R12 | The accounting/billing address dialog captures contact name, address, city, state, zip for the brokerage; saving it updates only the brokerage's accounting fields and leaves the master-details fields untouched. | CAP-CMS-0003/M1 (FR-BRK-9) | Must |
| R13 | The Add New Agency form captures: agency name, address, city, state, zip, phone, agency number, and a Premium Financing flag. | CAP-CMS-0003/M1 (FR-AGY-1) | Must |
| R14 | The address fields on the Add New Agency form use the same UNIT-CMS-0009 address-suggest widget as R2. | CAP-CMS-0003/M1 (FR-AGY-3) | Must |
| R15 | On successful save of a new agency, the UI presents a confirmation dialog offering exactly two choices: go to that agency's Detail screen, or add another agency (which resets the form and keeps the user on it). | CAP-CMS-0003/M1 (FR-AGY-2) | Must |
| R16 | The Agency Detail screen's master-details panel displays and allows editing of: name, address, city, state, zip, phone, billing contact, billing contact phone, notes, agency number ("G1 Agency ID"), and the High Potential, Premium Financing, and History flags. | CAP-CMS-0003/M1 (FR-AGY-4) | Must |
| R17 | Phone fields on the Agency Detail screen are normalized (punctuation stripped) before being sent on save. | CAP-CMS-0003/M1 (FR-AGY-5, NFR-VAL-1) | Must |
| R18 | The Agency Detail screen presents an Agents grid listing every agent on the agency, supporting inline add and inline edit of first name, last name, agent type/title (from the agent-type lookup), phone, email, NPN, and history flag. | CAP-CMS-0003/M1 (FR-AGY-6) | Must |
| R19 | The Agency Detail screen embeds UNIT-CMS-0008's Contact-activity grid and UNIT-CMS-0010's Policy-activity grid, passing the agency id as the sole linking context. | CAP-CMS-0003/M1 (FR-AGY-6) | Must |
| R20 | The Agency Detail screen provides navigation to the Specialty area, shown only when the current user's role includes access to it, and a control that returns to the Directory. | CAP-CMS-0003/M1 (FR-AGY-7) | Must |
| R21 | The CGA screen presents a grid keyed by CGA id, supporting inline add and inline edit of: agent name, address, city, state, zip, email, phone, and associated agency id. | CAP-CMS-0003/M1 (FR-CGA-1) | Must |
| R22 | Address entry on a CGA row uses the UNIT-CMS-0009 address-suggest widget, filling city, state, and zip for that row on acceptance. | CAP-CMS-0003/M1 (FR-CGA-2) | Must |
| R23 | The CGA phone field is edited and displayed as a formatted string end-to-end; the UI never coerces it to a number. | CAP-CMS-0003/M1 (FR-CGA-4) | Must |
| R24 | A back action on the CGA screen returns the user to the Directory. | CAP-CMS-0003/M1 (FR-CGA-4) | Must |
| R25 | The reference-lookup admin screens let a user with the Administrator role view and edit the values of: US states, broker types, agent types, broker statuses, and task/activity statuses. | CAP-CMS-0003/M1 (FR-REF-2) | Must |
| R26 | Every other role sees the reference-lookup screens read-only: list values are visible but no add, edit, or delete control is rendered. | CAP-CMS-0003/M1 (FR-REF-2) | Must |
| R27 | Every dropdown sourced from a reference lookup (states, broker types, agent types, broker statuses, task/activity statuses) on any screen in this unit is populated from UNIT-CMS-0005's lookup endpoints, not a hardcoded list. | CAP-CMS-0003/M1 (FR-REF-1) | Must |
| R28 | Every form field in this unit that UNIT-CMS-0005 marks required is enforced as required client-side before the request is sent, mirroring NFR-VAL-2, and the server's own rejection is still surfaced if it disagrees. | CAP-CMS-0003/A1 (NFR-VAL-2) | Must |
| R29 | Client-side validation formats and checks phone, zip, email, FEIN, and date fields using the same rules as UNIT-CMS-0005's validators (NFR-VAL-1), so a value that will be rejected server-side is flagged before submission. | CAP-CMS-0003/A1 (NFR-VAL-1) | Must |
| R30 | Every screen in this unit that reads or writes a brokerage/agency/CGA/broker/agent record carries and submits that record's `version` value unchanged from the value it was loaded with (XD-0002); the UI never fabricates or bumps this value itself. | CAP-CMS-0003/A3 | Must |

## Behaviour detail

**R2/R14/R22 — address-suggest widget contract.** The widget is UNIT-CMS-0009's; this
unit only wires its accept-suggestion callback to fill the local form/row state in the
`{ line1, line2, city, state, zip }` shape (XD-0004). If the widget is unavailable
(see R34), address fields remain free-text and R28's required-field check still applies
to whichever of them the brokerage/agency/CGA form requires.

**R9/R18/R21 — inline grid add/edit.** Each grid row supports an explicit Edit action
that switches that row into an editable state; other rows remain read-only. Saving a
row calls the corresponding UNIT-CMS-0005 create/update endpoint for that child entity
only — the parent brokerage/agency/CGA record is not re-submitted.

**R15 — two-choice confirmation.** "Add another agency" clears every field back to its
initial empty state and returns focus to the first field (agency name); it does not
navigate away from the Add New Agency screen.

**R30 / R31 (conflict) — concurrency UI.** See R31 in the failure-surface table below
for the observable behaviour when the version submitted is stale.

## Failure surface (nine-class sweep)

Applied against the create/edit/save happy-path requirements above (R1, R5, R8, R9,
R13, R16, R18, R21, R25).

| R-ID | Class | Case | Required behaviour |
|------|-------|------|---------------------|
| R31 | concurrency | Save submitted with a `version` UNIT-CMS-0005 no longer considers current | UI shows a distinguishable "this record changed since you loaded it" message (mapped from `409 conflict_version_mismatch`), does not overwrite the user's unsaved edits, and offers an explicit reload-and-retry action rather than silently discarding either side. |
| R32 | input | Required field left absent, or a field's client-side check (R29) fails | Save is blocked before the request is sent; the offending field is identified inline, not only in a summary banner. |
| R33 | input | Server rejects a value the client-side check passed (`400` validation) | The server's `error.fields` entries are mapped back onto the matching form fields; a field the server flagged that has no matching client field is shown in a general error area, never dropped silently. |
| R34 | dependency | UNIT-CMS-0009's address-suggest widget is down, slow, or returns an error | Address fields degrade to plain free-text entry; the form remains fully usable and R28's required-field check still applies to whichever address fields the record type requires. |
| R35 | dependency | UNIT-CMS-0010's Policy-activity grid or UNIT-CMS-0008's Contact-activity grid fails to load on Brokerage/Agency Detail | The failing panel shows its own inline error and retry control; the rest of the Detail screen (master details, Brokers/Agents grid) remains usable. |
| R36 | dependency | UNIT-CMS-0005 is down, slow, or times out on any read (e.g. loading Brokerage/Agency Detail, a grid, or a lookup) | The screen shows a distinguishable "unable to load" state with a retry control; a timeout is never presented as "not found" or as a validation rejection, and never silently retried more than once automatically. |
| R37 | dependency | UNIT-CMS-0005 is down, slow, or times out on a save | The save is reported as unresolved (not as failed and not as succeeded); no local state is updated to reflect a completion that was not confirmed, and the user is not blocked from retrying once. |
| R38 | repetition | User double-submits a create (double-click, or resubmits after a slow response) | The create control is disabled between submission and response/error so a second create request for the same intended record cannot be sent from the same form instance. |
| R39 | authorization | Current session lacks the role required for an action shown elsewhere in this unit (e.g. Administrator-only lookup edit, Editor-only create/edit) | The control is not rendered for that role, rather than rendered and rejected on click; this applies to R9/R18/R21 grid edit actions and R25/R26's lookup admin controls alike. |
| R40 | authorization | A save that was permitted when the form opened is rejected as forbidden by the time it is submitted (session/role changed mid-edit) | The UI shows a distinguishable "not permitted" message and does not present it as a validation or conflict error. |
| R41 | state | User attempts to edit a brokerage, agency, or record marked `disabled` (history) | Edit controls remain available (history is a status flag, not a lock, per XD-0003) unless UNIT-CMS-0005 itself rejects the write, in which case R33 applies. |
| R42 | time | The contract-received date (R1) or any date field is entered at a timezone/DST boundary | Dates are entered and displayed as date-only values (per the platform date-only rule) and are never silently coerced to a timestamp or shifted by the browser's local timezone. |

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R43 | availability | This unit has no server-side availability target of its own; it is available whenever the static assets are served, and every screen's functional availability is bounded by UNIT-CMS-0005's target (see that unit's own NFR row). N/A beyond that — no independent SLO to state here. |
| R44 | latency | Each screen's initial data (Detail load, grid load, lookup population) renders within p95 1.5s / p99 3s of the underlying UNIT-CMS-0005 call resolving, consistent with the serverless cold-start consequence recorded in `stack.md`; this is the promptness the M1 usability comparison against the legacy screens depends on. |
| R45 | throughput | Peak concurrent users bounded by the "low hundreds of brokerages/agencies/CGAs" volume noted in `capability.md` Constraints (intake Q8) — estimated low tens of concurrent editors, not independently sized; no dedicated client-side throughput control is required. |
| R46 | surge | N/A — this unit issues no batched or high-volume requests of its own; surge shedding, if any, is UNIT-CMS-0005's and the API Gateway throttling layer's concern (per `stack.md`), surfaced to this UI only as a `429` the UI must display (see R47). |
| R47 | rate limits | A `429` response from any UNIT-CMS-0005 call is shown as a distinguishable "too many requests, try again shortly" state honoring the `Retry-After` value from `stack.md`'s API Gateway throttling layer, rather than as a validation or generic error. |
| R48 | idempotency | This unit issues no idempotency keys of its own; `POST` creates (R1, R9, R13, R18, R21) are non-idempotent per the capability's Unified API Contract, and R38 is the control that prevents an accidental duplicate `POST` from the same form. |
| R49 | concurrency | Two browser tabs or sessions editing the same brokerage/agency/CGA/broker/agent record must both be able to load the record; whichever saves first succeeds and the second observes R31's conflict behaviour — this unit performs no client-side locking or reservation of a record being edited. |
| R50 | authorization | Every create/edit control in this unit requires the Editor role; reference-lookup add/edit/delete controls (R25) require the Administrator role; a Viewer-role session sees every screen in this unit read-only. Enforcement is UNIT-CMS-0005's; this unit's own obligation is R39/R40 — never render or claim success for an action the session cannot perform. |
| R51 | tenant isolation | This unit holds no tenant-scoped state of its own; every read and write is scoped by the session's tenant purely by virtue of calling UNIT-CMS-0005's tenant-scoped endpoints, and no request in this unit ever accepts or forwards a tenant identifier supplied by the UI itself. |
| R52 | audit | This unit produces no audit record of its own; every mutating action it initiates is audited by UNIT-CMS-0005 against the same request. N/A beyond that. |
| R53 | observability | Every failed load or save in this unit emits one structured client-side log entry carrying: the screen/action identifier, the HTTP status or error code returned, and the `trace_id` from the error envelope — no personal data (name, address, tax id, phone, email, NPN) appears in any such log entry. |
| R54 | data classification | This unit stores no persistent data of its own; the personal data it displays and edits transiently in-browser (brokerage/agency/CGA/broker/agent name, address, phone, email, tax id, NPN) is neither special-category nor exempt from the standard handling — it must not appear in any client-side log, analytics event, or error message beyond the trace_id-only shape in R53. |
| R55 | retention and deletion | N/A — this unit holds no persistent client-side or server-side store; retention and erasure are UNIT-CMS-0005's obligations against the records it owns. |
| R56 | migration and backfill | N/A — greenfield UI, no prior version of this screen set to migrate from within this system; no capability outcome depends on this row. |
| R57 | feature flag | No feature flag is required by any stated requirement; N/A. If one is introduced later, its off-state must fall back to the pre-existing screen rather than an unusable blank state, and no in-flight inline-grid edit (R9/R18/R21) may be discarded silently when it is switched off. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Brokerage, Broker, Agency, Agent, Cga | Read/edited via UNIT-CMS-0005 | This unit persists nothing; every field shown or edited round-trips through UNIT-CMS-0005's contract on the same request that displays or saves it. |
| ReferenceLookup (states, broker types, agent types, broker statuses, task/activity statuses) | Read via UNIT-CMS-0005; written via UNIT-CMS-0005 by Administrator sessions | Populates every dropdown named in R27; this unit caches lookup values only for the lifetime of a single screen session, never persists them. |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth/session, role-driven control visibility |
| UNIT-CMS-0004 | navigation | Launched from search results and the create-flow entry points |
| UNIT-CMS-0005 | contract | The full brokerage/agency/CGA/lookup CRUD contract |
| UNIT-CMS-0008 | embed | Activity grid component embedded on Brokerage/Agency Detail |
| UNIT-CMS-0009 | contract | Address-suggest, embedded on every address form |
| UNIT-CMS-0010 | contract | Policy-read, embedded on the Policy tab |

## Assumptions

- The "Specialty area" referenced by FR-AGY-7 is an existing or separately specified
  destination this unit only links to; its own screens are out of scope here (no
  capability or unit reference for it exists in `capability.md` or
  `capability-design.md`, so this unit treats it as an external navigation target
  gated by role, per R20).
- "Task/activity statuses" reference-lookup admin (R25) is included in this unit's
  scope because FR-REF-2 assigns lookup maintenance generally to Administrators and
  `capability.md` folds all five listed lookups into this capability; no separate unit
  owns a lookup-admin screen.
- Peak/concurrency figures in R44/R45/R49 are derived from the "low hundreds of
  records" volume statement in `capability.md` Constraints (intake Q8), since no
  concurrent-user figure was independently supplied; if this proves wrong, R44's
  latency budget should be re-checked against actual measured load.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
