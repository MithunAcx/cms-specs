# UNIT-CMS-0008 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | 35 requirements (R1-R35), all traced; no blocking open questions |
| 3 | 2026-08-19 | framed | designed | @MithunAcx | — | design.md covers all R-IDs; interfaces/ carries a derived (not yet copy-verbatim — UNIT-CMS-0007 unpublished) consumed contract; ux/ complete (states.md, a11y.md, components.md, 16-frame mockup) |
| 4 | 2026-08-19 | designed | ready | @MithunAcx | — | tasks.md complete, full R1-R35 task coverage; ba-spec-validate run: 0 FAILs in this unit's own authored content (S/F/T/RQ/D/U/K checks and most of H clean). 3 findings carried forward, none originating in this unit's own authoring: I11 (UNIT-CMS-0007.openapi.yaml is a derived placeholder, not yet byte-copied, since UNIT-CMS-0007 has not published its own contract — will re-sync once it does), H9 and H10 (page/size pagination and the `{error:{code,message,fields?}}` envelope both deviate from 10-platform.md's cursor-pagination/shared-envelope rules, but both were already fixed capability-wide by CAP-CMS-0004/capability-design.md before this unit existed — not a call U2 can unilaterally change). G3 (tracker) is expected-stale — pm-state-rollup deferred centrally per this run's instructions. |
