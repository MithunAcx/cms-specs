---
unit: UNIT-CMS-0006
change: original
---

# Tasks — Partner Records UI

The build order for this unit. Plain checklist, no task IDs. Each item is one
commit's worth of work, states its own done-condition, and names the R-IDs it
satisfies. Language-neutral: name the contract and the behaviour, never the file
path or framework — the engineering repo owns layout.

Authored once. **Never edited after the unit reaches `ready`.** Changes arrive as
`tasks_<YYYY-MM-DD>.md` delta files.

## Contracts and generated code

- [ ] Generate a client from `interfaces/UNIT-CMS-0010.openapi.yaml` for the embedded Policy-activity panel's read call — satisfies R10, R19
- [ ] Once UNIT-CMS-0005 publishes its own `interfaces/openapi.yaml`, re-run the contract copy per `consumed-contracts.yaml`'s pending note, then generate a client covering every brokerage/agency/CGA/broker/agent/lookup operation named in `capability-design.md`'s Unified API Contract — satisfies R1, R3, R5, R7–R9, R11–R13, R16, R18, R21, R25, R27, R30
- [ ] Once UNIT-CMS-0009 publishes its own `interfaces/openapi.yaml`, re-run the contract copy per `consumed-contracts.yaml`'s pending note, then generate a client for the address-suggest call — satisfies R2, R14, R22

## Data

N/A — this unit owns no persistent schema; see `design.md` Data model. No task
emitted for this section.

## Implementation

- [ ] Build the Add New Brokerage form capturing name, address, city, state, zip, phone, fax, tax id, assigned underwriter, status, contract-received date, and history flag — satisfies R1
- [ ] Wire the address-suggest widget into the Add New Brokerage form, filling the XD-0004 shape on acceptance — satisfies R2
- [ ] On a successful brokerage create, navigate to that brokerage's Detail screen — satisfies R3
- [ ] Wire the Add New Brokerage Cancel action to discard entered data and return to the Directory without calling create — satisfies R4
- [ ] Build the Brokerage Detail master-details panel (view + edit) for all fields named in the design's Components table — satisfies R5
- [ ] Format phone/fax as `(nnn) nnn-nnnn` for display and normalize to digits-only before submit — satisfies R6, R17
- [ ] Render the ePay/AccountCode field read-only with no editing control — satisfies R7
- [ ] Show a success confirmation on brokerage save and refresh the screen's held `version` from the response — satisfies R8
- [ ] Build the inline Brokers grid (list, add, edit of first name, last name, broker type/title, email, NPN, disabled) scoped to its own child endpoint — satisfies R9
- [ ] Embed UNIT-CMS-0008's Contact-activity panel and UNIT-CMS-0010's Policy-activity panel on Brokerage Detail, scoped by brokerage id — satisfies R10
- [ ] Add the accounting-address-dialog entry control and the back-to-Directory control on Brokerage Detail — satisfies R11
- [ ] Build the accounting-address dialog, saving only the brokerage's accounting fields — satisfies R12
- [ ] Build the Add New Agency form capturing name, address, city, state, zip, phone, agency number, and Premium Financing flag — satisfies R13
- [ ] Wire the address-suggest widget into the Add New Agency form — satisfies R14
- [ ] Build the two-choice confirmation dialog after a successful agency create, with "Go to Agency Detail" and "Add another agency" (which resets the form and keeps focus on agency name) — satisfies R15
- [ ] Build the Agency Detail master-details panel (view + edit) for all fields named in the design's Components table — satisfies R16
- [ ] Build the inline Agents grid (list, add, edit of first name, last name, agent type/title, phone, email, NPN, history) scoped to its own child endpoint — satisfies R18
- [ ] Embed UNIT-CMS-0008's Contact-activity panel and UNIT-CMS-0010's Policy-activity panel on Agency Detail, scoped by agency id — satisfies R19
- [ ] Add the Specialty navigation control on Agency Detail, rendered only for a role with access, plus the back-to-Directory control — satisfies R20
- [ ] Build the CGA grid keyed by CGA id (list, inline add, inline edit of agent name, address, city, state, zip, email, phone, agency id) — satisfies R21
- [ ] Wire the address-suggest widget into each CGA row, filling city/state/zip on acceptance — satisfies R22
- [ ] Handle the CGA phone field as a formatted string end-to-end, never coercing it to a number — satisfies R23
- [ ] Add the CGA screen's back-to-Directory control — satisfies R24
- [ ] Build the reference-lookup admin screen (states, broker types, agent types, broker statuses, task/activity statuses), rendering add/edit/delete controls only for an Administrator session — satisfies R25, R26
- [ ] Populate every dropdown named in R27 from the corresponding lookup endpoint on each screen's own mount, never from a hardcoded list — satisfies R27
- [ ] Implement client-side required-field enforcement mirroring the server's required fields, on every form in this unit — satisfies R28
- [ ] Implement client-side format checks for phone, zip, email, FEIN, and date fields matching UNIT-CMS-0005's validators — satisfies R29
- [ ] Carry each screen's loaded `version` unmodified through to its save call, per the design's state machine — satisfies R30

