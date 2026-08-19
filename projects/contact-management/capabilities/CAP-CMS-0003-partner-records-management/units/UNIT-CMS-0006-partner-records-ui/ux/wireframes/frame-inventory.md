# Frame inventory — UNIT-CMS-0006 Partner Records UI

## Source position

No design file exists for this unit. This is the ordinary case: the generated HTML
mockup at `UNIT-CMS-0006-partner-records-ui.html` (this folder) is the source of
truth for layout, per `designer-unit-ux` output #1.

## Constraints every frame respects

- All three canvas widths (`mobile` 360 / `tablet` 768 / `desktop` 1440) are reachable
  via the mockup's width control on every frame; a frame below is named for the width
  it was **specified** against, and a reviewer checks that width first.
- Both themes (`light`/`dark`) are reachable via the theme toggle on every frame.
- Contrast, target size, zoom, and colour-is-never-sole-carrier per `a11y.md`.
- Every literal value (colour, spacing, type, component geometry) comes from
  `design-system.md` — no improvised values.

## Frames

Several `states.md` rows that differ only in copy (e.g. `409` conflict, `429` rate
limit, timeout/unresolved, and session-expiry) share one representative frame per
view, using the same banner/notice layout — the copy table in `states.md` is what
differentiates them textually; the visual treatment does not change per error
subtype. This is noted per row below rather than drawing a separate frame for each.

| # | Frame (kebab-case) | Shows | `states.md` row | Width |
|---|---|---|---|---|
| 1 | `brokerage-detail-populated` | Brokerage Detail: master details, Brokers grid, activity/policy tabs, accounting-address control | Brokerage Detail — populated | desktop |
| 2 | `brokerage-detail-loading` | Brokerage Detail with skeleton blocks in every region | Brokerage Detail — loading | desktop |
| 3 | `brokerage-detail-empty-brokers` | Brokerage Detail with an empty Brokers grid | Brokerage Detail — empty | desktop |
| 4 | `brokerage-detail-conflict` | Brokerage Detail with the conflict banner shown after a stale save; also representative of `429`/timeout/session-expiry banner variants (copy differs, layout does not) | Brokerage Detail — error-recoverable, offline — on submit, session expiry mid-flow | desktop |
| 5 | `brokerage-detail-not-found` | Full-screen "This brokerage could not be found" terminal state | Brokerage Detail — error-terminal | desktop |
| 6 | `brokerage-detail-readonly` | Brokerage Detail with every edit control absent (Viewer-role session) | Brokerage Detail — disabled/no permission | desktop |
| 7 | `accounting-address-dialog` | The accounting-address dialog, open over Brokerage Detail | Accounting-address dialog — populated | desktop |
| 8 | `add-brokerage-populated` | Add New Brokerage form, empty and ready | Add New Brokerage — populated | desktop |
| 9 | `add-brokerage-validation-error` | Add New Brokerage form with per-field validation messages shown | Add New Brokerage — error-recoverable | desktop |
| 10 | `agency-detail-populated` | Agency Detail: master details, Agents grid, activity/policy tabs, Specialty link | Agency Detail — populated | desktop |
| 11 | `agency-detail-empty-agents` | Agency Detail with an empty Agents grid | Agency Detail — empty | desktop |
| 12 | `add-agency-populated` | Add New Agency form, empty and ready | Add New Agency — populated | desktop |
| 13 | `add-agency-confirm-dialog` | The two-choice confirmation dialog after a successful agency create | Two-choice confirmation dialog — populated | desktop |
| 14 | `cga-grid-populated` | CGA grid with rows | CGA grid — populated | desktop |
| 15 | `cga-grid-empty` | CGA grid with zero rows | CGA grid — empty | desktop |
| 16 | `cga-grid-row-editing` | CGA grid with one row in inline-edit mode | CGA grid — submitting (editing state immediately prior) | desktop |
| 17 | `reference-lookup-admin` | Reference-lookup screen, Administrator session (add/edit/delete controls visible) | Reference-lookup admin — populated | desktop |
| 18 | `reference-lookup-readonly` | Reference-lookup screen, non-Administrator session (no mutating controls) | Reference-lookup admin — disabled/no permission | desktop |
| 19 | `status-matrix` | All four status badges (active/pending/lapsed/neutral), per `design-system.md` §7's mandatory frame | — (design-system requirement, not a `states.md` row) | desktop |

Every frame above is reachable at `mobile` and `tablet` via the mockup's width
control to verify reflow (`components.md` Layout table), even though each row names
only the width it was specified against.

## What must NOT be drawn

- No delete control on the Brokers/Agents grids — this capability's requirements
  (R9, R18) specify add and edit only, never delete of a broker/agent record.
- No bulk/batch action on any grid (no "select all", no multi-row delete) — not
  requested by any requirement.
- No numeric input for CGA phone — it is a formatted string field per R23, never a
  number spinner.
- No visible tenant selector or tenant identifier field anywhere — tenant scoping is
  implicit in the session per R51, never a UI choice.
- No "forgot password" or session-management control on any screen in this unit —
  owned by UNIT-CMS-0001, not embedded here.
- No retry-without-limit affordance on `add-brokerage`/`add-agency` create — R38
  requires the control stay disabled between submission and response; no "submit
  again while pending" control is ever shown.
- No auto-refresh/auto-save indicator — every save in this unit is explicit
  user-initiated action (Approach: screen-scoped state, no shared cache).

## Could not be generated

None. Every frame above is expressible from `design-system.md`'s existing
components (App header, Tab bar, Button variants, Input field, Table, Card, Status
badge, Dialog, Empty state, Error block, Notice, Skeleton bar).

## Open questions affecting the inventory

None outstanding for this unit — see `requirements.md` Open questions (empty) and
Assumptions.
