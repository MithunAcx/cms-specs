# Components — Partner Records UI

Unit-local inventory. Describes components by behaviour and contract, never by
framework or file path.

## Reused

Components that already exist elsewhere and are used as-is.

| Component | Source | Used for |
|---|---|---|
| Address-suggest widget | UNIT-CMS-0009 | Every address entry point: Add New Brokerage, Add New Agency, accounting-address dialog, CGA row (R2, R14, R22) |
| Contact-activity grid | UNIT-CMS-0008 | Embedded panel on Brokerage Detail and Agency Detail (R10, R19) |
| Policy-activity grid | UNIT-CMS-0010 | Embedded panel on Brokerage Detail and Agency Detail (R10, R19) |

## Added by this unit

| Component | Purpose | Satisfies |
|---|---|---|
| Inline grid editor | Row-level add/edit/save for Brokers, Agents, and CGA grids | R9, R18, R21, R38 |
| Conflict/error presenter | Maps UNIT-CMS-0005's error envelope to the distinguishable states named in `states.md` | R31, R32, R33, R36, R37, R40, R47 |
| Two-choice confirmation dialog | Post-create choice for Add New Agency | R15 |
| Accounting-address dialog | Focused edit of accounting fields only | R11, R12 |
| Reference-lookup admin list | Role-gated view/edit of a single lookup type | R25, R26, R27, R39 |

### Inline grid editor

**Purpose.** Lets a user list child records (brokers on a brokerage, agents on an
agency, CGA rows) and edit exactly one row at a time in place, without navigating
away from the parent screen.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| rows | list of child records | yes | — | Each row carries its own id and `version` |
| columns | list of field definitions | yes | — | Differ per grid (broker/agent/CGA field sets per R9/R18/R21) |
| outcome | one of: `idle`, `loading`, `empty`, `row-editing`, `row-saving`, `row-error` | yes | `idle` | A single outcome input, not combinable booleans, per `60-frontend.md`'s component guidance |
| readOnly | boolean | yes | `false` | `true` when the session lacks the required role (R39) |
| nextCursor | string or null | no | `null` | Present only for the Brokers/Agents grids, which are cursor-paginated per UNIT-CMS-0005's `BrokerListResponse`/`AgentListResponse` (`items`/`next_cursor`, PR #60). `null` hides the "Load more" control. The CGA grid has no cursor input — its listing surface returns an unpaginated set |

**Events**

| Event | Payload | When |
|-------|---------|------|
| rowEditRequested | row id | User activates a row's Edit control |
| rowSaveRequested | row id, edited fields, `version` | User confirms a row's edit |
| rowSaveSucceeded | row id, updated fields, new `version` | The corresponding create/update call resolves successfully |
| rowSaveFailed | row id, error envelope | The call fails — the conflict/error presenter renders inside that row only |
| rowEditCancelled | row id | User presses Esc or a Cancel control while editing a row |
| loadMoreRequested | current `nextCursor` | User activates "Load more" on the Brokers/Agents grid (cursor-based, per 10-platform.md — never a page number) |

**States it must render:** see `states.md` — the loading/empty/populated/submitting/
error-recoverable/offline/session-expiry rows of each grid's view.

**Accessibility contract:** the grid is a real `table`; a row in edit mode exposes its
input controls in the same reading order as its read-only cells; Esc reverts that row
only; see `a11y.md` Keyboard map and Semantics.

### Conflict/error presenter

**Purpose.** A single, consistently-applied mapping from UNIT-CMS-0005's
`{ code, message, details[], trace_id }` envelope to one of the distinguishable
outcomes this unit's requirements name, so every screen presents `409`, `400`,
`403`, `429`, and timeout/`5xx` identically rather than each screen inventing its
own wording.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| outcome | one of: `conflict`, `validation`, `notPermitted`, `rateLimited`, `unresolved`, `notFound` | yes | — | Derived once from the response, never combined |
| details | list of `{ field, message }` | no | `[]` | Only present for `validation` |
| retryAfterSeconds | integer | no | — | Only present for `rateLimited` |

