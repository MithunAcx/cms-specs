# States — Activity Grid UI

Every state the user can observe. A state with no row here is an unspecified
state, and `ba-spec-validate` fails the unit for it.

There is one view in this unit — the activity grid itself, embedded into a host
screen it does not own (UNIT-CMS-0006). Every row below applies identically
whether the host embeds it against an agency or a brokerage parent.

**Role affects which controls exist, not which state is reached.** A Viewer-role
session reaches every row below except the ones naming an add/edit/complete/delete
action; for Viewer, those controls are absent from the DOM, not present-and-disabled
(R12/R28) — see `disabled / no permission` below and the a11y contract for why
"absent" rather than "disabled".

## Per view

### Activity grid — satisfies R1–R20, R29

| State | Trigger | What the user sees | Actions available |
|-------|---------|--------------------|-------------------|
| loading | Component mounts for a given `parentType`/`parentId` | Skeleton rows in place of the grid; sort/filter/load-more controls are present but disabled until the first response arrives | None — wait |
| empty — first-use | List call succeeds, `items` is empty, no filter is applied | "No activity logged yet." plus, for Editor only, the add control remains available | Add (Editor only) |
| empty — filtered-to-nothing | List call succeeds, `items` is empty, a completed/open filter or non-default sort is applied | "No entries match this filter." plus a control to clear the filter | Clear filter; Add (Editor only) |
| populated | List call succeeds, `items` non-empty | The grid: task/status, note, follow-up date, entered date, completed indicator, acting user, and (Editor only) per-row edit/complete/delete controls; sort/filter controls active, a "load more" control shown only while `next_cursor` is non-null. Follow-up date and entered date render as date-only values, with no time-of-day or timezone component attached (R19) | Sort, filter, load more (while available); add/edit/complete/delete (Editor only) |
| partial | — | N/A — a single bounded list call either returns a full page or it does not; there is no path where some rows of one response loaded and others failed | — |
| submitting | A caller triggers add, edit, complete, or delete | The triggering control (and, for delete, the confirm dialog's confirm button) disables for the call's duration; the rest of the grid stays interactive (R14) | Wait; nothing else on that row |
| success | Add/edit/complete/delete call returns success | A brief inline confirmation on the affected row (e.g. a check mark and "Saved"), then the row reflects the new server-returned state; the form/dialog closes | Continue working the grid |
| error — recoverable (dependency down/slow) | Initial list call times out or the connection fails | An error block replacing the grid area: "Activity could not be loaded." plus a retry control (R17) | Retry |
| error — recoverable (rate-limited) | Any call returns `429` | A "Too many requests — try again in `<n>`s" message honoring the response's `Retry-After`; the triggering control re-enables once it elapses (R18) | Wait, then retry the same action |
| error — recoverable (field-level) | An add/edit submit returns `400`/`422` | The offending field is highlighted inline with the server's message; the rest of the form's values are retained; submit re-enables (R10) | Correct the field and resubmit |
| error — terminal (row no longer available) | An edit/complete/delete submit returns `404` | "This entry is no longer available." on that row, then the row is removed from the grid; no retry is offered because the target is gone (R11) | Dismiss; continue working the rest of the grid |
| disabled / no permission | Caller's session role is Viewer | Sort/filter/load-more controls are present and active; add/edit/complete/delete controls are not rendered at all — not present-and-disabled (R12/R28) | Sort, filter, load more only |
| offline — on load | Device has no connectivity when the component mounts | Same visual treatment as `error — recoverable (dependency down/slow)`, with copy naming "offline" specifically, and retry re-attempts once connectivity is detected | Retry |
| offline — on submit | Device loses connectivity after a caller has already triggered add/edit/complete/delete | The affected control shows a queued/blocked state — "Can't save while offline" — the attempted change is **not** silently queued for later sync (this unit performs no background retry); the caller must resubmit once back online (R15's "outcome unknown" handling applies once connectivity returns) | Wait for connectivity, then resubmit |
| session expiry mid-flow | Any call returns `401` | A session-expired banner; any add/edit form still open keeps its entered values on screen so nothing is lost; no further calls are attempted until the host screen re-authenticates and remounts this component (R13) | None from within this component — re-authenticate via the host |

## Validation messages

| Field | Rule | Message |
|---|---|---|
| Task type / status | Required; must be one of the controlled list values scoped to this parent type | "Choose a task type." / "That task type isn't valid for this record." |
| Follow-up date | Required; must be a well-formed date, captured and stored as date-only with no time-of-day or timezone component (R19) | "Enter a follow-up date." / "Enter a valid date." |
| Note | No client-side rule beyond presence of the field itself (free text; server has no length rule surfaced to this unit) | — |

## Copy

All user-visible strings, so they are reviewable and translatable.

| Key | Copy |
|---|---|
| empty.first_use.title | No activity logged yet. |
| empty.first_use.action | Log activity |
| empty.filtered.title | No entries match this filter. |
| empty.filtered.action | Clear filter |
| error.dependency.title | Activity could not be loaded. |
| error.dependency.action | Retry |
| error.throttled.message | Too many requests — try again in {seconds}s. |
| error.field.generic | Check the highlighted field and try again. |
| error.row_gone.message | This entry is no longer available. |
| error.session_expired.title | Your session has ended. |
| error.session_expired.body | Sign in again to continue — your entry has been kept. |
| offline.load.title | You're offline. Activity could not be loaded. |
| offline.submit.message | Can't save while offline. Try again once you're back online. |
| success.created | Activity logged. |
| success.updated | Changes saved. |
| success.completed | Marked complete. |
| success.deleted | Entry removed. |
| action.add | Log activity |
| action.edit | Edit |
| action.complete | Mark complete |
| action.delete | Delete |
| action.delete_confirm.title | Delete this activity entry? |
| action.delete_confirm.body | This removes it from the list. This cannot be undone — no unit exposes a restore path. |
| action.delete_confirm.confirm | Delete |
| action.delete_confirm.cancel | Cancel |
| field.task_type | Task type |
| field.note | Note |
| field.follow_up_date | Follow-up date |
| field.completed_by | Logged by |
| filter.completed | Open only |
| filter.all | All |
| sort.follow_up_date | Follow-up date |
