# Frame inventory — UNIT-CMS-0004-partner-directory-ui

**Source position:** no unit-specific design file exists. This is the ordinary case —
frames below are generated per `designer-unit-ux`'s default output, from `states.md`
and `design.md`. The sponsor-provided indicative UI redesign,
`requirements/contactmanagement-full-mockup.html` (cited in
`requirements/CMS-Modernization-Requirements.md` §1.4 as
`contactmanagement-angular-mockup.html` — same file, filename drifted), **is** the
reference for this unit's visual design system, for the Directory/Search landing
screen's structure and copy (its `<!-- DIRECTORY / SEARCH -->` section, `~L236-283`,
and its `<style>` block, `~L29-966`), and — as of this revision — for its
**architecture**: the reference is a true single-page application with no
frame-picker anywhere in it. After sign-in it lands on a real Directory page
(`#page-directory`); its six `.seg` search-mode buttons, its Assigned Underwriter
filter, and its "Search"/"Clear" controls all re-render the results region live via
`renderResults()`; and clicking a result row calls `openBrokerage(id)`/`openAgency(id)`
— a real navigation, not a static "detail" screenshot. This mockup now matches that
architecture for this unit's own scope. Two structural differences from the
reference remain, both required by this unit's own requirements/design: (1) results
are paginated with a cursor-based "Load more" control (R12, `10-platform.md`), not
the reference's simpler unpaginated list; (2) "Manage CGAs" and the CGA/Agency/
Brokerage create-form dialogs are not drawn here — CGA is a search mode only in this
unit's scope, and the create forms belong to UNIT-CMS-0006 (requirements.md
Scope/Out of scope).

**Constraints every frame respects:** the three canvas widths (360/768/1440),
`design-system.md` §2 tokens (both themes), WCAG 2.2 AA contrast/target-size, usable
at 200% zoom, colour never the sole carrier of meaning (status badges carry a
shape-mark and a label alongside colour).

## The interaction model (read this before the frame table)

**There is exactly one live screen in this file: the Directory/Search screen**
(`#screen-directory`), plus three whole-screen alternates it can be replaced by
(`#screen-access-denied`, `#screen-offline-load`, `#screen-session-expired`). There is
no picker that swaps in a separately authored static markup block for a "frame" —
every row in the table below is reached by actually operating the one real screen,
against the in-memory demo dataset (brokerages/brokers/agencies/CGAs) wired to the
`<script>` at the end of the file:

