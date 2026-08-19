# Components — Activity Grid UI

Unit-local inventory. Describes components by behaviour and contract, never by
framework or file path.

## Reused

Components that already exist elsewhere and are used as-is.

| Component | Source | Used for |
|---|---|---|
| Session/role context | UNIT-CMS-0001 | Supplies the bearer token and the caller's role (Viewer/Editor) this component reads to gate controls (R12/R28) and to detect session expiry (R13) |

## Added by this unit

| Component | Purpose | Satisfies |
|---|---|---|
| Activity grid | The list/sort/filter/paginate surface | R1, R2, R3, R17, R18, R20, R29 |
| Activity row | One entry's read display plus (Editor only) its edit/complete/delete controls | R6, R7, R8, R11, R12, R14, R28 |
| Activity Editor dialog | Modal dialog for creating or editing an entry, matching the reference product mockup's Activity Editor pattern | R4, R5, R6, R9, R10, R12, R14, R15, R28 |
| Delete-confirm dialog | The explicit second step before a soft-delete call | R8, R11, R14 |
| Filter/sort bar | Completed/open filter, follow-up-date sort control | R1, R2 |
| Load-more control | Cursor-based next-page navigation against UNIT-CMS-0007's `limit`/`cursor` contract | R3 |

### Activity grid

**Purpose.** Fetches and renders a cursor-based page of activity entries for a
caller-supplied `parentType`/`parentId`, and hosts the filter/sort/load-more controls.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `parentType` | enum: `agency` \| `brokerage` | yes | — | Supplied by the host screen; never chosen by this component |
| `parentId` | id | yes | — | Supplied by the host screen |
| `outcome` | enum: `loading` \| `populated` \| `empty-first-use` \| `empty-filtered` \| `error-dependency` \| `error-throttled` \| `error-offline` \| `session-expired` | yes | — | One input drives which of these mutually-exclusive states renders, rather than several booleans that could combine into a state that should not exist |
| `role` | enum: `viewer` \| `editor` | yes | — | Read from the session context; determines whether write controls exist in the DOM at all |
| `nextCursor` | string \| null | yes | `null` | Drives whether the load-more control renders — present only while non-null |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `sort-changed` | `{ field, direction }` | Caller changes the sort control |
| `filter-changed` | `{ completed: boolean \| null }` | Caller changes the completed/open filter |
| `load-more-requested` | `{ cursor }` | Caller activates the load-more control |
| `retry-requested` | — | Caller activates retry on an error/offline state |
| `add-requested` | — | Editor activates the add control |

**States it must render:** see `states.md` § Activity grid.

**Accessibility contract:** `table` semantics, live-region error/session-expired
announcements — see `a11y.md`.

### Activity row

**Purpose.** Renders one entry's fields and, for Editor, its per-row actions;
manages that row's own submitting/error/success sub-state independently of the
rest of the grid. The completed/open indicator is a two-state badge (shape dot
+ text label, never colour alone), matching the reference product mockup's
badge component for status.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `entry` | Activity (id, statusId, note, followUpDate, enteredDate, completed, completedDate, userName) | yes | — | Read-only fields as returned by UNIT-CMS-0007; this component never constructs `userName` or `completedDate` |
| `role` | enum: `viewer` \| `editor` | yes | — | Gates whether edit/complete/delete controls exist |
| `outcome` | enum: `idle` \| `submitting` \| `success` \| `error-field` \| `error-gone` | yes | `idle` | One input, not independent booleans |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `edit-requested` | `{ id }` | Editor activates edit |
| `complete-requested` | `{ id }` | Editor activates mark-complete |
| `delete-requested` | `{ id }` | Editor activates delete (opens the confirm dialog; does not call the API directly) |

**States it must render:** see `states.md` — `submitting`, `success`,
`error — terminal (row no longer available)`.

**Accessibility contract:** each action button's accessible name disambiguates the
row (e.g. by entered date) — see `a11y.md`.

### Activity Editor dialog

**Purpose.** Collects `statusId`, `note`, `followUpDate` for a new or existing
entry, presented as a modal dialog — the same construct the reference product
mockup's own Activity Editor uses (a titled header, a body holding the fields,
and a footer holding Cancel/Save) — rather than an inline form embedded in the
grid. Never presents `userName`, `enteredDate`, `completedDate`, `id`, or a
completed/completion-date field as inputs — those fields do not exist in this
component's input set at all (R5, R7). The reference's own Activity Editor
includes a "Completed" checkbox in this same dialog; this unit deliberately
omits it, because R7 makes "mark complete" a separate, single-action row
control and this dialog's own field set is fixed at add/edit time only.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `mode` | enum: `add` \| `edit` | yes | — | — |
| `parentType` | enum: `agency` \| `brokerage` | yes | — | Threaded through unmodified from the grid |
| `initialValues` | `{ statusId, note, followUpDate }` | edit mode only | — | Pre-populates the form when editing |
| `outcome` | enum: `idle` \| `submitting` \| `error-field` \| `error-session-expired` | yes | `idle` | One input, not independent booleans |
| `fieldErrors` | `{ field, message }[]` | no | `[]` | Populated from the server's `400`/`422` `details[]` array |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `submitted` | `{ statusId, note, followUpDate }` | Caller submits a client-valid form |
| `cancelled` | — | Caller presses Esc or a cancel control |

