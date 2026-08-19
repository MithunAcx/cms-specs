# UNIT-CMS-0004 — transition ledger

APPEND-ONLY. Never edit, reorder, or remove a row. The last row is this unit's
current status.

| # | date | from | to | by | change | note |
|---|------|------|----|----|--------|------|
| 1 | 2026-08-18 | — | draft | @MithunAcx | — | created by ba-unit-split |
| 2 | 2026-08-18 | draft | framed | @MithunAcx | — | ba-unit-requirements: 41 requirements (R1-R41; 13 functional, 13 failure-surface, 15 NFR), 1 non-blocking open question (Q1) |
| 3 | 2026-08-18 | framed | designed | @MithunAcx | — | architect-unit-design + architect-unit-interfaces: design.md covers R1-R41; consumer-only interfaces/ (consumed-contracts.yaml + UNIT-CMS-0003.openapi.yaml constructed from capability-design.md, pending re-copy once UNIT-CMS-0003 authors its own openapi.yaml — Q2). No ADR raised. |
| 4 | 2026-08-19 | designed | designed | @MithunAcx | — | designer-unit-ux: ux/ complete — states.md (11 mandatory rows incl. offline on-load/on-submit and session-expiry), a11y.md, components.md, frame-inventory.md (18 frames), one runnable HTML mockup with state/theme/width switcher. All user-visible R-IDs covered. |
| 5 | 2026-08-19 | designed | ready | @MithunAcx | — | architect-unit-tasks: tasks.md covers R1-R41 (coverage table complete). ba-spec-validate (unit scope) run: 2 FAILs judged non-blocking and recorded as open conditions rather than reverting status — I11 (UNIT-CMS-0003.openapi.yaml cannot yet be byte-identical to a producer file, since UNIT-CMS-0003 has not authored interfaces/openapi.yaml; tracked as Q2/a tasks.md re-copy task) and H9 (page/size pagination inherited verbatim from CAP-CMS-0002's approved capability.md API-1 / capability-design.md Unified API Contract, a capability-level deviation from 10-platform.md's cursor-only floor that predates this unit and this unit cannot unilaterally change, since it only consumes UNIT-CMS-0003's contract). All other checks (RQ, D, U, K series; frontmatter; ledger legality) passed for this unit's scope. G3 (tracker freshness) not evaluated — pm-state-rollup deliberately deferred to the centralized post-parallel-units run per task instruction. ba-readiness-sweep recommended before handoff, not yet run. |
