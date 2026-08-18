# ADR-0001 — Resolve producer id per-request from the brokerage/agency record

**Unit:** UNIT-CMS-0010 — Policy Integration API
**Status:** Accepted
**Date:** 2026-08-18

## Context

The legacy system called the policy-administration system with a single hard-coded
producer id literal, `2105941587`, for every lookup (DR-4, FR-POL-3, G4). That value
happened to be correct for the one producer the legacy deployment served, but it is not
a data-driven answer — a lookup for a different brokerage/agency would silently query
under the wrong producer id if the literal were simply carried forward.

## Options considered

1. **Carry the literal forward as a single configuration value.** Simplest, but
   reproduces the exact defect FR-POL-3 exists to close — it is still one value for every
   brokerage/agency, just moved from source code to a config file.
2. **Resolve the producer id per-request from the requested brokerage/agency's own
   stored attribute.** Requires UNIT-CMS-0005 to own and expose that attribute, and this
   unit to read it before calling upstream.
3. **Resolve it from the caller's session/tenant instead of the requested record.**
   Rejected — a single staff tenant can serve multiple producers, so tenant identity is
   the wrong key.

## Decision

Option 2. The producer id is read from the requested brokerage's or agency's own record
(owned by UNIT-CMS-0005) at request time, not from a project-wide constant.

## Consequences

- UNIT-CMS-0005's brokerage/agency schema must carry a producer-id attribute; this unit
  depends on that field existing and being populated before cutover (see UNIT-CMS-0011's
  migration).
- A brokerage/agency record with no producer id set cannot have its policies looked up —
  `design.md`'s failure paths must eventually cover this once UNIT-CMS-0005's schema is
  finalized; flagged here for that unit's design to close.
- Reversal: if a future requirement needs a different resolution key (e.g., per-tenant
  default instead of per-record), this ADR is superseded by a new one, and the change
  flows through `ba-change-request` since UNIT-CMS-0010 will already be handed off by
  then.
