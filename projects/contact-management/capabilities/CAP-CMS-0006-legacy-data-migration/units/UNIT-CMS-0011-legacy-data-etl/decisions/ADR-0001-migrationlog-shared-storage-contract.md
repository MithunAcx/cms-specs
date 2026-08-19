---
id: ADR-0001
unit: UNIT-CMS-0011
title: MigrationLog as a shared storage contract, not a network API, between UNIT-CMS-0011 and UNIT-CMS-0012
status: accepted
date: 2026-08-19
deciders: ["@MithunAcx"]
supersedes: []
superseded_by: []
---

# ADR-0001 — MigrationLog as a shared storage contract, not a network API

## Status

accepted

## Context

CAP-CMS-0006's capability design (XD-0002) fixes that UNIT-CMS-0011 owns and is the
sole writer of `MigrationLog`, and that UNIT-CMS-0012 records its own outcomes only
through a logging contract UNIT-CMS-0011 exposes — never by writing the table
directly. What the capability design left open, and handed to this unit's own design
(`capability-design.md` § Handoff notes, "Its own to decide"), is the **shape** of
that logging contract: an in-process call, an internal API, or a queue.

Forces that bear on the choice:

- Both units share the same `target_repo` (`CMS-legacy-data-migration`) — they are
  not units in different deployables that need a network boundary between them for
  organizational reasons.
- Both are one-time, operator-run jobs, never invoked concurrently by design:
  XD-0003 requires UNIT-CMS-0012 to run only after UNIT-CMS-0011's agency phase
  reports complete. There is no steady-state traffic between them to justify a
  service boundary.
- R9/R10 (requirements.md) require exactly one `MigrationLog` row per source record,
  with duplicate-write rejection — a guarantee that is naturally a storage-level
  uniqueness constraint regardless of which contract shape is chosen, so the choice
  is really about how a write *reaches* that constraint, not what enforces it.
- Introducing a live API means UNIT-CMS-0011 must stay "up" (or be re-invoked) to
  serve UNIT-CMS-0012's writes, which adds an availability dependency neither job's
  own lifecycle needs — both are finite jobs, not long-running services.

## Options considered

### Option A — Network API (internal HTTP endpoint or equivalent)
UNIT-CMS-0011 exposes a request/response endpoint; UNIT-CMS-0012 calls it per
outcome it records.
- **For:** A clean, explicit contract surface; easy to version independently;
  matches the pattern every other backend unit in this project uses for
  cross-unit calls.
- **Against:** Requires UNIT-CMS-0011's write path to be a running, addressable
  service at the moment UNIT-CMS-0012 runs — an availability dependency that does
  not otherwise exist between two one-time batch jobs in the same repo. Adds a
  request/response error-handling surface (timeouts, retries, auth) for a caller
  that runs exactly once, for no benefit over a direct write.

### Option B — Asynchronous queue
UNIT-CMS-0012 publishes each outcome as a message; a consumer inside
UNIT-CMS-0011's own logging path writes it.
- **For:** Decouples the two units' runtime lifetimes completely; fits the
  project's SQS/SNS event transport (`stack.md`).
- **Against:** Adds delivery-latency and ordering considerations (at-least-once,
  dedupe) to a write that already has a natural, stronger guarantee available
  directly from the store (a uniqueness constraint) — the queue would be solving a
  problem the storage layer already solves for free at this shared-repo, non-
  concurrent scale. Also adds an extra moving part (queue provisioning, DLQ policy)
  to a capability whose own non-goals explicitly exclude an ongoing sync mechanism.

### Option C — Shared storage contract (chosen)
`MigrationLog` is a single table in this project's own datastore; both units'
code paths write into it directly, under a uniqueness constraint on
`(sourceTable, sourceId)` that enforces "exactly one row per source record"
regardless of which unit's process performs the insert.
- **For:** No availability dependency between the two jobs — UNIT-CMS-0012 can
  write whether or not UNIT-CMS-0011's own process is running, since the
  contract is the schema, not a service. The uniqueness constraint that R9/R15
  already require is what would ultimately enforce "exactly once" under any of
  the three options, so this option gets that guarantee with the fewest moving
  parts. Matches the two units' actual relationship: same repo, sequential
  (never concurrent) execution, one shared piece of state.
- **Against:** Blurs unit ownership slightly more than an API would — "sole
  writer" (XD-0002) is now enforced by *convention* (only this unit's design
  documents the write path UNIT-CMS-0012 is meant to call) and by the
  provisioning/access grants each unit's process is given, not by a hard service
  boundary that would reject an unauthorized caller by construction the way an
  authenticated API endpoint would.

## Decision

We chose **Option C — shared storage contract**.

Because: both units are one-time, sequentially-run jobs in the same repository with
no steady-state traffic between them, so a network or queue boundary would add an
availability/latency dependency and extra failure modes for a guarantee — exactly
one row per source record — that a storage-level uniqueness constraint already
provides more directly and more cheaply at this scale.

## Consequences

**Accepted costs.** "Sole writer" is enforced by documentation and by which
credential each unit's process is provisioned with, not by a hard API boundary that
would reject an unauthorized write attempt outright. If a future capability
introduces a third writer, or if UNIT-CMS-0011 and UNIT-CMS-0012 ever needed to run
concurrently (contradicting XD-0003), this contract would need to be revisited before
that could happen safely.

**Follow-on work.** `architect-unit-interfaces` authors the `MigrationLog` table
(`interfaces/0002_migration_log.sql`) with the uniqueness constraint on
`(sourceTable, sourceId)`, and the entry-shape contract
(`interfaces/migration-log-entry.schema.json`) both units' write paths conform to.

**Constraints imposed on others.** UNIT-CMS-0012's own design and tasks must treat
this unit's `MigrationLog` write path (and its access grant to it) as a fixed
contract to conform to, not as something it designs independently — and must treat a
uniqueness-constraint rejection as "already recorded," never as an error to surface
or retry with a different outcome.

## Reversal

Revisit this if: a future change requires UNIT-CMS-0011 and UNIT-CMS-0012 to run
concurrently (contradicting XD-0003), if a third unit needs to write outcomes into
the same log, or if `MigrationLog` needs to be read by a caller outside this
project's own datastore boundary (e.g. an external reporting system), at which point
a real API surface would earn its cost. Reversal means introducing an API/queue
layer in front of the existing table and migrating both units' write paths to call
it instead of writing directly — a moderate but not severe cost, since the
underlying schema and uniqueness guarantee do not need to change, only how a write
reaches them.

## References

- `UNIT-CMS-0011/requirements.md` R9, R10, R15
- `UNIT-CMS-0011/design.md` § Approach, § Contracts, § State and idempotency
- `CAP-CMS-0006/capability-design.md` XD-0002, XD-0003
- `interfaces/0002_migration_log.sql`, `interfaces/migration-log-entry.schema.json`
