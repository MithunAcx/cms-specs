# States — Partner Records UI

Every state the user can observe. A state with no row here is an
unspecified state, and `ba-spec-validate` fails the unit for it.

## Per view

### Add New Brokerage — satisfies R1, R2, R3, R4, R28, R29, R32, R33, R38

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Screen mount, fetching broker-status/underwriter lookup lists | Skeleton bars in place of the status dropdown and the address-suggest field; other fields render immediately since they need no lookup | None on the loading fields; other fields already editable |
| empty | N/A — this is a create form with no prior data; there is no "no records" case | — | — |
| populated | Lookups loaded; form ready with all fields empty | Blank form, every field editable | Fill fields, use address-suggest, Save, Cancel |
| partial | Broker-status lookup loads but underwriter suggestion (free text, no lookup) — N/A; only one lookup call exists on this form, so partial does not apply distinctly from error — recoverable below | — | — |
| submitting | User clicked Save, request in flight | Save button shows a busy state and is disabled; all fields become read-only; Cancel is disabled | None — must wait for response or error |
| success | `201` received | Brief inline confirmation, then immediate navigation to the new Brokerage Detail screen (R3) | None — screen changes |
| error — recoverable | `400` validation, `409` (not expected on create but handled defensively), `429`, timeout/`5xx` | Per-field messages under the offending fields for `400`; a general error block above the form for `429`/timeout/`5xx` naming the condition (R33, R37, R47) | Correct fields and resubmit; Save re-enabled after exactly one automatic re-enable (R37/R38) |
| error — terminal | N/A — no condition on this form is unrecoverable within the screen; every failure returns the user to an editable form | — | — |
| disabled / no permission | Session lacks the Editor role | Form is not reachable at all — the launching control (UNIT-CMS-0004) does not render it; if reached directly, an inline notice explains the requirement and offers only a link back to the Directory | Return to Directory |
| offline — on load | Browser reports no connectivity when the lookup fetch is attempted | Error block: "You're offline — reconnect to load status options." Address-suggest field falls back to free text (R34) | Retry |
| offline — on submit | Connectivity lost after Save is clicked | Save reported as unresolved (R37) — "Your save may not have gone through. Check your connection and try again." Fields remain populated with the user's entries | Retry once reconnected |
| session expiry mid-flow | Auth session expires while the form is filled in | A non-destructive notice appears: "Your session has expired. Sign in again to save — your entries are kept." Entered field values are preserved in the form | Re-authenticate, then Save is retried by the user |

### Brokerage Detail — satisfies R5–R12, R30, R31, R35, R36, R37, R41, R42

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Screen mount, fetching the brokerage record, Brokers grid, activity panel, policy panel | Skeleton blocks in the master-details panel and each grid/panel region independently | None |
| empty | Brokers grid has zero rows (a new brokerage with no brokers yet) | Empty-state block in the Brokers grid region: "No brokers yet" + Add broker action; master details still populated | Add broker |
| populated | Record and both grids loaded | Full master-details panel, Brokers grid rows, embedded activity and policy panels | Edit any master field, add/edit a broker row, load a further page of Brokers when `next_cursor` is present (cursor-based, per 10-platform.md — never page numbers), open accounting dialog, switch panels |
| partial | Master details load but the activity panel or policy panel fails independently (R35) | The failing panel shows its own inline error and retry; master details and Brokers grid remain fully usable | Retry the failing panel only |
| submitting | User saves an edited master-detail field, or an inline broker row | The field/row group being saved shows a busy state and locks; the rest of the screen remains interactive | None on the saving region; other regions unaffected |
| success | `200` on a master-detail save, or `201`/`200` on a broker row save | Inline confirmation near the saved region (R8); values refresh to the response, including the new `version` | Continue editing |
| error — recoverable | `400` (R33), `409` (R31), `429` (R47), timeout/`5xx` (R36/R37) | `409`: distinguishable conflict message, edits preserved, explicit reload-and-retry offered, never auto-merged. `400`: field-level messages. `429`/timeout: general message with retry | Reload-and-retry (409), correct and resubmit (400), retry (429/timeout) |
| error — terminal | Brokerage id in the URL does not exist or belongs to another tenant (`404`) | Full-screen "This brokerage could not be found" message | Return to Directory |
| disabled / no permission | Session lacks Editor role | Master-details fields, Brokers grid edit controls, and the accounting dialog control render read-only/hidden per R39 (control not rendered rather than rendered-and-rejected); a Viewer sees all data read-only | View only |
| offline — on load | No connectivity at screen mount | Full-screen "You're offline" message with retry, no stale data shown | Retry |
| offline — on submit | Connectivity lost mid-save | Save reported as unresolved (R37); edited fields keep the user's values, not the pre-edit ones | Retry once reconnected |
| session expiry mid-flow | Session expires while editing a field or a grid row | Non-destructive notice; in-progress edits (master field or grid row) are preserved in the UI, not sent, until re-authentication | Re-authenticate, then resume/save |

