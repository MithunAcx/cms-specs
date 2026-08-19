# Frame inventory — UNIT-CMS-0002 Identity Access UI

## Source position

A design file **does** exist and was missed on the first pass of this unit: the
sponsor-provided indicative redesign at `requirements/contactmanagement-full-mockup.html`
(cited in `CMS-Modernization-Requirements.md` §1.4 under the filename
`contactmanagement-angular-mockup.html` — the filename drifted after the citation was
written; it is the same file), specifically its login view, `#view-login`
(as of this repo's `main` at the time of this correction). That view is the source of
this unit's sign-in visual design; every other frame below (shell, change-password)
has no counterpart in that reference and is designed in its visual language rather
than copied from it, since the reference mockup does not show them.

Output: the generated HTML mockup + this inventory (output 1 of `designer-unit-ux`),
built from the reference's own design tokens and component classes rather than the
generic ones this unit originally invented — see `components.md` for the full
before/after and the deliberate deviations (self-containment, no motion).

## Constraints every frame respects

- Drawn at all three canvas widths via the mockup's width control (`360`/`768`/`1440`);
  the column below names the width each frame was **specified** against.
- Both themes (`light`/`dark`) reachable via the theme toggle for every frame, using
  the reference's own light/dark token pairs.
- Contrast ≥ 4.5:1 text / ≥ 3:1 UI, targets ≥ 24×24 CSS px, usable at 200% zoom, no
  horizontal scroll at 320px — per `60-frontend.md`.
- Colour is never the sole carrier of meaning — error/success states carry text and
  structure (a labelled error panel, a field-level message), not colour alone.
- No external resource — no Google Fonts `<link>`, no image, no script beyond the
  switcher — so the file still opens and switches states offline from `file://`, per
  `designer-unit-ux` §2, even though the reference itself links a webfont.

## Frames

| # | Frame (kebab-case) | Shows | State row (`states.md`) | Width specified at |
|---|---|---|---|---|
| 1 | `sign-in-idle` | Empty login form, ready for input | Sign-in — populated (initial) | desktop |
| 2 | `sign-in-submitting` | Login form with submit disabled, in-flight indicator | Sign-in — submitting | desktop |
| 3 | `sign-in-error-credentials` | Generic credential-rejected message (R2); password cleared | Sign-in — error, recoverable (credentials) | desktop |
| 4 | `sign-in-error-retry` | Retry-eligible error (network/5xx/timeout) | Sign-in — error, recoverable (dependency) | desktop |
| 5 | `sign-in-offline-on-load` | Sign-in reachable but a banner states connectivity is required before submitting | Sign-in — offline (on load) | mobile |
| 6 | `shell-viewer` | Authenticated shell, Viewer role: header, role badge, sign-out; edit/delete controls visibly absent (not merely disabled — never rendered) | Shell — populated (Viewer) | desktop |
| 7 | `shell-editor` | Authenticated shell, Editor role: create/edit/delete controls enabled | Shell — populated (Editor) | desktop |
| 8 | `shell-administrator` | Authenticated shell, Administrator role: Editor's controls plus reference-lookup and role-assignment entry points enabled | Shell — populated (Administrator) | desktop |
| 9 | `shell-disabled-control` | Shell showing an Administrator-only control visible-and-disabled to an Editor, with a caption naming the required role | Shell — disabled/unauthorized | tablet |
| 10 | `shell-session-expired-midflow` | Silent refresh has failed mid-session; a preserved-work banner appears before redirecting to sign-in | Shell — session expiry mid-flow | desktop |
| 11 | `change-password-idle` | Empty change-password form | Change password — populated (initial) | desktop |
| 12 | `change-password-submitting` | Form with submit disabled, in-flight indicator | Change password — submitting | desktop |
| 13 | `change-password-error-old` | Field-level error on old password (401) | Change password — error, recoverable (old password) | desktop |
| 14 | `change-password-error-new` | Field-level error on new password (400, weak password) | Change password — error, recoverable (new password) | desktop |
| 15 | `change-password-error-retry` | Retry-eligible error (network/5xx/timeout) | Change password — error, recoverable (dependency) | desktop |
| 16 | `change-password-offline-on-submit` | Submission blocked mid-flight by lost connectivity; entered values retained except password fields | Change password — offline (on submit) | mobile |
| 17 | `change-password-success` | Confirmation shown, session remains signed in | Change password — success | desktop |

Frame 5 and 16 are also verified at `mobile` to confirm the offline banner reflows
without truncation, per `design-system.md` § 1's "all three widths are reachable"
requirement; every other frame defaults to `desktop` and is reachable at the other two
widths through the mockup's own width control.

## What must NOT be drawn

- No data table, list, or search result of any kind — this unit owns no screen's own
  content (`requirements.md` § Scope, out of scope).
- No delete control anywhere — this unit renders no entity screens; delete controls
  belong to the units that own those entities.
- No "remember me" / persistent-session checkbox on sign-in — contradicts ADR-0001's
  in-memory-only token storage; no such control exists to draw.
- No SSO / corporate-identity-provider button on sign-in — out of scope per
  `capability.md`'s non-goals.
- No "forgot password" / self-service reset link — no reset flow is in
  `requirements.md`; only authenticated change-password (R7) exists.
- No reference-lookup or user-role-assignment *screen* under the Administrator
  frame — only the entry-point control is shown enabled; the screens themselves
  belong to CAP-CMS-0003 and to a future user-administration unit.
- No password-strength meter or live-validation-as-you-type indicator — client-side
  validation in this unit is a convenience only (design.md § Cross-cutting), and no
  requirement specifies a strength meter.
- No status badge / `status-matrix` frame — this unit renders no status values
  (§ 7 of `design-system.md` does not apply here).

## Could not be generated

None — every frame above is expressible with the reference's own component
vocabulary (`.field`/`.inp`, `.btn`/`.btn-primary`/`.btn-secondary`, `.panel`/
`.panel-pad`, `.dialog`, `.badge`), extended only where the reference has no
counterpart at all — see `components.md`.
