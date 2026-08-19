# UNIT-CMS-0003 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | requirements.md complete — 30 R-IDs (R1-R15 functional, R16-R30 NFR), no blocking open questions |
| 3 | 2026-08-18 | framed | designed | @MithunAcx | — | design.md complete (full R-ID coverage, flows, concurrency matrix, cross-cutting) and interfaces/openapi.yaml authored (2 operations, R1-R15 covered), no ADR raised |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md complete, full R1-R30 coverage in requirements.md/design.md/tasks.md, self-validated (RQ1 contiguous R1-R30, D3/D4 contracts-to-interfaces match, I5 error codes consistent) — ba-spec-validate not run as a separate skill invocation, self-check performed inline |
| 5 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE — 0 conditions, PR #49 (self-review, disclosed on the PR) |
| 6 | 2026-08-19 | ready | ready | @MithunAcx | — | ba-spec-validate re-run after a platform-floor pagination fix (page/size offset -> cursor-based limit/cursor/next_cursor across requirements.md, design.md, interfaces/openapi.yaml): PASS, 0 blocking failures, 2 warnings (tasks.md's stale page/size wording, out of scope since tasks.md is frozen at ready; tracker.md known-stale, rollup deliberately deferred batch-wide). PR #61 (fixes the defect originally landed via merged PR #49). |
| 7 | 2026-08-19 | ready | ready | @MithunAcx | — | spec-review: APPROVE WITH CONDITIONS — 1 condition open (tasks.md's stale page/size wording, tracked for a ba-change-request delta), PR #61 (self-review, disclosed on the PR) |
