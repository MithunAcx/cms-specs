# Frame inventory — UNIT-CMS-0006 Partner Records UI

## Interaction model

The mockup is a real, runnable click-through prototype backed by a small in-memory
demo dataset (a few brokerages/agencies with brokers/agents/policies, and a few CGA
rows), not only a frame-switcher over static snapshots. All 19 frames below remain
directly reachable via the dropdown switcher for reviewers, unchanged in name and
content. In addition, the three data-driven frames —
`brokerage-detail-populated`, `agency-detail-populated`, `cga-grid-populated` — are
now also reachable through ordinary interaction from within the mockup itself:

- The `.tabs` bar on Brokerage/Agency Detail performs a real panel swap
  (Details/Brokers/Activity/Policies and Details/Agents/Activity/Policies), not a
  static, pre-selected `active` class.
- "Accounting address" opens a real dialog over Brokerage Detail; "Add Brokerage" /
  "Add Agency" run real client-side validation (states.md's Validation messages
  table) and, on success, create the record in the in-memory dataset and navigate —
  Add Agency's two-choice confirmation (R15) is a real dialog with both outcomes
  wired.
- The Brokers/Agents "Load more" row appends the next in-memory page (cursor
  simulated client-side); the CGA grid's Edit action turns a real row into inputs,
  validates, and saves back into the in-memory row.
- Loading and "unable to load"/offline states for these three frames are reachable
  by navigating to them (a short simulated fetch delay plays every time), and the
  demo-only toolbar (`simulate next save as 409 conflict` / `simulate next load as
  failed` / `simulate offline`) makes the corresponding error states in `states.md`
  reachable on demand without a real backend. These toolbar controls are clearly
  marked demo-only and are not part of the specified UI.

This does not change what each of the 19 frames shows or means — it changes how a
reviewer can reach the live ones, in addition to jumping straight to any named frame.

## Source position

No design file exists for this unit. The generated HTML mockup at
`UNIT-CMS-0006-partner-records-ui.html` (this folder) is the source of truth for
layout, per `designer-unit-ux` output #1. Its class names for the tab bar (`.tabs`),
tables (`.tbl`/`.tbl-wrap`), dialogs (`.overlay`/`.scrim`/`.box`/`.dialog`/
`.dialog-head`/`.dialog-body`/`.dialog-foot`) and status badges (`.badge-active`/
`.badge-warn`/`.badge-lapsed`/`.badge-neutral`) are taken **verbatim** from the
sponsor-provided reference,
`requirements/contactmanagement-full-mockup.html` (Brokerage Detail ~line 285,
Agency Detail ~line 354, CGA Management ~line 423, Add Agency/Add Brokerage/
Accounting Address dialogs ~lines 442–510), so this unit's Brokerage Detail, Agency
Detail, CGA grid, and the three dialogs are structurally traceable to that reference.
Colour tokens, type scale, spacing and component geometry remain
`design-system.md`'s own values (which are themselves aligned to the same reference's
crimson-on-warm-slate palette per `design-system.md` §2) — the reference's Google
Font import, gradients, box-shadows and CSS animations are not reproduced, because
`design-system.md` §8 forbids external resources and those effects outright; this is
a deliberate, reported deviation, not an oversight.

## Constraints every frame respects

- All three canvas widths (`mobile` 360 / `tablet` 768 / `desktop` 1440) are reachable
  via the mockup's width control on every frame; a frame below is named for the width
  it was **specified** against, and a reviewer checks that width first.
- Both themes (`light`/`dark`) are reachable via the theme toggle on every frame.
- Contrast, target size, zoom, and colour-is-never-sole-carrier per `a11y.md`.
- Every literal value (colour, spacing, type, component geometry) comes from
  `design-system.md` — no improvised values.