## Validation and errors

- [ ] Implement the conflict/error presenter mapping `409 conflict_version_mismatch` to a preserved-edits, reload-and-retry UI, never auto-merged or auto-discarded — satisfies R31
- [ ] Block submission on a failed client-side check (R28/R29) before any request is sent, identifying the offending field inline — satisfies R32
- [ ] Map a `400` response's `error.details[]` back onto matching form fields, and unmatched entries into a general error area — satisfies R33
- [ ] Degrade every address-entry point to plain free-text when the address-suggest widget is down, slow, or errors, keeping the form usable — satisfies R34
- [ ] Isolate the embedded activity/policy panels so a failure in one shows its own inline error and retry without affecting the rest of the Detail screen — satisfies R35
- [ ] Implement the "unable to load" state with retry for any read call (Detail, grid, lookup) that is down, slow, or times out, distinguished from not-found and from validation rejection — satisfies R36
- [ ] Implement the "unresolved" save state for a down/slow/timed-out save, never marking local state as saved, and enabling exactly one manual retry — satisfies R37
- [ ] Disable each form/grid-row's submit control between submission and response/error, preventing a duplicate create request from the same instance — satisfies R38
- [ ] Render every create/edit/admin control only for a session with the required role — never rendered-then-rejected — satisfies R39
- [ ] Implement the "not permitted" presentation for a `403` returned on a save that was permitted when the screen opened — satisfies R40
- [ ] Keep edit controls available on a `disabled`/history-flagged brokerage/agency/CGA/broker/agent record, deferring to the server's own rejection if one occurs — satisfies R41
- [ ] Render and submit every date field (e.g. contract-received date) as date-only, never coerced to a timestamp or shifted by local timezone — satisfies R42

## Observability

- [ ] Emit one structured client-side log entry per failed load or save, carrying the screen/action id, the HTTP status or error code, and `trace_id`, with no personal data — satisfies R53
- [ ] Ensure no field classified as personal data (R54) is written to any client-side log, analytics event, or error message beyond the trace_id-only shape above — satisfies R54

## Tests

- [ ] Unit tests covering every R-ID's happy-path branch listed above (R1–R30)
- [ ] Unit tests covering every failure-surface branch (R31–R42), including the `409`/`400`/`403`/`429`/timeout distinctions and the double-submit guard
- [ ] Unit tests covering the non-functional rows with an observable behaviour (R44 loading-state timing behaviour, R47 rate-limit presentation, R49 two-tab conflict scenario, R50 role-gated rendering, R51 no tenant identifier ever sent, R53/R54 log-content assertions)
- [ ] Contract tests generated from `interfaces/UNIT-CMS-0010.openapi.yaml` pass
- [ ] Contract tests generated from the UNIT-CMS-0005 and UNIT-CMS-0009 copies pass, once those copies exist (see Contracts and generated code)
- [ ] Accessibility conformance check against `ux/a11y.md`'s keyboard map, focus order, and announcement rules for every view

