# Components — Partner Directory UI

Unit-local inventory. Describes components by behaviour and contract, never by
framework or file path.

## Reused

Components that already exist elsewhere and are used as-is (per
`design-system.md`'s fixed vocabulary — these are generic building blocks, not
owned by another unit).

| Component | Source | Used for |
|---|---|---|
| App header | Shared app shell | Screen title ("Partner Directory") |
| Status badge | Shared design system component | Active/Disabled indicator in By Broker results (R7) |
| Table / Card | Shared design system component | Result rendering, desktop vs mobile (R13) |
| Error block | Shared design system component | Recoverable/terminal/rate-limited/offline-submit states |
| Empty state | Shared design system component | Zero-result state (R8) |
| Notice / provenance | Shared design system component | Partial-state notice ("Underwriters unavailable...") |
| Skeleton bar | Shared design system component | Loading state |

## Added by this unit

| Component | Purpose | Satisfies |
|---|---|---|
| Mode switcher | Single-select control choosing one of the six search modes | R2 |
| Search input group | The term/state input(s), shown per the current mode's requirement | R3, R4 |
| Assigned Underwriter filter | Independent dropdown search path | R5 |
| Result row navigator | Click/keyboard-activate behaviour resolving a row to its detail-screen family | R10, R26 |
| Load more control | Fetches the next cursor-based batch of results; present only while the response carries a `next_cursor` | R12 |
| Create launch group | The two role-gated navigation entry points | R11, R18 |

### Mode switcher

**Purpose.** Lets the user pick exactly one of the six search modes; changing it
clears the other mode's term/state input (design.md's Search input state
component).

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `mode` | one of `brokerage`, `broker`, `state-broker`, `agency`, `cga`, `state-agent` | yes | `brokerage` | Closed enum, matches capability.md FR-SEARCH-1 |
| `disabled` | boolean | no | `false` | Only true while the session guard has not yet resolved (design.md) |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `mode-changed` | the new mode | User selects a different mode (keyboard or pointer) |

**States it must render:** see `states.md` — the switcher itself has no independent
loading/error state; it is always interactive once the session guard resolves.

**Accessibility contract:** `radiogroup`/`radio` semantics, roving tabindex,
arrow-key navigation between options, `aria-checked` on the selected option, and a
visible underline on the selected option (never colour alone) — see `a11y.md`.

### Search input group

**Purpose.** Presents exactly the input(s) the current mode requires — a term
field for the four name/keyword modes, a state selector for the two state modes
(R3, R4) — and blocks submission when the requirement is unmet.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `mode` | see Mode switcher | yes | — | Determines which sub-input is shown |
| `term` | string | conditionally (term-required modes) | `""` | Whitespace-only treated as empty (R14) |
| `state` | 2-letter code | conditionally (state-required modes) | none | |
| `validationMessage` | string, nullable | no | `null` | Populated when a blocked submit is attempted |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `submit` | `{ mode, term?, state? }` | User activates Search with a valid input for the current mode |
| `blocked` | validation message key | User activates Search with an invalid input |

**States it must render:** see `states.md` — validation-error is this
component's own; loading/populated/empty/error are the results region's, not
this one's.

**Accessibility contract:** input labelled per `a11y.md` Semantics; validation
message linked via `aria-describedby`; see `a11y.md` for full detail.

### Assigned Underwriter filter

**Purpose.** An independent search path: selecting a value supersedes whichever
mode/term/state search was last active (design.md's Assigned Underwriter filter
flow), and re-selecting the mode switcher returns to mode-driven search.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `options` | list of underwriter names | yes (may be empty) | `[]` | Sourced from `/lookups/assigned-uws`; free text, not a managed lookup |
| `selected` | string, nullable | no | `null` | |
| `unavailable` | boolean | no | `false` | True when the lookup call itself failed (partial state) |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `uw-selected` | underwriter name | User picks a value from the dropdown |

**States it must render:** populated (options loaded), unavailable/partial (lookup
failed — notice shown, dropdown itself disabled), loading (options not yet
fetched, shown only briefly at screen load).

**Accessibility contract:** `combobox`/`listbox` pattern, arrow-key navigation,
Esc closes without changing selection — see `a11y.md`.

### Result row navigator

**Purpose.** Resolves a clicked/activated row to the correct detail-screen family
by the mode that produced the result set (never by inspecting the row's own
fields) — design.md's "Open a result" flow.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `mode` | see Mode switcher | yes | — | Determines the target screen family: Brokerage Detail (brokerage/broker/state-broker), Agency Detail (agency/state-agent), CGA Detail (cga) |
| `itemId` | UUIDv7 | yes | — | From the result item |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `open` | `{ mode, itemId }` | Row activated by click, Enter, or Space |

**States it must render:** none of its own — a row is always either present (in a
populated result set) or absent (empty/error/loading states have no rows to
activate).

**Accessibility contract:** each row/card is independently focusable and
activatable via Enter/Space, with an accessible name built from its primary
visible field — see `a11y.md`.

### Load more control

**Purpose.** Fetches the next cursor-based batch of results for the current
mode/term/state/UW-filter search (design.md's "Run a search" flow, step 6) —
never a page-number control, per 10-platform.md's cursor-only pagination floor
and R12.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `nextCursor` | opaque string, nullable | yes | `null` | Presence, not value, drives visibility — the control renders only while non-null |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `load-more` | `{ mode, term?, state?, cursor: nextCursor }` | User activates the control |

**States it must render:** present (a `next_cursor` was returned) or entirely
absent (the last batch had none) — same present/absent pattern as the create
launch group, no third state. A `load-more` request goes through the same
request sequencer as any other search request (design.md), so a stale response
to it is discarded on the same token basis.

**Accessibility contract:** standard button semantics, reachable in the focus
order immediately after the results region — see `a11y.md`.

### Create launch group

**Purpose.** Renders "Add New Agency"/"Add New Brokerage" only for a session
whose role carries the create permission (R11/R18) — absent, not disabled, for
everyone else.

**Inputs**

| Name | Type | Required | Default | Notes |
|------|------|----------|---------|-------|
| `canCreate` | boolean | yes | — | Resolved by the session guard, per design.md |

**Events**

| Event | Payload | When |
|-------|---------|------|
| `launch-add-agency` | — | "Add New Agency" activated |
| `launch-add-brokerage` | — | "Add New Brokerage" activated |

**States it must render:** present (canCreate = true) or entirely absent
(canCreate = false) — no third state.

**Accessibility contract:** standard link/button semantics; see `a11y.md`.

## Layout

Responsive behaviour by breakpoint, described in terms of what reflows.

| Breakpoint | Behaviour |
|---|---|
| `mobile` (360) | Mode switcher wraps to two rows if needed; search input group stacks vertically above the Search button; results render as stacked cards (R13), one field per line inside each card; Add New Agency/Brokerage stack full-width below the search controls |
| `tablet` (768) | Mode switcher stays one row; results still render as cards (this unit's table/card threshold is the desktop breakpoint, per R13 — tablet is treated as the mobile-card layout since it shares the narrower viewport's row-density constraint) |
| `desktop` (1440) | Mode switcher, search input group, and Search button share one row; results render as a table with all mode-specific columns visible; Add New Agency/Brokerage sit inline at the top-right of the results region |