### Accounting-address dialog — satisfies R11, R12

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Dialog opens, fetching current accounting fields | Skeleton bars for each field inside the dialog | None |
| empty | N/A — accounting fields always exist on an existing brokerage, even if blank | — | — |
| populated | Fields loaded (possibly blank if never set) | Editable contact name/address/city/state/zip fields, address-suggest assist | Edit, Save, Cancel |
| partial | N/A — single-record fetch, no partial sub-parts | — | — |
| submitting | Save clicked | Save disabled/busy, fields locked | None |
| success | `200` | Dialog closes; Brokerage Detail's accounting fields reflect the update; master-details fields are confirmed unchanged | Continue on Detail screen |
| error — recoverable | `400`, `409`, `429`, timeout | Same mapping as Brokerage Detail's save states, scoped to the dialog | Correct/retry/reload per error type |
| error — terminal | N/A | — | — |
| disabled / no permission | Session lacks Editor role | Dialog's open control is not rendered on Brokerage Detail | N/A |
| offline — on load | No connectivity when dialog opens | Dialog shows "You're offline" with retry, does not show stale data | Retry |
| offline — on submit | Connectivity lost mid-save | Save reported as unresolved; dialog stays open with entered values | Retry once reconnected |
| session expiry mid-flow | Session expires while dialog is open | Non-destructive notice inside the dialog; entered values preserved | Re-authenticate, then Save |

### Add New Agency — satisfies R13, R14, R15, R28, R29, R32, R33, R38

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Screen mount | Skeleton bars while the form's own dependencies (none beyond address-suggest, which is on-demand) settle — effectively brief/instant | Fields become editable as they settle |
| empty | N/A — create form | — | — |
| populated | Form ready, all fields empty | Blank form | Fill fields, address-suggest, Save, Cancel |
| partial | N/A | — | — |
| submitting | Save clicked | Save busy/disabled, fields locked | None |
| success | `201` received | Two-choice confirmation dialog (R15): "Go to Agency Detail" / "Add another agency" | Choose one of the two options |
| error — recoverable | `400`, `429`, timeout/`5xx` | Same mapping pattern as Add New Brokerage | Correct/retry |
| error — terminal | N/A | — | — |
| disabled / no permission | Session lacks Editor role | Form unreachable; launching control (UNIT-CMS-0004) does not render it | Return to Directory |
| offline — on load | No connectivity at mount | Error block, address-suggest degrades to free text | Retry |
| offline — on submit | Connectivity lost after Save | Save reported unresolved; fields keep entered values | Retry once reconnected |
| session expiry mid-flow | Session expires while filling the form | Non-destructive notice; entries preserved | Re-authenticate, then Save |

### Two-choice confirmation dialog (Add New Agency) — satisfies R15

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | N/A — dialog opens instantly on the create response already in hand | — | — |
| empty | N/A | — | — |
| populated | Agency created successfully | Confirmation text naming the new agency, two buttons | "Go to Agency Detail", "Add another agency" |
| partial | N/A | — | — |
| submitting | N/A — choosing an option navigates or resets immediately, no server call from the dialog itself | — | — |
| success | N/A — the dialog's two outcomes are both "success" states of the parent flow, not a further save | — | — |
| error — recoverable | N/A — nothing can fail once this dialog is showing | — | — |
| error — terminal | N/A | — | — |
| disabled / no permission | N/A — only reachable after a successful create the user was already permitted to do | — | — |
| offline | N/A — no network action originates from the dialog | — | — |
| session expiry mid-flow | Session expires while the dialog is open | Both choices still work locally (navigate or reset the form); the next screen (Detail, or the reset form) applies its own session-expiry handling if a call is then needed | Choose either option |