## Coverage check

| R-ID | Covered by task |
|------|-----------------|
| R1 | Implementation — Add New Brokerage form |
| R2 | Implementation — address-suggest on Add New Brokerage |
| R3 | Implementation — navigate on brokerage create success |
| R4 | Implementation — Add New Brokerage Cancel |
| R5 | Implementation — Brokerage Detail master-details panel |
| R6 | Implementation — phone/fax formatting |
| R7 | Implementation — ePay/AccountCode read-only |
| R8 | Implementation — brokerage save confirmation |
| R9 | Implementation — Brokers grid |
| R10 | Contracts — UNIT-CMS-0010 client; Implementation — embed activity/policy panels |
| R11 | Implementation — accounting-dialog entry + back control |
| R12 | Implementation — accounting-address dialog |
| R13 | Implementation — Add New Agency form |
| R14 | Implementation — address-suggest on Add New Agency |
| R15 | Implementation — two-choice confirmation dialog |
| R16 | Implementation — Agency Detail master-details panel |
| R17 | Implementation — phone/fax formatting (shared task) |
| R18 | Implementation — Agents grid |
| R19 | Implementation — embed activity/policy panels (Agency Detail) |
| R20 | Implementation — Specialty navigation |
| R21 | Implementation — CGA grid |
| R22 | Implementation — address-suggest on CGA rows |
| R23 | Implementation — CGA phone as string |
| R24 | Implementation — CGA back-to-Directory |
| R25 | Implementation — reference-lookup admin screen |
| R26 | Implementation — reference-lookup admin screen (role gating) |
| R27 | Implementation — dropdown population from lookup endpoints |
| R28 | Implementation — client-side required-field enforcement |
| R29 | Implementation — client-side format checks |
| R30 | Implementation — version carried through to save |
| R31 | Validation and errors — conflict/error presenter (409) |
| R32 | Validation and errors — block on client validation |
| R33 | Validation and errors — map 400 to fields |
| R34 | Validation and errors — address-suggest degrade |
| R35 | Validation and errors — embedded-panel isolation |
| R36 | Validation and errors — unable-to-load state |
| R37 | Validation and errors — unresolved-save state |
| R38 | Validation and errors — disable submit control |
| R39 | Validation and errors — role-gated control rendering |
| R40 | Validation and errors — not-permitted (403) presentation |
| R41 | Validation and errors — edit controls on disabled/history records |
| R42 | Validation and errors — date-only handling |
| R43 | N/A — no independent availability SLO (design.md Cross-cutting: performance); no task |
| R44 | Tests — loading-state timing behaviour |
| R45 | N/A — no dedicated throughput control (requirements.md NFR R45); no task |
| R46 | N/A — no unit-issued surge behaviour (requirements.md NFR R46); no task |
| R47 | Tests — rate-limit presentation; Validation and errors covers the display itself under R33/R36 pattern |
| R48 | N/A — no idempotency key issued by this unit (requirements.md NFR R48); covered structurally by R38's double-submit guard |
| R49 | Tests — two-tab conflict scenario |
| R50 | Tests — role-gated rendering (shared with R39's task) |
| R51 | Tests — no tenant identifier ever sent |
| R52 | N/A — this unit produces no audit record of its own (requirements.md NFR R52); no task |
| R53 | Observability — structured failure log |
| R54 | Observability — no personal data in logs |
| R55 | N/A — no persistent store, no retention/erasure obligation of its own (requirements.md NFR R55); no task |
| R56 | N/A — greenfield UI, no migration/backfill (requirements.md NFR R56); no task |
| R57 | N/A — no feature flag required by any stated requirement (requirements.md NFR R57); no task |
