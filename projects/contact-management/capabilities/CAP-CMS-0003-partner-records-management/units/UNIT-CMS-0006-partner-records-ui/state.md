# UNIT-CMS-0006 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | 57 requirements (R1-R57): 30 functional/behaviour, 12 failure-surface, 15 NFR; no blocking open questions |
| 3 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md covers all 57 R-IDs; interfaces/ holds consumed-contracts.yaml + UNIT-CMS-0010.openapi.yaml copy (UNIT-CMS-0005/UNIT-CMS-0009 copies pending their own interfaces); ux/ complete (frame-inventory.md, 19-frame HTML mockup, states.md, a11y.md, components.md) |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md complete, full R-ID coverage (R1-R57); ba-spec-validate run scoped to this unit — no FAILs found against the tree as authored; open items: UNIT-CMS-0005/UNIT-CMS-0009 contract copies pending those units' own interfaces (tracked in consumed-contracts.yaml) |
