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
| Add/edit activity form | Inline form for creating or editing an entry | R4, R5, R6, R9, R10, R12, R14, R15, R28 |
| Delete-confirm dialog | The explicit second step before a soft-delete call | R8, R11, R14 |
| Filter/sort bar | Completed/open filter, follow-up-date sort control | R1, R2 |
| Pagination control | Page navigation against UNIT-CMS-0007's page/size contract | R3 |

### Activity grid

**Purpose.** Fetches and renders one page of activity entries for a caller-supplied
`parentType`/`parentId`, and hosts the filter/sort/pagination controls.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `parentType` | enum: `agency` \| `brokerage` | yes | — | Supplied by the host screen; never chosen by this component |
| `parentId` | id | yes | — | Supplied by the host screen |
| `outcome` | enum: `loading` \| `populated` \| `empty-first-use` \| `empty-filtered` \| `error-dependency` \| `error-throttled` \| `error-offline` \| `session-expired` | yes | — | One input drives which of these mutually-exclusive states renders, rather than several booleans that could combine into a state that should not exist |
| `role` | enum: `viewer` \| `editor` | yes | — | Read from the session context; determines whether write controls exist in the DOM at all |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `sort-changed` | `{ field, direction }` | Caller changes the sort control |
| `filter-changed` | `{ completed: boolean \| null }` | Caller changes the completed/open filter |
| `page-changed` | `{ page }` | Caller navigates pagination |
| `retry-requested` | — | Caller activates retry on an error/offline state |
| `add-requested` | — | Editor activates the add control |

**States it must render:** see `states.md` § Activity grid.

**Accessibility contract:** `table` semantics, live-region error/session-expired
announcements — see `a11y.md`.

### Activity row

**Purpose.** Renders one entry's fields and, for Editor, its per-row actions;
manages that row's own submitting/error/success sub-state independently of the
rest of the grid.

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

### Add/edit activity form

**Purpose.** Collects `statusId`, `note`, `followUpDate` for a new or existing
entry. Never presents `userName`, `enteredDate`, `completedDate`, or `id` as
inputs — those fields do not exist in this component's input set at all (R5).

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `mode` | enum: `add` \| `edit` | yes | — | — |
| `parentType` | enum: `agency` \| `brokerage` | yes | — | Threaded through unmodified from the grid |
| `initialValues` | `{ statusId, note, followUpDate }` | edit mode only | — | Pre-populates the form when editing |
| `outcome` | enum: `idle` \| `submitting` \| `error-field` \| `error-session-expired` | yes | `idle` | One input, not independent booleans |
| `fieldErrors` | `{ field, message }[]` | no | `[]` | Populated from the server's `400`/`422` `fields` array |

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
loss.

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

### Pagination control

**Purpose.** Navigates the page/size contract UNIT-CMS-0007 exposes.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `page` | integer ≥ 1 | yes | 1 | — |
| `size` | integer, 1–100 | yes | 25 | Matches the platform pagination default/maximum |
| `total` | integer ≥ 0 | yes | — | — |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `page-changed` | `{ page }` | — |

**States it must render:** always interactive, including for Viewer role.

**Accessibility contract:** `navigation` landmark, `aria-current="page"` — see
`a11y.md`.

## Layout

Responsive behaviour by breakpoint, described in terms of what reflows.

| Breakpoint | Behaviour |
|---|---|
| `desktop` (1440) and `tablet` (768) | Real table: one row per entry, all columns visible, actions right-aligned in the last cell |
| `mobile` (360) | The table becomes a stack of cards, one per entry (per `design-system.md`'s Card component) — each card shows the same fields as a row, labelled, with actions below the note text; filter/sort/pagination controls stack vertically above the list |