### Agency Detail — satisfies R16–R20, R30, R31, R35, R36, R37, R41

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Screen mount, fetching agency, Agents grid, activity panel, policy panel | Skeleton blocks per region | None |
| empty | Agents grid has zero rows | Empty-state block: "No agents yet" + Add agent | Add agent |
| populated | Record and grids loaded | Full master-details panel, Agents grid, embedded activity/policy panels, Specialty link (if role permits) | Edit fields, add/edit agent row, load a further page of Agents when `next_cursor` is present (cursor-based, per 10-platform.md), navigate to Specialty, embed panels |
| partial | Activity or policy panel fails independently | That panel shows its own inline error and retry; rest of screen unaffected | Retry that panel |
| submitting | Saving a master field or agent row | Saving region busy/locked; rest of screen interactive | None on saving region |
| success | `200`/`201` | Inline confirmation; values refresh including `version` | Continue editing |
| error — recoverable | `400`, `409`, `429`, timeout/`5xx` | Same mapping as Brokerage Detail | Reload-and-retry / correct+resubmit / retry |
| error — terminal | Agency id not found or cross-tenant (`404`) | Full-screen "This agency could not be found" | Return to Directory |
| disabled / no permission | Session lacks Editor role; Specialty link hidden if role lacks access (R20) | Read-only master details and grids; Specialty control absent for ineligible roles | View only |
| offline — on load | No connectivity at mount | Full-screen offline message, retry | Retry |
| offline — on submit | Connectivity lost mid-save | Save reported unresolved; edited values preserved | Retry once reconnected |
| session expiry mid-flow | Session expires mid-edit | Non-destructive notice; in-progress edits preserved until re-authentication | Re-authenticate, then resume/save |

### CGA grid — satisfies R21–R24, R28, R29, R32, R33, R38, R41

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Screen mount, fetching CGA list | Skeleton rows in the grid | None |
| empty | Zero CGA records exist | Empty-state block: "No CGA records yet" + Add CGA | Add CGA |
| populated | CGA records loaded | Grid rows keyed by CGA id, each with inline edit | Add row, edit row, back to Directory |
| partial | Some rows' address-suggest widget fails while the grid itself loaded fine | Grid remains usable; affected row's address field degrades to free text (R34) | Continue editing that row as free text |
| submitting | Saving an inline row | That row shows busy state and locks; other rows remain interactive | None on the saving row |
| success | `200`/`201` on a row save | Inline confirmation on that row | Continue editing other rows |
| error — recoverable | `400`, `409`, `429`, timeout/`5xx` on a row save | Same per-error mapping, scoped to that row | Correct/retry/reload that row |
| error — terminal | N/A — a row load failure is recoverable via retry, not terminal | — | — |
| disabled / no permission | Session lacks Editor role | Grid renders read-only, no add/edit controls (R39) | View only |
| offline — on load | No connectivity at mount | Full-grid "You're offline" message, retry | Retry |
| offline — on submit | Connectivity lost mid-row-save | That row's save reported unresolved; entered values preserved | Retry once reconnected |
| session expiry mid-flow | Session expires while a row is being edited | Non-destructive notice; the in-progress row's edits preserved until re-authentication | Re-authenticate, then save that row |