**States it must render:** see `states.md` — `submitting`, `error — recoverable
(field-level)`, `session expiry mid-flow`.

**Accessibility contract:** focus moves to the first field on open, back to the
opening control on close, to the first invalid field's message on a validation
error — see `a11y.md`.

### Delete-confirm dialog

**Purpose.** The explicit second step required before a soft-delete call is made
(R8), reducing accidental, effectively-irreversible-from-the-caller's-view data
loss. Uses the same dialog construct as the Activity Editor; its confirm
action is styled as a destructive action (the reference product mockup's own
danger-button treatment), distinct from the primary Save action elsewhere.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `outcome` | enum: `idle` \| `submitting` | yes | `idle` | — |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `confirmed` | — | Caller activates the dialog's own delete/confirm control |
| `cancelled` | — | Caller activates cancel or presses Esc |

**States it must render:** see `states.md` — `submitting`.

**Accessibility contract:** `alertdialog` semantics, modal (background inert),
focus trapped within it while open, returns to the triggering row's delete
control on close — see `a11y.md`.

### Filter/sort bar

**Purpose.** Exposes the completed/open filter and the follow-up-date sort,
composable with each other (R2).

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `completedFilter` | enum: `all` \| `open-only` | yes | `open-only`* | *Assumption recorded in `requirements.md` — no default was specified in the raw ask |
| `sortDirection` | enum: `asc` \| `desc` | yes | `asc` | Ascending = soonest follow-up first |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `filter-changed` | `{ completedFilter }` | — |
| `sort-changed` | `{ sortDirection }` | — |

**States it must render:** always interactive, including for Viewer role
(R1/R2/R12).

**Accessibility contract:** see `a11y.md` § Semantics (columnheader, filter
group).

### Load-more control

**Purpose.** Requests the next cursor-based page from UNIT-CMS-0007's list endpoint
(`limit`+`cursor` in, `items`+`next_cursor` out per `10-platform.md`). There is no
page number or total count to render — cursor pagination exposes neither.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `nextCursor` | string \| null | yes | `null` | Control renders only while non-null; absent once the last page is reached |
| `loading` | boolean | yes | `false` | Disables the control for the duration of the in-flight request (R14) |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `load-more-requested` | `{ cursor }` | Caller activates the control |

**States it must render:** hidden when `nextCursor` is `null`; disabled while
`loading`; otherwise always interactive, including for Viewer role.

**Accessibility contract:** a single button, accessible name "Load more activity",
appended results announced via the grid's live region rather than a page-change
announcement — see `a11y.md`.

## Layout

Responsive behaviour by breakpoint, described in terms of what reflows.

| Breakpoint | Behaviour |
|---|---|
| `desktop` (1440) and `tablet` (768) | Real table: one row per entry, all columns visible, actions right-aligned in the last cell |
| `mobile` (360) | The table becomes a stack of cards, one per entry — each card shows the same fields as a row, labelled, with actions below the note text; filter/sort/load-more controls stack vertically above the list |

## Visual system

This unit's screens are drawn from the reference product mockup's design
system (`requirements/contactmanagement-full-mockup.html`), not from a
component vocabulary invented for this unit alone, so that the embedded grid
reads as part of the same product as the host screen (UNIT-CMS-0006) rather
than a visually distinct island. Concretely, this unit's mockup reuses,
verbatim by name and structure:

| Reference class(es) | Used for |
|---|---|
| `.btn` / `.btn-primary` / `.btn-secondary` / `.btn-ghost` / `.btn-danger` / `.btn-sm` | Every button in the grid, dialogs and toolbar. `.btn-danger` is reserved for the destructive delete actions (row delete, delete-confirm dialog); `.btn-primary` is reserved for the affirmative Save action; row-level Edit uses `.btn-ghost` |
| `.tbl-wrap` / `table.tbl` | The activity grid itself |
| `.badge` / `.dot` / `.badge-active` / `.badge-warn` | The completed/open indicator — a shape dot plus a text label, colour is reinforcement only |
| `.overlay` / `.scrim` / `.box` / `.dialog` / `.dialog-head` / `.dialog-body` / `.dialog-foot` | The Activity Editor and Delete-confirm dialogs |
| `.field` / `.inp` / `.help-err` | Every form field and its validation message |
| `.panel` / `.empty` / `.card` | Panel framing, the empty-state block, and the mobile card layout |
| `.toast-in` | The success-confirmation frame's inline saved indicator |

The colour tokens (`--brand`, `--bg`, `--panel`, `--text`, etc.) and the
type family (`Inter`, falling back to system/Segoe UI fonts since no external
font request is permitted in a self-contained mockup) are copied from the same
reference file. Two deliberate departures from the reference, both required by
this repo's accessibility floor rather than by preference: no CSS `animation`
or `transition` is used anywhere (`a11y.md` commits this component to no
motion), and the `.overlay` construct is positioned relative to its own frame
section rather than `position: fixed` to the viewport, so each of this one
file's frames stays independently switchable — the real component's actual
modal/fixed placement is specified in `a11y.md`'s text, not by this rendering.
