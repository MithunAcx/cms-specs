---
id: ADR-0001
unit: UNIT-CMS-0005
title: Account-code generation mechanism for new agencies
status: accepted
date: 2026-08-19
deciders: ["@MithunAcx"]
supersedes: []
superseded_by: []
---

# ADR-0001 — Account-code generation mechanism for new agencies

## Status

accepted

## Context

`POST /agencies` must assign a new agency a generated account code as part of
creation (FR-AGY-2, R12) — the equivalent of the legacy `ppsp_add_accountcode`
procedure. Once assigned, this code is externally visible (it appears on the
agency record returned to the caller and, per `capability.md`'s non-goals, is
consumed by downstream billing/reporting flows outside this capability), so
getting its generation wrong is expensive to unwind after agencies have already
been created with a given format.

Two constraints bound the choice. First, `capability.md`'s own decomposition
rationale and intake Q1/A1 commit this capability to a clean redesign — the new
PostgreSQL schema follows the raw ask's domain model, not a column-for-column or
procedure-for-procedure mirror of the legacy SQL Server logic, so reproducing
`ppsp_add_accountcode`'s exact algorithm is explicitly out of scope. Second, R26
requires every write in this unit to avoid an application-level read-then-write
race — the code must be produced without introducing exactly the kind of race
XD-0002's `version` field exists to prevent elsewhere.

## Options considered

### Option A — Per-tenant atomic sequence, formatted as a code
- A store-enforced atomic counter, scoped per tenant, incremented as part of the
  same create operation that inserts the agency row; the returned code is that
  sequence value in a fixed, human-legible format (e.g. a tenant-scoped prefix
  plus a zero-padded number).
- **For:** uniqueness is guaranteed by the store atomically, with no
  read-then-write window; codes are sequential and legible, matching the spirit
  of a "next account number" a back-office user would recognize.
- **Against:** sequential codes reveal roughly how many agencies a tenant has
  created, and the format is new — nothing before it to be compatible with.

### Option B — Randomly generated code (e.g. a short opaque token)
- Generate a random code at create time and check it for collision.
- **For:** reveals nothing about volume; simple to generate.
- **Against:** collision-checking against a random value either needs a
  read-then-check-then-write (the exact race R26 exists to avoid) or a
  store-level uniqueness constraint with retry-on-conflict, which is more
  moving parts for no benefit over Option A at this capability's stated volume
  (low hundreds of agencies); an opaque code is also harder for a back-office
  user to reference in conversation than a sequential one.

### Option C — Reproduce the legacy `ppsp_add_accountcode` algorithm as-is
- Port the stored procedure's exact logic into this unit.
- **For:** byte-for-byte continuity with whatever format any existing downstream
  consumer already expects.
- **Against:** directly contradicts intake Q1/A1 and `capability.md`'s own
  decomposition rationale, which commit this capability to a clean domain-model
  redesign rather than a physical port of legacy logic; the legacy procedure's
  internals are not documented as a requirement anywhere in the raw ask, so
  porting it "as-is" would import undocumented legacy behaviour as unreviewed
  fact — the exact failure mode `00-core.md` warns against.

## Decision

We chose **Option A — a per-tenant atomic sequence, formatted as a code**.

Because: it is the only option that satisfies R26's no-read-then-write-race
constraint atomically, at the store level, without importing legacy procedure
internals we have no requirement basis to reproduce.

## Consequences

**Accepted costs.** The exact code format (the human-legible prefix/padding
shape) is new and not verified compatible with any legacy or downstream
consumer's expectations. Sequential codes also make each tenant's agency count
observable to anyone who can read the code, which is an acceptable disclosure
given account codes are already visible to the same in-tenant Editors who created
the agencies.

**Follow-on work.** Confirm with any downstream consumer of agency account codes
(outside this capability) that the new format is acceptable before this unit is
handed off — tracked as a Risk in `design.md`.

**Constraints imposed on others.** `interfaces/schema.sql` must define the
per-tenant sequence as a store-enforced construct (not an application-computed
counter). UNIT-CMS-0006 (partner-records-ui) treats the returned account code as
an opaque display string and imposes no format assumption of its own.

## Reversal

Revisit if a downstream consumer requires a legacy-compatible code format, or if
per-tenant sequential codes prove to leak more than is acceptable and an opaque
identifier is required instead. Reversal costs a schema migration (a new
generation mechanism) plus a decision on whether to backfill or grandfather
already-issued codes — not a contract change, since the field's shape
(`accountCode: string`) does not have to change to switch mechanisms.

## References

- `UNIT-CMS-0005/requirements.md` R12
- `UNIT-CMS-0005/design.md` § Approach, § Components (Account-code generator), § Risks
- `interfaces/schema.sql` (per-tenant sequence construct)
