# Components — UNIT-CMS-0002 Identity Access UI

## Reused from the reference design system

Corrected 2026-08-19: this unit originally built its own generic vocabulary
(`--surface`, `--primary`, `text-h1`, `.field-group`, Segoe UI) instead of the
sponsor's actual design system. It now reuses, verbatim, the colour tokens and
component classes defined in `requirements/contactmanagement-full-mockup.html`
(cited in `CMS-Modernization-Requirements.md` §1.4) — the same file `frame-
inventory.md`'s Source position names:

- **Tokens**: `--brand`/`--brand-dark`/`--brand-light`/`--brand-50`, `--bg`,
  `--panel`/`--panel-2`, `--border`/`--border-strong`, `--text`/`--text-2`,
  `--muted`/`--faint`, `--slate-100`/`--slate-200`/`--slate-400`, both the
  reference's light and dark theme blocks.
- **Typography**: the Inter font stack (see deviation below), `.h1` for a
  page-level heading, plain `h2`/`h3`, `.muted`/`.faint`/`.text-2` for secondary
  text.
- **Components**: `.field`/`.inp`/`.inp.err`/`.help-err` (form fields and their
  errors), `.btn`/`.btn-primary`/`.btn-secondary`/`.btn-ghost`/`.btn-sm` (buttons),
  `.panel`/`.panel-pad` (cards), `.login-wrap`/`.login-card`/`.brandmark` (the
  sign-in layout, matching the reference's `#view-login`), `.dialog`/
  `.dialog-head`/`.dialog-body`/`.dialog-foot` (the session-expired alert),
  `.badge`/`.dot` (the role indicator in the shell header), `.avatar`,
  `.icon-btn`, `.divider`.

**Deliberate deviations from the reference**, each kept as small as the
conflicting requirement allows:

| Deviation | Reason |
|---|---|
| No Google Fonts `<link>`; Inter falls back to `ui-sans-serif, system-ui, "Segoe UI", Arial, sans-serif` with no webfont loaded | `designer-unit-ux` requires the mockup render and switch states offline from `file://`, with no external resource of any kind |
| No `box-shadow`, gradient, `animation` or `transition` anywhere (the reference uses all four — card shadows, a brandmark gradient, dialog/toast pop-in) | `a11y.md`'s Visual section already commits this unit to "moot here, since the design system forbids animation/transition outright" under `prefers-reduced-motion`; keeping that commitment true takes priority over matching purely decorative motion |
| Retry-eligible / dependency errors (`sign-in-error-retry`, `change-password-error-retry`) use a new `.error-panel` built from `.panel` + the reference's own error colour (`--brand`, the same red the reference uses for `.help-err`/`.inp.err`) | The reference mockup never shows a form-level, title+body+retry error — only inline field errors — so there is no existing block to reuse. `.error-panel` is documented here rather than left as a silent addition, per `design-system.md` §10's "do not improvise silently" rule, generalised to this reference |
| The offline banner (`.notice`) is a new class, `.panel-2` background + `.text-2` copy | Same reason — the reference has no persistent-notice component; built from tokens already in use rather than an invented colour |
| Role display in the shell header uses `.badge.badge-off` rather than one of the reference's status badges (`.badge-active`/`.badge-off`/`.badge-warn`) | A session role is not an entity status (active/lapsed/pending); `frame-inventory.md`'s "What must NOT be drawn" already excludes a status-matrix frame for this unit. `badge-off`'s neutral grey avoids implying the role itself has a state |

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

## Interaction addenda (2026-08-19) — mockup only, not new components

Two additions were needed to make the mockup a real click-through prototype
rather than a state switcher; neither changes a documented state or adds a
component to the vocabulary above:

- **Client-side required-field validation** on the credential form (both
  sign-in and change-password) reuses the existing `.inp.err`/`.help-err`
  pair with a generic "This field is required." message. This is the
  convenience validation `design.md`'s cross-cutting section already
  describes ("required fields, minimum password shape"); it is a micro-state
  layered on `populated`, not a new row in `states.md`.
- **Session diagnostics panel**, shown only inside the signed-in shell, is
  scaffolding that simulates R8/R9/R10's silent-refresh-and-coalesce
  behaviour (expire the access token, force a refresh failure, fire two
  concurrent calls) since there is no real UNIT-CMS-0001 to call from a
  static file. It is visually distinct from the design system (plain
  monospace log, muted captions) precisely so it reads as demo tooling, not
  a specified screen — consistent with `frame-inventory.md`'s "What must NOT
  be drawn" list, which this panel does not violate because it draws no
  entity screen, only a log of simulated HTTP outcomes.
