# States — Partner Directory UI

Every state the user can observe. A state with no row here is an
unspecified state, and `ba-spec-validate` fails the unit for it.

**Mockup note.** `ux/wireframes/UNIT-CMS-0004-partner-directory-ui.html` is a real,
single-page interactive prototype of this screen — there is no frame-picker; every
row below is reached by actually operating the mockup (typing, switching mode,
searching, filtering, loading more), against an in-memory demo dataset. A small
"Simulate condition" harness fakes the handful of conditions that dataset cannot
produce on its own — a genuine dependency failure, an offline connection, an
expired session, a throttled response, a failed lookup call — but the harness only
flips a flag the same render code reads; it never substitutes a separately-authored
static block for a row below. See `ux/wireframes/frame-inventory.md`'s "The
interaction model" section for exactly how each row is reached.

## Per view

### Directory / Search screen — satisfies R1-R41

The screen has one search-input state machine (design.md: idle / loading /
resolved / error) plus a few cross-cutting states (auth, offline, permission)
layered on top of it. The table below maps every user-observable state to the
mandatory set in `60-frontend.md`.

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | A search is submitted (mode search or UW-filter select) and the response has not yet arrived | The results region shows skeleton rows (table skeleton on desktop/tablet, card skeleton on mobile) in place of the previous result set; the search controls remain visible and editable | Change mode/term/state/UW filter (starts a new search per R20); no cancel affordance is exposed, since a newer search silently supersedes the older one |
| empty | A resolved (non-stale) response returns zero items | "No records to display" empty-state block, plus the result count showing 0 | Change mode/term/state/UW filter and search again; Add New Agency / Add New Brokerage remain available (R11) |
| populated | A resolved (non-stale) response returns ≥1 item | Table (desktop/tablet) or stacked cards (mobile) with the mode's column set (R6), plus the total result count (R9); a "Load more" control is shown whenever the response carries a `next_cursor` (R12 — cursor-based, never a page-number control) | Click a row to open its detail screen (R10); change search inputs; activate "Load more" to fetch the next cursor-based batch |
| partial | The Assigned Underwriter lookup (`/lookups/assigned-uws`) fails to load while the rest of the screen is otherwise usable | The UW filter dropdown shows an inline "Underwriters unavailable" notice in place of its option list; the six-mode search path is unaffected and fully usable | Retry loading the UW list; use mode-based search normally |
| error — recoverable | UNIT-CMS-0003 is unreachable, times out, or returns a 5xx (R21) | An error block replacing the results region: message plus a "Retry" secondary button; the search inputs the user entered are preserved | Retry (re-issues the same search); change inputs and search again |
| error — terminal | The same dependency failure recurs after the user has already retried the retryable error at least once in this session | An error block with a message that does not offer another retry button, and points the user to contact support instead; search inputs are preserved | Change search inputs and try a different search; no further retry of the identical failing request is offered |
| disabled / no permission | The authenticated session's role is below Viewer for the whole screen (R17), or below the create-capable role for the launch points only (R11/R18) | Whole-screen case: an access-denied block replaces the entire Directory screen, no search inputs rendered. Launch-point case: "Add New Agency"/"Add New Brokerage" are absent entirely — not shown disabled — from an otherwise fully usable screen | Whole-screen case: none, other than navigating away. Launch-point case: full search functionality remains |
| offline — on load | The device has no network connectivity when the Directory screen is first opened | A full-screen offline notice in place of the search form and results, stating the screen needs a connection to search | Retry once connectivity is detected (automatic re-check plus a manual "Try again") |
| offline — on submit | Connectivity drops after the screen loaded, while a search is in flight or about to be submitted | The in-flight search is treated as a recoverable error (offline is surfaced as the reason in the error block's message) rather than hanging indefinitely; inputs are preserved | Retry once connectivity returns |
| session expiry mid-flow | The session's access token expires while the screen is idle or between searches (R25) | The next search attempt is intercepted before it is sent; the user is routed to re-authenticate. On return, the search inputs (mode/term/state/UW selection) the user had set are preserved and the search is re-issued automatically | Re-authenticate; the interrupted search resumes without the user re-entering it |
| submitting | Functionally identical to loading for this unit — every "submission" here is the read-only search request itself (R31: no mutation exists to submit) | Same as loading | Same as loading |
| success | Functionally identical to populated/empty for this unit — there is no separate confirmation step beyond rendering the result set (R31: no mutation, so no success toast/redirect is applicable) | Same as populated / empty | Same as populated / empty |

## Validation messages

| Field | Rule | Message |
|---|---|---|
| Search term | Empty or whitespace-only, for a term-required mode (By Brokerage, By Broker, By Agency, By CGA) | "Enter a search term to search by {mode label}." |
| State | No state selected, for a state-required mode (By State (Broker), By State (Agent)) | "Select a state to search." |

## Copy

All user-visible strings, so they are reviewable and translatable.

| Key | Copy |
|---|---|
| screen.title | "Partner Directory" |
| screen.subtitle | "Search brokerages, brokers, agencies and CGAs." |
| results.heading | "Search results" |
| action.load-more | "Load more" |
| session.expired.action | "Sign in again" |
| error.offline-submit.body | "You appear to be offline. Reconnect and try again." |
| mode.brokerage | "By Brokerage" |
| mode.broker | "By Broker" |
| mode.state-broker | "By State (Broker)" |
| mode.agency | "By Agency" |
| mode.cga | "By CGA" |
| mode.state-agent | "By State (Agent)" |
| filter.assigned-uw.label | "Assigned Underwriter" |
| filter.assigned-uw.placeholder | "All underwriters" |
| filter.assigned-uw.unavailable | "Underwriters unavailable right now — mode search still works." |
| search.term.label | "Search term" |
| search.state.label | "State" |
| search.submit | "Search" |
| results.count | "{count} results" |
| results.empty.title | "No records to display" |
| results.empty.body | "Try a different search term, state, or underwriter." |
| results.column.brokerage | "Brokerage" |
| results.column.address | "Address" |
| results.column.assigned-uw | "Assigned UW" |
| results.column.state | "State" |
| results.column.first-name | "First" |
| results.column.last-name | "Last" |
| results.column.title-type | "Title/Type" |
| results.column.email | "Email" |
| results.column.status | "Status" |
| results.column.agency | "Agency" |
| results.column.agent | "Agent" |
| results.column.cga-agent | "CGA Agent" |
| status.active | "Active" |
| status.disabled | "Disabled" |
| action.add-agency | "Add New Agency" |
| action.add-brokerage | "Add New Brokerage" |
| error.recoverable.title | "We couldn't load results" |
| error.recoverable.body | "Something went wrong reaching the search service." |
| error.recoverable.retry | "Retry" |
| error.terminal.title | "Search is unavailable" |
| error.terminal.body | "This keeps failing. Contact support if it continues." |
| error.rate-limited.title | "Too many searches" |
| error.rate-limited.body | "Please wait a moment before searching again." |
| error.access-denied.title | "You don't have access to this screen" |
| error.access-denied.body | "Contact your administrator if you believe this is a mistake." |
| offline.load.title | "You're offline" |
| offline.load.body | "Connect to the network to search the directory." |
| offline.submit.retry | "Try again" |
| session.expired.notice | "Your session expired. Sign in again to continue." |
