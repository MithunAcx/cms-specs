# States — UNIT-CMS-0002 Identity Access UI

Three views: **Sign-in**, **Shell / role-gated rendering**, **Change password**. Every
mandatory row from `60-frontend.md` is filled for each; a row that does not apply names
why rather than being left blank.

## Sign-in — satisfies R2, R3

| State | Answer |
|---|---|
| loading | N/A — the form has no data to load; it renders immediately from static copy |
| empty | N/A — no list/collection exists on this view |
| populated | `sign-in-idle` — empty username/password fields, submit enabled once both are non-empty |
| partial | N/A — a single atomic submission, no partial data |
| submitting | `sign-in-submitting` — submit control disabled, an in-flight indicator replaces the button label; both fields become read-only so a resubmission with edited values cannot race the pending call |
| success | Not a rendered frame — on `200` the view is replaced by a route navigation (design.md § Flows — Sign-in step 5); nothing remains to screenshot |
| error, recoverable (credentials) | `sign-in-error-credentials` — one generic message ("Username or password is incorrect."); username retained, password field cleared and refocused |
| error, recoverable (dependency) | `sign-in-error-retry` — distinct message naming a connection problem, with a retry affordance; username retained, password cleared |
| error, terminal | N/A — no error on this view is terminal; every failure is retry-eligible or corrects to the credential-rejected message above |
| disabled / unauthorized | N/A — sign-in is reachable to anyone with no session; there is no authorization gate on this view itself |
| offline, on load | `sign-in-offline-on-load` — form still renders (nothing to fetch), but a banner states connectivity is required before the submit control is usable; submit is disabled with a caption naming the reason |
| offline, on submit | Same visual treatment as `sign-in-error-retry` — a lost connection mid-submission is indistinguishable to the user from a timeout, and is handled by the same retry-eligible path |
| session expiry mid-flow | N/A — there is no session yet on this view |

### Copy — Sign-in

| Key | Text |
|---|---|
| `signin.title` | Sign in |
| `signin.field.username` | Username |
| `signin.field.password` | Password |
| `signin.submit` | Sign in |
| `signin.submit.pending` | Signing in… |
| `signin.error.credentials` | Username or password is incorrect. |
| `signin.error.retry` | Something went wrong reaching the sign-in service. Check your connection and try again. |
| `signin.error.retry.action` | Retry |
| `signin.offline.banner` | You appear to be offline. Sign-in requires a connection. |

## Shell / role-gated rendering — satisfies R1, R4, R5, R6

| State | Answer |
|---|---|
| loading | N/A — the shell has no data of its own to load; the role/identity used to render it was already resolved during sign-in (R3) |
| empty | N/A — no list/collection exists on this view |
| populated | `shell-viewer` / `shell-editor` / `shell-administrator` — the same shell with only the visible control set differing by role, per the role table below |
| partial | N/A — role is resolved atomically at sign-in/refresh time; there is no partially-known role |
| submitting | N/A — sign-out is the only action on this view; see its own row below |
| success | N/A — see disabled/unauthorized and session-expiry rows; this view has no "success" outcome of its own |
| error, recoverable | N/A — this view renders nothing that can itself fail; a failed sign-out is covered below |
| error, terminal | N/A |
| disabled / unauthorized | `shell-disabled-control` — a control requiring a higher role than the session holds is either **hidden** (Viewer never sees an Editor-only control at all) or, where the design calls for showing what exists without granting it (Administrator-only entry points shown to an Editor), rendered **visible-and-disabled with a caption naming the required role**. Per the role table in `requirements.md`'s Behaviour detail, every create/edit/delete control is hidden entirely below Editor; only the Administrator-only entry points (reference lookups, role assignment) use the visible-disabled treatment for Editors, since those are the ones worth advertising exist |
| offline | Sign-out (the one action here) behaves per its own row; nothing else on this view depends on connectivity |
| session expiry mid-flow | `shell-session-expired-midflow` — when a silent refresh fails (R10) while the user has unsaved work on any screen this shell hosts, a banner states the session ended and that unsaved work may be lost, **before** navigating to sign-in — giving the user a moment to notice, per the "is the user's work preserved?" question this row exists to force. This unit does not itself preserve the other screen's unsaved data (it owns no screen content), so the honest answer is: not preserved, and the user is told so explicitly rather than losing work silently |

**Sign-out** (a control on this view, not a separate view): selecting it immediately
clears the session and navigates to sign-in (design.md § Flows — Logout) regardless of
the server call's outcome — there is no visible "signing out…" state because the local
transition is instant; the server call happens without blocking the UI.

### Role table (drawn, not just described)

| Role | Visible controls in the shell |
|---|---|
| Viewer | Search entry point, view-only navigation. No create/edit/delete control renders at all. |
| Editor | Viewer's, plus create/edit/delete entry points for brokerages, agencies, brokers, agents, CGAs, accounting addresses, contact activity, flags/statuses |
| Administrator | Editor's, plus reference-lookup maintenance and user role-assignment entry points |

### Copy — Shell

| Key | Text |
|---|---|
| `shell.role.viewer` | Viewer |
| `shell.role.editor` | Editor |
| `shell.role.administrator` | Administrator |
| `shell.signout` | Sign out |
| `shell.disabled.caption` | Requires Administrator role |
| `shell.sessionexpired.banner` | Your session has ended. Any unsaved work on this screen may be lost. |
| `shell.sessionexpired.action` | Sign in again |

## Change password — satisfies R7

| State | Answer |
|---|---|
| loading | N/A — no data to load |
| empty | N/A — no list/collection exists on this view |
| populated | `change-password-idle` — empty old/new password fields |
| partial | N/A — a single atomic submission |
| submitting | `change-password-submitting` — submit disabled, in-flight indicator, both fields read-only |
| success | `change-password-success` — inline confirmation shown in place of the form; session remains signed in, no redirect |
| error, recoverable (old password) | `change-password-error-old` — field-level error under the old-password field (401); new-password field retained, old-password field cleared and refocused |
| error, recoverable (new password) | `change-password-error-new` — field-level error under the new-password field (400, weak password); old-password field retained, new-password field cleared and refocused |
| error, recoverable (dependency) | `change-password-error-retry` — a form-level retry-eligible error (network/5xx/timeout); both password fields cleared, old-password refocused |
| error, terminal | N/A |
| disabled / unauthorized | N/A — reachable to any authenticated session (Viewer and above); there is no role gate on this view |
| offline, on load | N/A — the form has nothing to load; it renders regardless of connectivity |
| offline, on submit | `change-password-offline-on-submit` — connection lost mid-submission; treated identically to the dependency retry-eligible error above, both password fields cleared |
| session expiry mid-flow | If the access token expires while this form is open, the underlying silent-refresh flow (shell view) runs transparently; only if that refresh itself fails does `shell-session-expired-midflow`'s banner apply, and the entered (unsubmitted) password values are lost — the same "not preserved, told explicitly" answer as the shell view |

### Copy — Change password

| Key | Text |
|---|---|
| `changepw.title` | Change password |
| `changepw.field.old` | Current password |
| `changepw.field.new` | New password |
| `changepw.submit` | Change password |
| `changepw.submit.pending` | Changing password… |
| `changepw.success` | Your password has been changed. |
| `changepw.error.old` | Current password is incorrect. |
| `changepw.error.new` | New password does not meet the password requirements. |
| `changepw.error.retry` | Something went wrong changing your password. Check your connection and try again. |
| `changepw.error.retry.action` | Retry |