- Field shapes shown (brokerage/agency/broker/agent/CGA/accounting-address) match
  `UNIT-CMS-0005`'s `interfaces/openapi.yaml` field-for-field (e.g. `address` as
  `line1`/`line2`/`city`/`state`/`zip`, `accountCode` read-only, `disabled` as a
  boolean flag rather than a status string). Policy fields shown on the Policies tab
  match `UNIT-CMS-0010`'s copied `interfaces/UNIT-CMS-0010.openapi.yaml`
  (`policyId`, `status`, `term`, `insured`, `classId`, `subclass`) — no field is drawn
  that either real contract does not have. `deepLinkUrl` is never rendered as a
  concrete `href`; the "Open in policy system" control is drawn disabled with no
  destination, since the URL is server-computed and no concrete endpoint may be
  invented here (`00-core.md`).
- The Brokers and Agents grids show a "Load more" row when a further page may exist,
  reflecting UNIT-CMS-0005's cursor-based `items`/`next_cursor` pagination (PR #60)
  rather than the reference mockup's unpaginated static list. The Policies list and
  the CGA grid are not paginated in the mockup, because neither contract
  (`UNIT-CMS-0010`'s policy read, `UNIT-CMS-0005`'s CGA create/read surface as used
  by this unit) exposes a cursor for them.

## Frames

Several `states.md` rows that differ only in copy (e.g. `409` conflict, `429` rate
limit, timeout/unresolved, and session-expiry) share one representative frame per
view, using the same banner/notice layout — the copy table in `states.md` is what
differentiates them textually; the visual treatment does not change per error
subtype. This is noted per row below rather than drawing a separate frame for each.

| # | Frame (kebab-case) | Shows | `states.md` row | Width |
|---|---|---|---|---|
| 1 | `brokerage-detail-populated` | Brokerage Detail: `.tabs` tab bar (Details/Brokers/Activity/Policies), master details, `.tbl` Brokers grid with a cursor "Load more" row, an embedded Contact-activity placeholder (UNIT-CMS-0008), a `.tbl` Policies list with `.badge-active`/`.badge-warn` status, accounting-address control | Brokerage Detail — populated | desktop |
| 2 | `brokerage-detail-loading` | Brokerage Detail with skeleton blocks in every region | Brokerage Detail — loading | desktop |
| 3 | `brokerage-detail-empty-brokers` | Brokerage Detail with an empty Brokers grid | Brokerage Detail — empty | desktop |
| 4 | `brokerage-detail-conflict` | Brokerage Detail with the conflict banner shown after a stale save; also representative of `429`/timeout/session-expiry banner variants (copy differs, layout does not) | Brokerage Detail — error-recoverable, offline — on submit, session expiry mid-flow | desktop |
| 5 | `brokerage-detail-not-found` | Full-screen "This brokerage could not be found" terminal state | Brokerage Detail — error-terminal | desktop |
| 6 | `brokerage-detail-readonly` | Brokerage Detail with every edit control absent (Viewer-role session) | Brokerage Detail — disabled/no permission | desktop |
| 7 | `accounting-address-dialog` | The accounting-address dialog, open over Brokerage Detail | Accounting-address dialog — populated | desktop |
| 8 | `add-brokerage-populated` | Add New Brokerage form, empty and ready | Add New Brokerage — populated | desktop |
| 9 | `add-brokerage-validation-error` | Add New Brokerage form with per-field validation messages shown | Add New Brokerage — error-recoverable | desktop |
| 10 | `agency-detail-populated` | Agency Detail: `.tabs` tab bar (Details/Agents/Activity/Policies), master details, `.tbl` Agents grid with a cursor "Load more" row, an embedded Contact-activity placeholder (UNIT-CMS-0008), a `.tbl` Policies list, Specialty link | Agency Detail — populated | desktop |
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
badge, Dialog, Empty state, Error block, Notice, Skeleton bar). The reference
mockup's visual flourishes that `design-system.md` §8 forbids outright — the Google
Font import, gradients, box-shadows, and CSS animations on the dialog open/close and
toast — are not a missing component; they are excluded by that section's rule, and
are called out above rather than silently applied.

## Open questions affecting the inventory

None outstanding for this unit — see `requirements.md` Open questions (empty) and
Assumptions.
