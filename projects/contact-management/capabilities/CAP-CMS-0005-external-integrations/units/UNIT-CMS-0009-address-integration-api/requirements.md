---
id: UNIT-CMS-0009
slug: address-integration-api
project: CMS
capability: CAP-CMS-0005
title: Address Integration API
kind: backend
target_repo: CMS-external-integrations
owner: "@MithunAcx"
engineering:
  frontend: { applicable: false }
  api:      { applicable: true }
created: 2026-08-18
updated: 2026-08-18
---

# Address Integration API

## Scope

A stateless server-side proxy to SmartyStreets (kept per intake Q5), exposing one
suggest endpoint whose response shape matches UNIT-CMS-0005's address sub-resource
(XD-0002 of this capability's design). Owns no persistent entity. Independent of every
other unit in the project — can be built in parallel with anything else.

**In scope:**
- `GET /address/suggest` — proxying to SmartyStreets, credentials held server-side only
- The suggestion response shape (line1/city/state/zip) matching UNIT-CMS-0005's address fields

**Out of scope:**
- Which forms call this endpoint, or how they use the result (UNIT-CMS-0006)
- Any address data persistence (UNIT-CMS-0005)
- Whether state renders as a text field or a dropdown on the consuming form (FR-ADDR-3, owned by the calling frontend)

## Requirements

Each requirement is atomic, testable, and traced to a capability outcome
measure or acceptance condition. R-IDs are permanent — never renumber, never
reuse, never delete.

| R-ID | Requirement | Traces to | Priority |
|------|-------------|-----------|----------|
| R1 | `GET /address/suggest?q=` returns a list of candidate US addresses `{ line1, city, state, zip }` (XD-0002 shape), proxied server-side to SmartyStreets for the given free-text partial address. | CAP-CMS-0005/A2, FR-ADDR-1, FR-ADDR-2 | P0 |
| R2 | The browser never calls SmartyStreets directly — every provider call is made server-side by this unit, so the provider's credentials and endpoint never appear in client-shipped code or in any network traffic the browser originates. | CAP-CMS-0005/A1, ARCH-4, FR-ADDR-4 | P0 |
| R3 | The SmartyStreets API key and endpoint are read from server-side secure configuration; neither appears in the response body, a log line, or an error message. | CAP-CMS-0005/M1, NFR-SEC-2 | P0 |
| R4 | A request whose `q` parameter is missing, empty, or shorter than the minimum length this unit defines is rejected with `400 invalid_request` before any upstream call is made. | CAP-CMS-0005/A2 | P1 |
| R5 | An unauthenticated request is rejected with `401`; an authenticated request from any role of Viewer or above is accepted — this unit has no elevated-role requirement above Viewer. | CAP-CMS-0001/A1, A2 | P0 |
| R6 | A returned suggestion carries exactly `line1`, `city`, `state`, `zip` — no other SmartyStreets response field (e.g. delivery-point validation metadata, geocoordinates) is ever forwarded to the caller. | CAP-CMS-0005/A1, M1, XD-0002 | P1 |
| R7 | A retried or duplicated `GET /address/suggest` call has no side effect beyond re-issuing the upstream lookup — the operation is naturally idempotent and needs no dedupe key. | — (NFR: idempotency) | P2 |
| R8 | Two concurrent callers requesting the same or different `q` each receive an independent proxied read; neither call observes or blocks on the other. | — (NFR: concurrency) | P2 |
| R9 | When SmartyStreets is unreachable or returns an error, the caller receives `502 upstream_unavailable`; this is distinct from, and never conflated with, SmartyStreets successfully answering "no matches" (`200` with `suggestions: []`). | — (NFR: dependency) | P0 |
| R10 | When SmartyStreets does not respond within this unit's stated timeout budget (R-NFR-latency), the caller receives `502 upstream_unavailable` rather than the request hanging past that budget. | — (NFR: dependency) | P0 |

## Behaviour detail

**R1 / R6 — response shape.** The response shape is fixed by XD-0002 of
`capability-design.md` to match UNIT-CMS-0005's own address sub-resource field-for-field,
so a consuming form can fill `line1`/`city`/`state`/`zip` directly from a selected
suggestion with no reshaping. Any additional field SmartyStreets returns (validation
flags, geocoordinates, delivery-point barcode data) is dropped by this unit before the
response is assembled — never forwarded, per R6.

**R9 vs. R1 — outage vs. answer.** "SmartyStreets is down or erroring" (R9/`502`) and
"SmartyStreets answered with zero matches for a valid but unmatched query" (`200`, empty
`suggestions`) are different outcomes and must never share a status code or an error path.

**R4 — minimum query length.** SmartyStreets' own US Autocomplete Pro API imposes no
documented minimum, but a one- or two-character `q` produces a call with no useful
signal and needlessly consumes provider quota; this unit defines its own floor (design
decision, not yet fixed here) and rejects below it with `400` rather than forwarding a
degenerate query upstream.

## Non-functional requirements

| R-ID | Category | Requirement |
|------|----------|-------------|
| R11 | availability | This unit's own compute carries the platform default; its *effective* availability for a caller is bounded by SmartyStreets' own availability, which is not owned by this project. `R9`/`R10` are how that bound is made observable rather than silently inherited. |
| R12 | latency | p95 ≤ 900 ms, p99 ≤ 2000 ms end-to-end, inclusive of serverless cold start (per `stack.md`'s cold-start consequence) and the upstream round trip — consistent with intake NFR-PERF-1's "first results within ~1s" search-responsiveness target. ASSUMPTION: no measured baseline exists yet for SmartyStreets' own latency; revisit once observed. |
| R13 | throughput | Peak figure: ≤30 requests/second. ASSUMPTION, not a measured figure: derived from intake Q8's "<50 concurrent staff" (small-scale), inflated relative to UNIT-CMS-0010's ≤15 rps because a typeahead field issues one call per keystroke (client-side debounce assumed, not verified) rather than one call per screen view; label per rule 30-nfr-floor.md and revisit if traffic proves otherwise. |
| R14 | surge | At 2× peak (~60 rps), API Gateway throttling (per `stack.md`) sheds excess requests with `429` + `Retry-After`; nothing here is exempt from shedding, since every request is a discretionary, re-issuable read. |
| R15 | idempotency | Covered by R7 — `GET` is inherently idempotent; no key is derived or stored. |
| R16 | concurrency | Covered by R8 — no shared mutable state exists in this unit, so no contended operation exists to enforce ordering on. |
| R17 | rate limits | Per caller and per this unit's own endpoint, enforced by API Gateway throttling (`stack.md`); response is `429` with `Retry-After`, matching CAP-CMS-0005's shared error envelope. |
| R18 | authorization | Minimum role: Viewer (R5). No service-credential caller is defined for this unit; ownership rule is "the caller's own session, scoped to their own tenant" — this endpoint returns no tenant-scoped data (it proxies a public geocoding lookup), so no per-tenant filtering applies to the upstream call itself. |
| R19 | tenant isolation | N/A for the upstream call itself — SmartyStreets returns generic public address candidates, not tenant-owned data. The endpoint still requires an authenticated caller scoped to a tenant (R5), so access to the endpoint is gated, even though the data returned carries no tenant dimension. |
| R20 | audit | N/A — this unit performs no create/update/delete operation, so CAP-CMS-0001/M3's audit-log obligation (scoped to mutating operations) does not apply here. |
| R21 | observability | Metrics: request count, upstream call latency, upstream error rate. Structured log fields: caller id, tenant id, query length (never the raw `q` value, since a partial address a user is typing may itself be personal data in progress — R22). Trace span boundary: the upstream call to SmartyStreets is its own span. |
| R22 | data classification | `q` (the free-text partial address entered by the caller) is treated as personal data in progress — never logged in full, only its length. Returned suggestion fields (`line1`, `city`, `state`, `zip`) are generic public address candidates from the provider's own database, not associated with any data subject at the point this unit returns them, so they are not personal data — they become personal data only once a caller selects one and a consuming form persists it against a specific record, which is out of this unit's scope. |
| R23 | retention and deletion | N/A — this unit persists nothing; there is no retention period to define and no erasure path to build. |
| R24 | migration and backfill | N/A — greenfield unit, no data owned, nothing to migrate or backfill. |
| R25 | feature flag | N/A — no flagged rollout is planned for this unit. |

## Data

Entities this unit owns, reads, or emits — language-neutral. Shapes belong in
`interfaces/`, not here.

| Entity | Owned/Read | Notes |
|---|---|---|
| Address suggestion (external) | Read (never persisted) | Read live from SmartyStreets per request; this unit is the only place that provider's response shape is translated into the XD-0002 contract shape |

## Dependencies

| On | Kind | Notes |
|---|---|---|
| UNIT-CMS-0001 | contract | Auth — every call still requires an authenticated Viewer-or-above request |
| SmartyStreets (US Autocomplete Pro) | external | Live proxied call; credentials and endpoint held server-side only per R2/R3 |

## Assumptions

- Peak throughput of ≤30 rps (R13) is derived from intake Q8's qualitative "small scale" statement plus a typeahead-vs-single-call inflation factor, not a measured figure. Revisit once real traffic is observed.
- Client-side debouncing of keystrokes before a call is fired is assumed but not confirmed — it is owned by the consuming frontend (CAP-CMS-0003), not this unit; if it turns out not to debounce, R13's figure should be revisited.
- No service-credential caller exists for this unit today (R18); only user-session callers are in scope. If a service-to-service caller is added later, its ownership rule needs its own requirement.
- SmartyStreets has no stated SLA in the intake material; R11/R12 treat it as best-effort and make the bound observable (`502`) rather than assuming any particular uptime.
- The minimum `q` length for R4 is a design-time decision, not fixed by a capability outcome; `design.md` should state the chosen value and cite this row.

## Open questions

| # | Question | Blocks | Owner | Status |
|---|----------|--------|-------|--------|