**Events**

| Event | Payload | When |
|-------|---------|------|
| retryRequested | — | User activates the presenter's retry/reload action |

**States it must render:** the "error — recoverable" and "error — terminal" rows of
every view in `states.md`.

**Accessibility contract:** rendered inside an `alert` region so it is announced
immediately; see `a11y.md` Announcements.

### Two-choice confirmation dialog

**Purpose.** Presents exactly the two post-create choices FR-AGY-2 specifies,
without a third implicit option (e.g. a bare close/X that would leave the outcome
undefined).

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| agencyName | string | yes | — | Names the just-created agency in the confirmation text |
| agencyId | string (uuid) | yes | — | Used by the "Go to Agency Detail" action |

**Events**

| Event | Payload | When |
|-------|---------|------|
| goToDetailChosen | agencyId | User activates "Go to Agency Detail" |
| addAnotherChosen | — | User activates "Add another agency" |

**States it must render:** the "populated" row of its own view in `states.md`; no
other state applies to this dialog.

**Accessibility contract:** modal dialog, focus trapped, focus moves to its heading
on open; see `a11y.md`.

### Accounting-address dialog

**Purpose.** Isolated edit surface for a brokerage's accounting/billing address so
editing it can never be confused with, or accidentally submit, the master-details
fields (R12).

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| brokerageId | string (uuid) | yes | — | — |
| accountingFields | `{ contactName, line1, line2, city, state, zip }` | yes | — | XD-0004 address shape |
| version | string/opaque | yes | — | Carried unmodified until save, per R30 |

**Events**

| Event | Payload | When |
|-------|---------|------|
| saveRequested | edited fields, `version` | User activates Save |
| cancelled | — | User activates Cancel or Esc |

**States it must render:** the Accounting-address dialog view in `states.md`.

**Accessibility contract:** modal dialog, focus trapped, focus returns to the
opening control on close; see `a11y.md`.

### Reference-lookup admin list

**Purpose.** One screen shape, parametrized by lookup type, so states/broker
types/agent types/broker statuses/task-activity statuses all get identical
Administrator maintenance behaviour rather than five bespoke screens (R25–R27).

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| lookupType | one of: `states`, `broker-types`, `agent-types`, `broker-statuses`, `task-statuses` | yes | — | — |
| values | ordered list of `{ id, label, order }` | yes | — | — |
| readOnly | boolean | yes | `true` | `false` only for an Administrator session (R25/R26/R39) |

**Events**

| Event | Payload | When |
|-------|---------|------|
| valueAddRequested | new value fields | Administrator adds a value |
| valueEditRequested | value id, edited fields | Administrator edits a value |
| valueDeleteRequested | value id | Administrator deletes a value |

**States it must render:** the Reference-lookup admin view in `states.md`.

**Accessibility contract:** a real list/table; Administrator-only controls are
absent from the accessibility tree entirely for a non-Administrator session, not
merely visually hidden; see `a11y.md`.

## Layout

Responsive behaviour by breakpoint, described in terms of what reflows.

| Breakpoint | Behaviour |
|---|---|
| `mobile` (360) | Master-details fields stack in a single column; Brokers/Agents/CGA grids render as a stacked list of Cards (design-system §5) instead of a table, one card per row; embedded activity/policy panels stack below the master details as full-width sections rather than side-by-side tabs |
| `tablet` (768) | Master-details fields render two per row where paired (city/state/zip); grids render as a real table with horizontal scroll inside their own region if needed, never scrolling the page; embedded panels render as tabs |
| `desktop` (1440) | Full multi-column master-details layout; grids render as a full-width table with no scrolling needed at typical row counts; embedded panels render as tabs alongside the Brokers/Agents grid |

German text expansion (1.4×, per `60-frontend.md`) is accommodated by every label
using `.text-caption`/`.text-body` with no fixed-width truncation on field labels or
button text; buttons size to content within the fixed height in design-system §5
rather than a fixed width.