### Reference-lookup admin — satisfies R25, R26, R27, R39

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Screen mount, fetching the selected lookup type's values | Skeleton rows | None |
| empty | A lookup type currently has zero values (e.g. newly introduced type) | Empty-state block: "No values yet" + Add value (Administrator only) | Add value (Administrator) |
| populated | Values loaded | List of values with Administrator-only edit/delete/add controls; read-only list for every other role (R26) | Add/edit/delete (Administrator); none (other roles) |
| partial | N/A — single list fetch, no partial sub-parts | — | — |
| submitting | Administrator saves an add/edit | List locked, busy indicator | None |
| success | `200`/`201` | Inline confirmation; list refreshes | Continue editing |
| error — recoverable | `400`, `429`, timeout/`5xx` | Field-level or general error mapping | Correct/retry |
| error — terminal | N/A | — | — |
| disabled / no permission | Session role is not Administrator | List renders with no add/edit/delete controls at all (R26, R39) — never rendered-then-rejected | View only |
| offline — on load | No connectivity at mount | "You're offline" message, retry | Retry |
| offline — on submit | Connectivity lost mid-save (Administrator) | Save reported unresolved; entered edit preserved | Retry once reconnected |
| session expiry mid-flow | Session expires while an Administrator edit is open | Non-destructive notice; the edit's entered values preserved | Re-authenticate, then save |

## Validation messages

| Field | Rule | Message |
|---|---|---|
| Brokerage/Agency name | Required | "Enter a name." |
| Address line 1 | Required | "Enter a street address, or use suggest to fill it." |
| City / State / Zip | Required together | "Enter city, state, and zip." |
| Phone | Format, once entered | "Enter a valid phone number." |
| Fax | Format, once entered | "Enter a valid fax number." |
| Tax id (FEIN) | Format | "Enter a valid tax ID (FEIN)." |
| Email | Format, once entered | "Enter a valid email address." |
| Contract-received date | Valid date, not in the future | "Enter a valid date, not in the future." |
| Agency number ("G1 Agency ID") | Required | "Enter the agency number." |
| CGA phone | Format (string, not numeric) | "Enter a valid phone number." |
| Any field the server also rejects | Server `400` on a field the client accepted | Server's `message` shown at that field, verbatim |
| Any server field the client has no matching control for | Server `400` naming an unmapped field | Shown in a general error area at the top of the form |

## Copy

All user-visible strings, so they are reviewable and translatable.

| Key | Copy |
|---|---|
| conflict.title | "This record changed" |
| conflict.body | "Someone else saved changes to this record after you loaded it. Your edits are still here — reload to see the latest version, or keep editing and try saving again." |
| conflict.action.reload | "Reload record" |
| notPermitted.title | "You don't have permission to do that" |
| notPermitted.body | "Your access may have changed since this screen loaded." |
| unresolved.title | "We couldn't confirm your save" |
| unresolved.body | "Check your connection and try again. If the change already went through, you'll see it after reloading." |
| unresolved.action.retry | "Try again" |
| rateLimited.title | "Too many requests" |
| rateLimited.body | "Please wait a moment and try again." |
| unableToLoad.title | "Unable to load" |
| unableToLoad.body | "Something went wrong loading this. Try again." |
| unableToLoad.action.retry | "Retry" |
| notFound.brokerage | "This brokerage could not be found." |
| notFound.agency | "This agency could not be found." |
| offline.title | "You're offline" |
| offline.body | "Reconnect to continue." |
| sessionExpired.title | "Your session has expired" |
| sessionExpired.body | "Sign in again to continue. Your entries are kept." |
| sessionExpired.action | "Sign in" |
| addressSuggest.degraded | "Address suggestions are unavailable right now — enter the address directly." |
| brokersGrid.empty.title | "No brokers yet" |
| brokersGrid.empty.action | "Add broker" |
| agentsGrid.empty.title | "No agents yet" |
| agentsGrid.empty.action | "Add agent" |
| cgaGrid.empty.title | "No CGA records yet" |
| cgaGrid.empty.action | "Add CGA" |
| lookup.empty.title | "No values yet" |
| lookup.empty.action | "Add value" |
| addAgency.confirm.title | "Agency created" |
| addAgency.confirm.goToDetail | "Go to Agency Detail" |
| addAgency.confirm.addAnother | "Add another agency" |
| save.success | "Saved" |
| save.saving | "Saving…" |
| grid.loadMore | "Load more" |
| grid.loadingMore | "Loading more…" |