- Typing in the search term/state input **live-filters** the results instantly
  (client-side, no request — mirrors the reference's `renderResults()`).
- Clicking a `.seg` mode button **really switches mode** and re-renders the results
  for that mode.
- Clicking "Search" **really submits**: it goes through a short artificial delay so
  the loading state is reached the way a real network call would reach it, then
  resolves to populated/empty against the demo data.
- The Assigned Underwriter filter **really filters**, through the same delayed path.
- "Load more" **really appends** the next in-memory batch (cursor-pagination stand-in,
  R12).
- Clicking a result row is a **real navigation attempt** that resolves to a toast
  ("Would navigate to Brokerage/Agency/CGA Detail for `<id>` — owned by
  UNIT-CMS-0006, out of this unit's scope"), because the destination screens are
  UNIT-CMS-0006's scope and do not exist in this file (requirements.md R10/R26,
  Scope/Out of scope). "Add New Agency"/"Add New Brokerage" resolve the same way
  (R11).

A small **"Simulate condition" harness** (clearly separated, top chrome bar, never
part of the canvas) exists **only** for the handful of states that cannot occur
naturally against fake in-memory data — a genuine dependency failure, an offline
condition, an expired session, a throttled response, a failed lookup call. Each
control **fakes the underlying condition and lets the same render functions run**
(`renderRecoverableError`, `renderTerminalError`, `renderRateLimited`,
`renderOfflineSubmitError`, the access-denied/offline-load/session-expired screen
swaps, the UW-filter's unavailable presentation) — it never swaps in a
separately-authored static HTML block for the state. The harness:

| Control | Fakes | Reached state(s) |
|---|---|---|
| Offline checkbox | No connectivity | offline-load (before any search attempted) / offline-submit (after) |
| Access select | Session-guard role resolution | access-denied (no screen access) / no-create-permission (create buttons absent) |
| Search dependency select | UNIT-CMS-0003 failure modes | error-recoverable → error-terminal on retry (R21) / rate-limited (R23) |
| Underwriters lookup unavailable checkbox | `/lookups/assigned-uws` failure | partial |
| "Expire session now" button | Access-token expiry mid-flow | session-expired mid-flow (intercepts the next search attempt, R25) |

No harness control exists for validation-error, loading, populated, or empty — those
are reached by ordinary interaction alone, with no simulated condition involved.

## Frames

Frame names/numbers are unchanged from the prior revision for traceability. The
"Width" column still records the width each row was *specified* against; every row
also renders correctly at the other two widths via the width control, since it is
the same live screen throughout.

| # | Frame name | What it shows | State row (states.md) | How it's reached | Width |
|---|---|---|---|---|---|
| 1 | directory-idle | Landing view: mode switcher (By Brokerage selected by default), empty term input, no results region rendered yet | (pre-search — implicit initial condition) | Real — the screen's initial render, before any search input | desktop |
| 2 | directory-validation-error | Term-required mode submitted with an empty term; inline validation message under the input | Validation messages table | Real — click Search (or press Enter) with the term/state field empty | desktop |
| 3 | directory-loading | Search in flight; skeleton rows (table) or skeleton cards (mobile/tablet) in the results region | loading | Real — click Search with a valid input; the 450ms artificial delay makes this genuinely observable | desktop |
| 4 | directory-populated-desktop | Results table for the current mode, result count, Add New Agency/Brokerage visible (create-capable role) | populated | Real — any search/filter that returns ≥1 match, viewed at 1440px | desktop |
| 5 | directory-populated-mobile | Same results as #4, stacked-card layout | populated | Real — same search, viewed at 360px via the Width control | mobile |
| 6 | directory-broker-mode | By Broker results: mailto email link + Active/Disabled status badge column | populated | Real — click the "By Broker" mode button, then search | desktop |
| 7 | directory-uw-filter | Assigned Underwriter filter selected; results scoped to that underwriter | populated | Real — pick a value from the Assigned Underwriter dropdown | desktop |
| 8 | directory-empty | Zero-result response for a valid search; "No records to display" | empty | Real — search for a term/state that matches nothing in the demo data | desktop |
| 9 | directory-partial | UW filter dropdown failed to load; mode search still fully usable | partial | Harness — check "Underwriters lookup unavailable"; mode search remains fully live alongside it | desktop |
| 10 | directory-error-recoverable | UNIT-CMS-0003 5xx/timeout; error block with Retry, inputs preserved | error — recoverable | Harness — set "Search dependency" to Failing, then search | desktop |
| 11 | directory-error-terminal | Repeated failure after a retry already attempted; error block with no further retry, points to support | error — terminal | Harness — with "Failing" still set, click Retry on frame 10's error block a second time for the same query (R21's "recurs after already retried once") | desktop |
| 12 | directory-rate-limited | 429 from UNIT-CMS-0003/gateway; rate-limited message, Retry available | (dependency — rate limit; folded into the error-recoverable family, R23) | Harness — set "Search dependency" to Rate limited, then search | desktop |
| 13 | directory-access-denied | Session role below Viewer; whole screen replaced by access-denied block | disabled / no permission (whole-screen case) | Harness — set Access to "No screen access" | desktop |
| 14 | directory-no-create-permission | Fully usable search screen with Add New Agency/Brokerage absent (role lacks create permission) | disabled / no permission (launch-point case) | Harness — set Access to "Viewer (no create permission)"; only the create buttons disappear, search stays fully live | desktop |
| 15 | directory-offline-load | Screen opened with no connectivity; full-screen offline notice, no search form | offline — on load | Harness — check Offline before attempting any search | desktop |
| 16 | directory-offline-submit | Connectivity drops mid-search; treated as a recoverable error naming the offline cause | offline — on submit | Harness — perform a search first, then check Offline, then search/filter/load-more again | desktop |
| 17 | directory-session-expired | Token expired mid-flow; notice plus re-authentication routing, inputs preserved | session expiry mid-flow | Harness — click "Expire session now", then attempt any search; "Sign in again" returns to the Directory screen and automatically re-issues the intercepted search | desktop |
| 18 | status-matrix | The status-badge component in all four canonical variants (active/pending/lapsed/neutral), for the greyscale check — this unit only uses active/disabled (mapped to active/lapsed) in real screens; the other two are shown here as the shared component's full set per `design-system.md` §7 | (component reference frame, not a unit state) | Real — click "Show status-badge reference set" below the Directory screen; a collapsed reference panel, never part of the interactive flow above it | desktop |

All frames also render at `tablet`/`mobile` (or `tablet`/`desktop` for #5) via the
mockup's width control — the column above records only the width each frame was
*specified* against, per `design-system.md` §1.

**Prior revision's note is now obsolete and removed:** an earlier revision made only
frame 1 (directory-idle) a live prototype and left frames 2-17 as fixed static
snapshots, reachable only via a frame-picker dropdown. That dropdown has been
removed entirely. No frame is a static snapshot any more; every row above is reached
by interacting with the one real screen, exactly as `requirements/
contactmanagement-full-mockup.html` reaches its own states — the only thing this
mockup adds beyond that reference is the small, clearly-labelled harness for the
handful of conditions fake data cannot produce on its own. No new state was added
and no frame was removed or renamed — this is a change to *how* the already-
documented states are reached, not to the state inventory itself.

## What must NOT be drawn

- No delete/edit affordance anywhere — this unit has no CRUD capability (capability.md non-goals).
- No cancel button on an in-flight search — a newer search silently supersedes an older one (R20); there is nothing to "cancel" from the user's point of view.
- No retry button on the terminal-error frame (#11) — that is what makes it terminal rather than recoverable.
- No tenant/organization selector or identifier anywhere in the UI (R35 — tenant scoping is invisible to this screen).
- No raw API error envelope (`code`/`trace_id`) shown to the end user — only the human-readable message (design.md Cross-cutting/errors).
- No column not listed in the capability's per-mode column table (R6) — e.g. no "Disabled" column on modes other than By Broker.
- No frame-picker (or any control) that swaps in a separately-authored static block for a state reachable through real interaction — the harness table above is the only sanctioned exception, and only for conditions fake data cannot produce.

## Could not be generated

None — every frame in `states.md` maps to a component already defined in
`design-system.md` (table, card, status badge, error block, empty state, notice,
skeleton bar).

## Open questions affecting this inventory

- Q1 (requirements.md): if UNIT-CMS-0006 is not in fact the detail/create-screen owner, the row-open and create-launch navigation targets change, but no frame here changes shape as a result — navigation destination is not drawn in a mockup, only attempted and stubbed.
