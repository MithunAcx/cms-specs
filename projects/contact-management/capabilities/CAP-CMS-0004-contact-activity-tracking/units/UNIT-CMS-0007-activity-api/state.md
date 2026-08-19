# UNIT-CMS-0007 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | 27 requirements (R1-R27); no blocking open questions |
| 3 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md written, full R-ID coverage; interfaces/openapi.yaml + interfaces/001_create_activity.sql authored; server URL UNRESOLVED, owner @MithunAcx, blocks ba-unit-handoff |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md written, 27/27 R-IDs covered; self-run spec check found no structural failures (R-ID sequence, coverage tables, interface parseability) |
| 5 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS — 1 condition open (capability-design.md's Shared conventions error-envelope row is stale vs. platform envelope actually used), self-review disclosed, PR #50 |
| 6 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS — 2 conditions open (capability-design.md's Shared conventions error-envelope row is stale; this unit's own design.md Cross-cutting error-model row also repeats the stale shape though interfaces/openapi.yaml is correct), independent re-review (not self-review), PR #50 |
| 7 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE — 0 findings, 0 conditions; PR #62 corrected capability-design.md's pagination/error-envelope conventions and this unit's requirements.md R4 + design.md GET-list-flow/cross-cutting rows to match; conditions from rows 5/6 above are closed by this PR |
