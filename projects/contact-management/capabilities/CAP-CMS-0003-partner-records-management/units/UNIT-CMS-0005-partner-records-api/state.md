# UNIT-CMS-0005 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | 49 requirements (R1-R49: R1-R34 functional, R35-R49 NFR), all traced to CAP-CMS-0003/M1 and A1-A4; 2 non-blocking open questions |
| 3 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md complete (all R1-R49 covered) plus ADR-0001 (account-code generation); interfaces/openapi.yaml (19 operations) and interfaces/001_create_partner_records_schema.sql authored |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md complete, full R1-R49 coverage; ba-spec-validate (unit-scoped) run — 2 findings fixed in place (H9 cursor pagination added to listBrokers/listAgents, I10 stale .gitkeep removed), no remaining FAILs; tracker rollup deferred, to run centrally across parallel units |
| 5 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS — 6 conditions open (self-review, disclosed), PR #56 |
