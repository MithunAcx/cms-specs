# UNIT-CMS-0006 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | 57 requirements (R1-R57): 30 functional/behaviour, 12 failure-surface, 15 NFR; no blocking open questions |
| 3 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md covers all 57 R-IDs; interfaces/ holds consumed-contracts.yaml + UNIT-CMS-0010.openapi.yaml copy (UNIT-CMS-0005/UNIT-CMS-0009 copies pending their own interfaces); ux/ complete (frame-inventory.md, 19-frame HTML mockup, states.md, a11y.md, components.md) |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md complete, full R-ID coverage (R1-R57); ba-spec-validate run scoped to this unit — no FAILs found against the tree as authored; open items: UNIT-CMS-0005/UNIT-CMS-0009 contract copies pending those units' own interfaces (tracked in consumed-contracts.yaml) |
| 5 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS — 2 conditions open (refresh UNIT-CMS-0005/UNIT-CMS-0009 contract copies before handoff; flag capability-level page/size-vs-cursor pagination inconsistency), self-review disclosed, PR #55 |
| 6 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS (independent re-review) — 2 conditions open (refresh UNIT-CMS-0005/UNIT-CMS-0009 contract copies once PRs #56/#48 merge; capability-level page/size-vs-cursor pagination inconsistency for capability owner to resolve), PR #55 comment https://github.com/MithunAcx/cms-specs/pull/55#issuecomment-5337189045 |
| 7 | 2026-08-19 | ready | ready | @MithunAcx | — | ux/ rebuilt to align mockup with the sponsor reference design system (PR #66); ba-spec-validate re-run scoped to the ux/ delta — no blocking FAILs; spec-review: APPROVE WITH CONDITIONS (self-review disclosed) — 1 condition open (UNIT-CMS-0009 contract copy still pending upstream; UNIT-CMS-0005's own copy is now complete), PR #66 comment https://github.com/MithunAcx/cms-specs/pull/66#issuecomment-5339905485 |
