# UNIT-CMS-0001 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | requirements.md complete — 28 requirements (R1-R13 functional, R14-R28 NFR), no blocking open questions |
| 3 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md covers all 28 R-IDs; interfaces/openapi.yaml (6 operations) and interfaces/001_create_identity_rbac_audit.sql (4 RLS-scoped tables) complete |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md complete, full R1-R28 coverage; ba-spec-validate scoped to this unit passes (all content checks clean; tracker.md regeneration deferred to centralized pm-state-rollup) |
| 5 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE — 0 conditions, PR #51 (self-review, disclosed) |
