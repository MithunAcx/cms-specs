# Components — UNIT-CMS-0002 Identity Access UI

## Reused from the shared design system

`design-system.md` §§ 2–5, applied as-is: colour tokens, typography classes, spacing
scale, app header, button (primary/secondary/disabled), input field, error block,
notice/provenance block. No modification to any of these.

## Added by this unit

### Credential form

**Purpose:** collects username/password (sign-in) or old/new password
(change-password); the one input surface this unit renders.

| Input | Type | Required | Default |
|---|---|---|---|
| `fields` | ordered list of `{ label, kind: "text" \| "password", value, error? }` | yes | empty values, no error |
| `submitLabel` | string | yes | — |
| `pendingLabel` | string | yes | — |
| `isSubmitting` | boolean | yes | `false` |
| `formError` | `{ message, retryable: boolean }` or absent | no | absent |

**Events:** `onSubmit` (fires once per user-initiated submission, never while
`isSubmitting` is true); `onRetry` (fires from the form-level error's retry
action, present only when `formError.retryable` is true).

**States it must render:** idle, submitting (fields read-only, submit disabled,
label swapped to `pendingLabel`), field-level error (one or more `fields[].error`
set), form-level error (`formError` set, distinguishing retryable from — though
this unit has no non-retryable form-level error — the shape still carries the flag
for completeness).

**Accessibility contract:** each field is a labelled `textbox`; a field with an
`error` gets `aria-describedby` pointing at an `alert`-role element containing that
error's text, per `a11y.md`. The submit control's accessible name changes with
`pendingLabel` while submitting, not only its visible text.

### Role-gated control

**Purpose:** wraps any action the current session's role may or may not use — the
rendering primitive `shell-viewer`/`shell-editor`/`shell-administrator` are built
from.

| Input | Type | Required | Default |
|---|---|---|---|
| `requiredRole` | `"viewer" \| "editor" \| "administrator"` | yes | — |
| `currentRole` | `"viewer" \| "editor" \| "administrator"` | yes | — |
| `presentation` | `"hide" \| "show-disabled"` | yes | `"hide"` |
| `disabledReason` | string | required when `presentation` is `"show-disabled"` | — |

**Events:** none of its own — it renders its child control or nothing/a disabled
copy of it; the child's own events are unaffected.

**States it must render:** enabled (current role meets or exceeds required),
absent (role below required, `presentation: "hide"`), visible-disabled (role below
required, `presentation: "show-disabled"` — captioned with `disabledReason`).
**Never** a fourth, ambiguous state — this is exactly the "prefer one `outcome`
input over booleans that combine into states that should not exist" case
`60-frontend.md` names, which is why `presentation` is a closed enum, not a
`hidden: boolean` plus a `disabled: boolean` that could both be false and true
simultaneously.

**Accessibility contract:** an absent control is genuinely absent from the DOM (not
tab-reachable); a visible-disabled control carries `aria-disabled="true"` and
`aria-describedby` naming the required role, per `a11y.md`.

### Session banner

**Purpose:** the offline notice (sign-in), and the session-expired mid-flow
notice (shell) — one component, two `kind` values, since both are a persistent,
non-dismissible-except-by-action notice above the main content.

| Input | Type | Required | Default |
|---|---|---|---|
| `kind` | `"offline" \| "session-expired"` | yes | — |
| `message` | string | yes | — |
| `action` | `{ label, } ` or absent | no (present for `session-expired`, absent for `offline`) | absent |

**Events:** `onAction` — fires only when `action` is present (the session-expired
banner's "Sign in again").

**States it must render:** `offline` (informational, polite announcement, no
action), `session-expired` (assertive `alertdialog` semantics, captures focus,
carries an action).

**Accessibility contract:** see `a11y.md` § Announcements and § Semantics — the two
`kind` values map to different live-region politeness and different focus-capture
behaviour, which is why they are one component with a discriminating input rather
than two components that would otherwise duplicate their layout.

## Layout — responsive behaviour

- **Credential forms** (sign-in, change-password): single column at every width;
  the `desktop` canvas simply adds horizontal breathing room via the design
  system's margin, not a second column — there is nothing to place beside a
  two-to-three-field form.
- **Shell header**: the role badge and sign-out control sit right-aligned in the
  56px header at `desktop`/`tablet`; at `mobile` the header's title truncates
  before the role badge does, since knowing the session is still authenticated
  (the badge) matters more at that width than the screen's own title.
- **Session-expired / offline banners**: full content width at every canvas size,
  stacked above the form or shell content, `margin-bottom: 16px` before the next
  region — never overlapping content, never a fixed/sticky overlay that could
  cover a field the user is mid-edit on.

## Trace

| Component | R-IDs served |
|---|---|
| Credential form | R2, R7 |
| Role-gated control | R4, R5 |
| Session banner | R1, R6 (offline path on sign-in touches R2's failure surface), R10 |
| App header (reused) | R3 |
