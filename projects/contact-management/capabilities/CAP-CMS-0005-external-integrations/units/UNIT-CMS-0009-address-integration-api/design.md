---
unit: UNIT-CMS-0009
updated: 2026-08-18
---

# Design — Address Integration API

Language-neutral. No frameworks, class names, file paths, or repo layout — those
are owned by the engineering repo.

## Approach

A single stateless, synchronous read endpoint that stands between the CMS frontend
and SmartyStreets. On each call it: (1) validates the free-text query is present and
meets this unit's minimum length, (2) makes a live, synchronous call to SmartyStreets
with the provider's API key held in server-side configuration, (3) strips every field
from the provider's response except `line1`/`city`/`state`/`zip` (the XD-0002 shape),
and (4) returns the assembled suggestion list. No suggestion is cached and nothing is
written to this project's own datastore, so the unit stays a thin, synchronous proxy
rather than an integration with its own state to reason about.

**Minimum query length.** This unit rejects `q` shorter than 3 characters with `400
invalid_request` (R4). Three characters is the point at which SmartyStreets' own
autocomplete typically starts returning a useful candidate set; below it, a call
consumes provider quota for a result set too broad to be useful. This is a design-time
parameter, not fixed by any capability outcome — `requirements.md`'s Assumptions
flags it as revisable, and a future change to it is a same-unit design update, not a
change request, since no R-ID's wording depends on the exact number.

**Caching was considered and rejected for this iteration.** A short-TTL cache keyed
on `q` would reduce provider calls and could help R12's latency budget under repeated
near-identical queries during typeahead. It is not adopted here because: (a) no
capability outcome or requirement calls for it, (b) SmartyStreets' own free-text
matching means near-duplicate keys (`"123 Main"` vs `"123 Main S"`) would mostly miss
anyway, and (c) it is not free — it exists to be added later if p95 in production shows
otherwise (see Risks). This is a candidate for the engineering repo to raise as a
performance change request once real traffic is observed, not a decision this design
forecloses.

## Components

| Component | Responsibility | Satisfies |
|---|---|---|
| Request validator | Rejects a missing, empty, or below-minimum-length `q` before any upstream call | R4 |
| SmartyStreets client | Makes the live synchronous call to SmartyStreets, with a bounded timeout, credentials read from server-side configuration | R1, R2, R3, R9, R10 |
| Response assembler | Strips every provider field except `line1`/`city`/`state`/`zip`; builds the final `{ suggestions: [...] }` shape | R1, R6 |

## Flows

### GET /address/suggest — happy path — satisfies R1, R2, R3, R5, R6

1. Caller sends `GET /api/v1/address/suggest?q=` with a bearer token.
2. Request validator checks the token is present and valid (R5); rejects a missing,
   empty, or below-minimum-length `q` (R4).
3. SmartyStreets client calls SmartyStreets with the resolved `q`, within the stated
   timeout budget (R12), using an API key read from server-side configuration (R2, R3)
   — the browser never makes this call itself.
4. Response assembler strips every field except `line1`/`city`/`state`/`zip` from each
   candidate SmartyStreets returns (R6).
5. Response assembler returns `{ suggestions: [{ line1, city, state, zip }] }`.

Failure paths:

| Step fails | Behaviour |
|---|---|
| 2 — no/invalid token | `401` (R5) |
| 2 — `q` missing, empty, or below minimum length | `400 invalid_request` (R4) |
| 3 — SmartyStreets unreachable, connection refused, non-2xx | `502 upstream_unavailable` (R9) |
| 3 — SmartyStreets exceeds timeout budget | `502 upstream_unavailable`; request is not held open past the budget (R10) |
| 3 — SmartyStreets answers with zero matches for a valid query | `200` with `suggestions: []` — success, not an error (R9 distinction) |

## Data model

This unit owns no persistent entity — see `requirements.md` § Data. Nothing is read
from or written to this project's own datastore on any path.

| Entity | Key | Fields of note | Retention |
|---|---|---|---|
| — (none owned) | — | — | — |

## Contracts

| Contract | Kind | File | Satisfies |
|---|---|---|---|
| Address suggest | sync HTTP | `interfaces/openapi.yaml` | R1, R2, R3, R4, R5, R6, R9, R10 |

## State and idempotency

This unit holds no state and performs no write, so there is no state machine and no
idempotency key to derive (R7). Every call is a fresh, independent proxied read.

**Idempotency walk.** The only path that could perform an effect is the single
upstream `GET` call to SmartyStreets:

