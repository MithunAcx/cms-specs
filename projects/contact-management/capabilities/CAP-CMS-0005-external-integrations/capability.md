---
id: CAP-CMS-0005
slug: external-integrations
project: CMS
title: External Integrations
status: draft
owner: "@MithunAcx"
created: 2026-08-18
updated: 2026-08-18
---

# External Integrations

## Original ask

> - US address autocomplete on all address forms.
> - Read-only display of related policies with deep-links into the external policy-administration system.
>
> **ARCH-4** — The address-autocomplete provider is called **from the server** (or a server proxy) so provider credentials never reach the browser.
>
> **ARCH-5** — Configuration (connection strings, provider keys, external policy base URL, the producer id used for policy lookups) is read from environment/secret configuration, never hard-coded.
>
> **FR-ADDR-1** — On every address-entry form (add/update brokerage, add/update agency, CGA, accounting address) the system shall offer US address autocomplete.
>
> **FR-ADDR-2** — As the user types a street address, suggestions shall be fetched (via the server/proxy) and selecting one shall auto-fill street, city, state, and zip for that address/row.
>
> **FR-ADDR-3** — State shall populate into either a text field or a state dropdown depending on the form.
>
> **FR-ADDR-4** — Provider credentials shall never be exposed to the browser.
>
> **FR-POL-1** — For a given brokerage or agency, the system shall display related policies drawn from policy-administration data (policy id, status, term, insured, class/subclass).
>
> **FR-POL-2** — The user shall be able to open a selected policy's full detail in the external policy-administration web application; the target page is chosen by policy **class** — healthcare classes (15/16/17) route to the healthcare detail page, all others to the underwriter detail page.
>
> **FR-POL-3** — The external system base URL and the producer id used in the policy lookup shall be configuration values, replacing the hard-coded literal `2105941587`.
>
> **FR-POL-4** — The CMS shall neither create nor edit policies; this is navigation/reference only.
>
> | # | Legacy issue | Modernization requirement |
> |---|---|---|
> | G2 | SmartyStreets credentials and SQL host hard-coded in source. | All secrets, endpoints, and connection strings externalized to secure configuration / secret store. |
> | G4 | Hard-coded server names, UNC paths, magic producer id (`2105941587`), environment URLs. | Everything environment-specific is configurable per environment. |
>
> **NFR-SEC-2** — Secrets and endpoints (DB connection strings, address-provider key, external policy URL, producer id) live in secure configuration / a secret store, never in source.
>
> Server-proxied US street autocomplete (the legacy SmartyStreets US Autocomplete Pro
> capability, kept for this rebuild — intake Q5). Related policies are read via a live,
> read-only call to the policy-administration system at request time — no replication of
> policy data into this project's own PostgreSQL store (intake Q2).

## Outcome measures

| # | Measure | Baseline | Target | How measured | From |
|---|---------|----------|--------|--------------|------|
| M1 | External-provider credentials and endpoints reaching the browser | Legacy: SmartyStreets credentials and the SQL host hard-coded in source (G2); the policy-lookup producer id hard-coded as the literal `2105941587` (G4/DR-4) | 0% — every provider credential and endpoint (address-autocomplete key, policy-system base URL, producer id) lives in secure configuration, and none is ever sent to the browser | Code review of the address-suggest and policy-read integration paths, plus a browser-network-trace check for leaked credentials | intake O3 |

## Outcome-level acceptance

- A1. Address suggestions are fetched only through the server-side proxy; the browser never calls the address-autocomplete provider directly, and its credentials appear nowhere in client-shipped code or network traffic.
- A2. Every address-entry form (brokerage, agency, CGA, accounting address — all owned by CAP-CMS-0003) can call this capability's address-suggest contract and receive street/city/state/zip.
- A3. Related-policy data for a given brokerage or agency is fetched live from the policy-administration system at request time; opening a policy deep-links to the correct external page (healthcare for classes 15/16/17, underwriter otherwise).
- A4. No write path to policy data exists anywhere in this capability.

## Non-goals

- Address form fields, validation, or which screens include an address block — owned by CAP-CMS-0003 (Partner Records Management); this capability only provides the suggest-and-fill contract.
- Creating or editing policies — explicitly out of scope for the whole project, owned entirely by the external policy-administration system.
- Replicating or syncing policy data into this project's own datastore — confirmed against (intake Q2); every policy read is a live call, never a local copy.
- Choosing a different address-autocomplete vendor — confirmed to keep SmartyStreets (intake Q5); switching vendors is a future change request against this capability.

## Constraints

| Constraint | Source | Effect |
|---|---|---|
| Keep SmartyStreets as the address-autocomplete vendor | intake Q5 | No vendor-selection work in this capability; only the server-proxy integration against the existing vendor |
| Live read-only call to the policy-administration system (no replica) | intake Q2 | This capability's policy-read path has a hard runtime dependency on that external system's availability; there is no local fallback data |
| No write path to policy data anywhere | raw ask FR-POL-4 / API-5 | The interface contract for this capability must not expose any mutating policy endpoint |
| Serverless compute (cold starts) | `stack.md` | Both the address-suggest proxy and the live policy-read call inherit cold-start latency; this capability's own NFRs must state a budget consistent with that, not assume an always-warm instance |

## Decomposition rationale

Address autocomplete and read-only policy integration are grouped into one capability
rather than two, or folded into the capabilities that consume them, because they share
the one property that makes them a coherent domain: both are server-proxied calls to a
system this project does not own, bound by the same architectural mandate (ARCH-4/ARCH-5,
G2, G4) that credentials and endpoints never reach the browser and are always
configuration, never hard-coded. Measuring that mandate once, across both integrations,
is more honest than measuring it twice in two unrelated capabilities. Folding address
autocomplete into Partner Records Management (its only consumer) and policy display into
wherever it is shown was considered and rejected: it would scatter the "keep external
credentials off the browser" outcome across every capability that happens to call an
external system, instead of giving it one home with one measurable target. The two
integrations remain in one capability rather than splitting further because both are
thin, read-only, externally-dependent proxies of comparable size — splitting them would
produce two capabilities too small to be worth the split (each closer to "1 unit" than a
real domain).

## Dependencies

| Direction | What | Why |
|---|---|---|
| upstream | Identity & Access Control (CAP-CMS-0001) | Endpoints in this capability still require an authenticated Viewer-or-above request |
| downstream | Partner Records Management (CAP-CMS-0003) | Every address-entry form calls this capability's address-suggest contract; brokerage/agency detail screens call its policy-read contract |
| external | Address-autocomplete provider (SmartyStreets) | Address suggestions |
| external | Policy-administration system | Read-only policy data and the deep-link target |

## Open questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | The mechanism for the live read-only call to the policy-administration system (direct DB read, an API it exposes, or something else) is not yet named — intake Q2 confirmed "live call", not the transport. Mirrored from `capability-design.md`'s own open question. | @MithunAcx | open |

<!-- GENERATED:units — do not hand-edit below. Written by pm-state-rollup. -->
## Units

<!-- /GENERATED:units -->
