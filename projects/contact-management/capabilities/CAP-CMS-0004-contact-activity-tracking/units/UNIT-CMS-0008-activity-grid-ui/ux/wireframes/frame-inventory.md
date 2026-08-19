# Frame inventory — Activity Grid UI

**Source position:** no design file exists. This is the ordinary case — the frames
below are generated directly against `design-system.md`, per `designer-unit-ux`
step 1.

**Constraints every frame respects:** all three canvas widths (360/768/1440) are
reachable via the mockup's width control; both themes (light/dark) via the theme
toggle; text contrast ≥4.5:1 and UI contrast ≥3:1 per the design system's token
pairs; interactive targets ≥24×24 CSS px; usable at 200% zoom; no horizontal page
scroll at 320px (the data table itself switches to a card layout below the
`tablet` width — see `components.md` § Layout); colour is never the sole carrier
of meaning (every disabled/error/success state also carries text or an icon).

There is no `active`/`pending`/`lapsed` status enum anywhere in this unit's data
(`statusId` is a task-type/status controlled list scoped by parent type, not the
capability-wide lifecycle badge design-system.md § 7 describes) — no
`status-matrix` frame is drawn for that reason; see "What must NOT be drawn".

## Frames

| # | Frame (kebab-case) | Width | What it shows | States.md row |
|---|---|---|---|---|
| 1 | `loading` | desktop | Skeleton rows in place of the grid on initial mount | loading |
| 2 | `populated-editor` | desktop | Full grid, Editor role — sort/filter controls and a load-more control (shown while `next_cursor` is non-null), add/edit/complete/delete controls all visible | populated (Editor) |
| 3 | `populated-viewer` | desktop | Same data, Viewer role — sort/filter/load-more visible, no write controls rendered | populated (Viewer); disabled/unauthorized |
| 4 | `empty-first-use` | desktop | Zero entries exist yet for this parent, no filter applied | empty — first-use |
| 5 | `empty-filtered` | desktop | A filter/sort is applied and zero entries match it | empty — filtered-to-nothing |
| 6 | `add-form-open` | desktop | Inline add form open, valid empty state, submit enabled once required fields are filled | submitting (pre-submit) |
| 7 | `add-form-validation-error` | desktop | Add form after a `400`/`422`, field-level error shown, submit re-enabled | error — recoverable (field-level) |
| 8 | `row-submitting` | desktop | One row's edit/complete/delete control disabled mid-request; rest of the grid remains interactive | submitting |
| 9 | `delete-confirm` | desktop | The explicit second confirm step before a soft-delete call is made | submitting (pre-confirm) |
| 10 | `error-dependency-down` | desktop | Initial load failed (timeout/connection failure) — error block with retry | error — recoverable |
| 11 | `throttled` | desktop | A `429` response — "try again" state honoring `Retry-After` | error — recoverable (rate-limited) |
| 12 | `session-expired` | desktop | A `401` mid-flow — session-expired state, in-progress form values preserved | session expiry mid-flow |
| 13 | `row-not-found` | desktop | A `404` on edit/complete/delete — "no longer available", row removed | error — terminal (per-row) |
| 14 | `offline-on-load` | desktop | Device is offline when the component mounts | offline — on load |
| 15 | `offline-on-submit` | desktop | Device goes offline with a mutation already in flight | offline — on submit |
| 16 | `success-confirmation` | desktop | Brief inline confirmation after a successful add/edit/complete/delete | success |
| 17 | `populated-editor` (mobile check) | mobile | Same as #2, verifying the table-to-card reflow at 360px | populated (Editor) |

Every frame except #17 is specified at `desktop` by default; the width control
still reaches `mobile`/`tablet` for all of them, and #17 is the one a reviewer
should check first at 360px, per `components.md` § Layout.

**`partial`** (some data loaded, some failed) has no frame: a single bounded list
call either returns a full page or it does not — there is no code path in this
unit where some rows of one response succeeded and others failed, so the row in
`states.md` is answered "N/A" rather than drawn.

## What must NOT be drawn

- No `status-matrix` frame — this unit renders no active/pending/lapsed lifecycle
  badge (see above).
- No delete control, edit control, add control, or "mark complete" control in
  `populated-viewer` — a Viewer-role session must not see them rendered-and-disabled
  either; they are absent, not greyed out (R12/R28).
- No completion-date input anywhere, including in `add-form-open` or any edit
  frame — completion date is never a field a caller can type into (R7).
- No `userName` input field anywhere — it is display-only, never editable (R5).
- No page-number/page-size pagination style anywhere — matching UNIT-CMS-0007's
  cursor-based contract (`limit`+`cursor` in, `items`+`next_cursor` out), rendered
  as a single "load more" control, not a page-number list.
- No retry affordance on `row-not-found` — a 404'd row is removed, not retried
  (R11).

## Open questions affecting the inventory

None. `requirements.md` records no blocking open questions for this unit.
