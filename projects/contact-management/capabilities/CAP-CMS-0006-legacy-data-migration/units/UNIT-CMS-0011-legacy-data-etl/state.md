# UNIT-CMS-0011 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | draft | @MithunAcx | — | spec-review: APPROVE — 0 conditions, PR #21 |
| 3 | 2026-08-19 | draft | framed | @MithunAcx | — | requirements.md complete — R1-R25 (11 functional + 14 NFR), 0 blocking open questions |
| 4 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md complete (all R1-R25 covered, ADR-0001 recorded) and interfaces/ complete (5 contract files: 2 SQL migrations, 2 JSON Schemas, 1 AsyncAPI) |
| 5 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md complete with full R1-R25 coverage; ba-spec-validate run against this unit — 0 FAILs after fixing an I5 gap (missing unrecognized_history_value reason code) and an H4 gap (tenant isolation stated for reads, not only writes); tracker.md is stale pending the centrally-run pm-state-rollup (deferred per coordinator instruction) |
| 6 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS — 2 conditions (self-review, disclosed), PR #57 |
| 7 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS — 2 conditions (independent review), PR #57 |
