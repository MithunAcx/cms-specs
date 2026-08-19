# Frame inventory — UNIT-CMS-0004-partner-directory-ui

**Source position:** no design file exists. This is the ordinary case — frames below
are generated per `designer-unit-ux`'s default output, from `states.md` and `design.md`.

**Constraints every frame respects:** the three canvas widths (360/768/1440),
`design-system.md` §2 tokens (both themes), WCAG 2.2 AA contrast/target-size, usable
at 200% zoom, colour never the sole carrier of meaning (status badges carry a
shape-mark and a label alongside colour).

## Frames

| # | Frame name | What it shows | State row (states.md) | Width |
|---|---|---|---|---|
| 1 | directory-idle | Landing view: mode switcher (By Brokerage selected by default), empty term input, no results region rendered yet | (pre-search — implicit initial condition of "loading"/"populated" rows) | desktop |
| 2 | directory-validation-error | Term-required mode submitted with an empty term; inline validation message under the input | Validation messages table | desktop |
| 3 | directory-loading | Search in flight; skeleton rows in the results region | loading | desktop |
| 4 | directory-populated-desktop | By Brokerage results, table layout, result count, Add New Agency/Brokerage visible (create-capable role) | populated | desktop |
| 5 | directory-populated-mobile | Same By Brokerage results as #4, stacked-card layout | populated | mobile |
| 6 | directory-broker-mode | By Broker results: mailto email link + Active/Disabled status badge column | populated | desktop |
| 7 | directory-uw-filter | Assigned Underwriter filter selected; results scoped to that underwriter | populated | desktop |
| 8 | directory-empty | Zero-result response for a valid search; "No records to display" | empty | desktop |
| 9 | directory-partial | UW filter dropdown failed to load; mode search still fully usable | partial | desktop |
| 10 | directory-error-recoverable | UNIT-CMS-0003 5xx/timeout; error block with Retry, inputs preserved | error — recoverable | desktop |
| 11 | directory-error-terminal | Repeated failure after a retry already attempted; error block with no further retry, points to support | error — terminal | desktop |
| 12 | directory-rate-limited | 429 from UNIT-CMS-0003/gateway; rate-limited message, Retry-After respected | (dependency — rate limit; see R23, folded into error-recoverable family) | desktop |
| 13 | directory-access-denied | Session role below Viewer; whole screen replaced by access-denied block | disabled / no permission (whole-screen case) | desktop |
| 14 | directory-no-create-permission | Fully usable search screen with Add New Agency/Brokerage absent (role lacks create permission) | disabled / no permission (launch-point case) | desktop |
| 15 | directory-offline-load | Screen opened with no connectivity; full-screen offline notice, no search form | offline — on load | desktop |
| 16 | directory-offline-submit | Connectivity drops mid-search; treated as a recoverable error naming the offline cause | offline — on submit | desktop |
| 17 | directory-session-expired | Token expired mid-flow; notice plus re-authentication routing, inputs preserved | session expiry mid-flow | desktop |
| 18 | status-matrix | The status-badge component in all four canonical variants (active/pending/lapsed/neutral), for the greyscale check — this unit only uses active/disabled (mapped to active/lapsed) in real screens; the other two are shown here as the shared component's full set per `design-system.md` §7 | (component reference frame, not a unit state) | desktop |

All frames also render at `tablet`/`mobile` (or `tablet`/`desktop` for #5) via the
mockup's width control — the column above records only the width each frame was
*specified* against, per `design-system.md` §1.

## What must NOT be drawn

- No delete/edit affordance anywhere — this unit has no CRUD capability (capability.md non-goals).
- No cancel button on an in-flight search — a newer search silently supersedes an older one (R20); there is nothing to "cancel" from the user's point of view.
- No retry button on the terminal-error frame (#11) — that is what makes it terminal rather than recoverable.
- No tenant/organization selector or identifier anywhere in the UI (R35 — tenant scoping is invisible to this screen).
- No raw API error envelope (`code`/`trace_id`) shown to the end user — only the human-readable message (design.md Cross-cutting/errors).
- No column not listed in the capability's per-mode column table (R6) — e.g. no "Disabled" column on modes other than By Broker.

## Could not be generated

None — every frame in `states.md` maps to a component already defined in
`design-system.md` (table, card, status badge, error block, empty state, notice,
skeleton bar).

## Open questions affecting this inventory

- Q1 (requirements.md): if UNIT-CMS-0006 is not in fact the detail/create-screen owner, the row-open and create-launch navigation targets change, but no frame here changes shape as a result — navigation destination is not drawn in a mockup.
