---
id: ADR-0001
unit: UNIT-CMS-0002
title: In-memory-only client-side token storage, not persistent browser storage
status: accepted
date: 2026-08-18
deciders: ["@MithunAcx"]
supersedes: []
superseded_by: []
---

# ADR-0001 — In-memory-only client-side token storage, not persistent browser storage

## Status

accepted

## Context

`CAP-CMS-0001/capability-design.md`'s Handoff notes to this unit explicitly left
"client-side token storage mechanism (memory vs. browser storage) and its own
XSS/CSRF posture within `stack.md`'s NFR-SEC-4 requirements" as this unit's own
decision — it was not fixed by the capability design or by `requirements.md`.

The forces at play:

- XD-0001 (capability-design.md) fixes the token *shape* — a short-lived access
  token plus a longer-lived, revocable refresh token — but says nothing about
  where the browser keeps either one between requests.
- `stack.md`'s NFR-SEC-4 requires standard web protections including XSS output
  encoding, but does not eliminate XSS risk to zero; no client-side spec can
  assume a hostile script never runs in the page's own origin.
- AUTH-5 (`capability.md`'s original ask) states "the front end holds no
  long-term secrets beyond the session/access token" — read literally, this
  favours the token not outliving what is strictly needed for the session.
- `UNIT-CMS-0002/requirements.md` R9 requires refresh calls to coalesce through a
  single shared in-flight-refresh reference, which is naturally scoped to one
  execution context's memory.
- No requirement in `requirements.md` asks for a session to survive a page
  reload; it was not requested, and `requirements.md`'s Assumptions section
  records the default landing route and storage mechanism as design decisions
  precisely because neither was asked for as a requirement.

## Options considered

### Option A — In-memory only
- Tokens are held only in page memory for the lifetime of the browser tab; a
  page reload discards them and forces a fresh sign-in.
- **For:** unreachable by anything that runs after the page has unloaded (a
  reloaded page starts with an empty memory space); the security property does
  not depend on XSS mitigation being perfect, only on no *concurrent* injected
  script reading memory while the tab is open; matches AUTH-5's "no long-term
  secrets" read literally.
- **Against:** every reload — including an accidental one, or a deployed
  front-end update reloading the tab — forces the user to sign in again, which is
  a real, user-visible friction cost on a system used across a normal working
  day (AUTH-4).

### Option B — Persistent browser storage
- Tokens are written to a persistent client-side store so a reload does not
  interrupt the session.
- **For:** removes the reload friction entirely; simpler mental model for
  "session persists across a normal working day" (AUTH-4).
- **Against:** anything persisted in the page's origin is readable by any script
  that runs in that origin, including an injected one — this makes NFR-SEC-4's
  XSS output-encoding protection the *only* thing standing between an attacker
  and both the access and refresh token, for as long as the browser keeps the
  data. A single successful injection compromises the full token pair, not just
  the current in-page state.

## Decision

We chose **Option A — in-memory only**.

Because: this unit's token storage is the one place a single XSS gap turns into
full session compromise rather than a contained one, and no requirement asked for
reload-persistent sessions strongly enough to accept that trade.

## Consequences

**Accepted costs.** A page reload — accidental, or triggered by a deployed
front-end update — always forces a fresh sign-in for every user, every time,
for the life of this design. This is a standing, deliberate UX cost, not an
oversight.

**Follow-on work.** The refresh-coalescing mechanism in `design.md` § State and
idempotency is built around a single shared in-memory reference; it is
correctly scoped to this decision and would need rework, not just a config
change, if storage ever moved to something shared across execution contexts.

**Constraints imposed on others.** None outside this unit — no other unit reads
or writes this unit's client-side token storage.

## Reversal

Would be revisited if a future requirement explicitly demands reload-persistent
sessions strongly enough to accept the widened XSS blast radius, or if a
different XSS-resistant persistence mechanism becomes part of `stack.md`'s
stated NFR-SEC-4 posture. Reversal is not cheap: it means re-deriving the
refresh-coalescing design for a storage mechanism shared across execution
contexts, and re-stating NFR-SEC-4's XSS posture for the frontend, both of which
should go through `ba-change-request` rather than a silent `design.md` edit.

## References

- `UNIT-CMS-0002/requirements.md` R9, R22, R23, Assumptions
- `UNIT-CMS-0002/design.md` § Approach, § State and idempotency, § Risks
- `CAP-CMS-0001/capability-design.md` § Handoff notes to unit design — identity-access-ui (U2)
- `projects/contact-management/stack.md` NFR-SEC-4 consequence row
