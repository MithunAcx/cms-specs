# UNIT-CMS-0007 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | 27 requirements (R1-R27); no blocking open questions |
| 3 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md written, full R-ID coverage; interfaces/openapi.yaml + interfaces/001_create_activity.sql authored; server URL UNRESOLVED, owner @MithunAcx, blocks ba-unit-handoff |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md written, 27/27 R-IDs covered; self-run spec check found no structural failures (R-ID sequence, coverage tables, interface parseability) |