| Path | Effect | Collapses to |
|---|---|---|
| First attempt | One upstream read | The read |
| Client retry (same `q`) | A second, independent upstream read | Same observable result (modulo SmartyStreets' own answer changing), no cumulative effect — R7 |
| Duplicate submit (double-click, two tabs) | Two independent upstream reads | Same as above — neither call observes or is affected by the other, R8 |
| Timeout followed by a caller-side retry | The original call, if still in flight, has no side effect to duplicate — it is a read | No duplicated effect possible on a read-only proxy |

Because every path is a read against an external system with no local write, there is
no key to derive and nothing to deduplicate — a retried or duplicated call is simply
another independent read (R7, R9 vs. R1 distinction preserved on each).

## Concurrency matrix

| Two things happening at once | Who wins / what each observes |
|---|---|
| Two callers issue different `q` values concurrently | Each gets its own independent upstream call and response; no shared state to contend over (R8) |
| Two callers issue the identical `q` value concurrently | Each gets its own independent upstream call; SmartyStreets may answer either identically or with drift depending on its own consistency, which this unit does not attempt to reconcile — no requirement asks it to (R8) |
| A caller retries while the original call is still in flight | Two independent calls proceed; whichever completes first is returned to whichever request is waiting on it — no ordering guarantee is made or needed on a stateless read |

No case here needs storage-level enforcement — this unit has no store.

## Cross-cutting

| Concern | Decision |
|---|---|
| authn/authz | Bearer token validated per CAP-CMS-0001; minimum role Viewer (R5, R18) |
| validation | `q` required, non-empty, minimum 3 characters before any upstream call (R4) |
| errors | Shared envelope `{ error: { code, message, details, trace_id } }`; `502 upstream_unavailable` for any upstream failure, `400 invalid_request` for malformed/absent `q` (R4, R9) |
| observability | Metrics: request count, upstream call latency, upstream error rate. Logs: caller id, tenant id, `q` length only — never the raw query text (R21, R22) |
| performance | p95 ≤ 900 ms / p99 ≤ 2000 ms inclusive of cold start and upstream round trip (R12) |
| migration/backfill | N/A — greenfield, no owned data (R24) |
| feature flag | N/A — no flagged rollout planned (R25) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| SmartyStreets has no stated SLA | Unbounded tail latency could exceed this unit's own p99 budget regardless of this unit's own code | Bounded client-side timeout (R10) turns an unbounded hang into a fast, observable `502`; document the bound as a caller-facing contract, not an internal implementation detail |
| Typeahead traffic pattern (one call per keystroke) may exceed the ≤30 rps assumption (R13) if client-side debouncing is weaker than assumed | Under-provisioned throttling could shed legitimate keystrokes-worth of calls during normal use, degrading the autocomplete experience | R13 is explicitly labelled an assumption in `requirements.md`; revisit the figure once real traffic is observed. A short-TTL response cache (rejected above, for now) is the first lever if this proves out |
| No caching means every keystroke's call round-trips to SmartyStreets even for near-duplicate queries | Provider cost and load scale with keystrokes rather than with distinct addresses looked up | Accepted for this iteration — see Approach; revisit as a performance change request if provider cost or latency in production warrants it |

## Decisions

No ADR raised for this unit. The one candidate decision — the minimum-`q`-length
value — is a low-cost, easily-reversed design parameter with no capability outcome
riding on its exact value, so it is recorded in Approach rather than as an ADR.

| ADR | Decision |
|---|---|
| — | none |

## Requirement coverage

| R-ID | Covered by |
|------|-----------|
| R1 | Flow: GET /address/suggest happy path; SmartyStreets client; Response assembler |
| R2 | SmartyStreets client; Cross-cutting → validation/errors |
| R3 | SmartyStreets client; Cross-cutting → errors |
| R4 | Request validator; Approach (minimum query length); Failure paths |
| R5 | Request validator; Failure paths; Cross-cutting → authn/authz |
| R6 | Response assembler; Flow step 4 |
| R7 | State and idempotency |
| R8 | State and idempotency; Concurrency matrix |
| R9 | SmartyStreets client; Failure paths |
| R10 | SmartyStreets client; Failure paths; Cross-cutting → performance |
| R11 | Risks (SLA-less dependency) |
| R12 | Cross-cutting → performance |
| R13 | Risks (typeahead traffic assumption) — inherited from `requirements.md`, no separate design section needed |
| R14 | Cross-cutting → errors (`429`, gateway-level, not unit-designed) |
| R15 | State and idempotency |
| R16 | State and idempotency; Concurrency matrix |
| R17 | Cross-cutting → errors |
| R18 | Cross-cutting → authn/authz |
| R19 | N/A per `requirements.md` — no tenant dimension on the upstream call itself |
| R20 | N/A per `requirements.md` — no design section needed for a non-applicable NFR |
| R21 | Cross-cutting → observability |
| R22 | Cross-cutting → observability |
| R23 | N/A per `requirements.md` |
| R24 | Cross-cutting → migration/backfill |
| R25 | Cross-cutting → feature flag |

## Change log

| Date | Change ID | What changed |
|------|-----------|--------------|
