# Provenance Engine storage retention, version 1

This policy applies to the PE-owned SQLite store. It is implemented by schema
version 29 and the outcome writer. It is a storage gate for live terminal Codex
ingestion. The separate legacy `provenance-engine` checkout is not the current
package; the current package lives in the bmux monorepo.

## Measured cause, 2026-10-26

The live schema-28 file occupied 678,207,881,216 bytes (631.6 GiB). Its page
count was 165,578,096 at 4096 bytes and its freelist was 97,643,982 pages
(372.5 GiB). A read-only `dbstat` scan measured:

| SQLite object | Bytes | GiB |
| --- | ---: | ---: |
| Session outcome revision table | 236,551,921,664 | 220.3 |
| Turn outcome revision table | 41,359,458,304 | 38.5 |
| Event ledger table | 221,347,840 | 0.21 |
| Turn revision primary-key index | 7,544,832 | 0.0070 |
| Turn revision turn index | 7,110,656 | 0.0066 |
| Turn revision session index | 4,943,872 | 0.0046 |
| Session revision primary-key index | 3,710,976 | 0.0035 |
| Session revision session index | 2,723,840 | 0.0025 |
| Session revision rule index | 5,939,200 | 0.0055 |

The session outcome writer stored a full copy of every turn outcome inside each
session revision, and each accepted change produced another full session
snapshot. Content-identical revision IDs also rewrote their JSON whenever
provenance metadata changed. This explains the large revision tables and free
pages; index growth and the event ledger are minor by comparison. A read-only logical-byte scan found 36,522 session revision payloads totaling
236,757,643,633 bytes and 80,939 turn revision payloads totaling
41,268,111,354 bytes. The largest session JSON was 288,354,365 bytes and the
largest turn JSON was 9,071,774 bytes. In that scan, 635 current session
payloads totaled 1,651,965,388 bytes and 1,940 current turn payloads totaled
937,375,632 bytes: 2.41 GiB combined. The scan used a live read snapshot, so
its row totals differ slightly from later bounded diagnostic samples. None of these diagnostics
print payloads.

## Read-only pre-maintenance estimate

The live schema is still 28, so the version-1 citation index and prune dry run
cannot safely run against it. A read-only upper bound from a later sample is
35,914 superseded session rows and 79,048 superseded turn rows (total rows
minus current rows). The two revision tables occupied 277,911,379,968 physical bytes in the
earlier `dbstat` snapshot, and their later logical JSON totaled
278,025,754,987 bytes. These are separate live snapshots and therefore
approximate upper bounds on payload bytes that pruning might retire, not a
savings forecast. The actual candidate set will be smaller after
keeping eight historical revisions per owner and all indexed citations and
pins. The version-1 dry run reports exact candidate rows and logical payload
bytes after migration and citation indexing, before any deletion.

## Record classes

- Event evidence: the append-only accepted ledger has no age cutoff in this
  policy. Replay and rebuild use it as the source of truth.
- Current projections: retain the current turn and session outcome payloads and
  their exact revision IDs. Session payloads persist aggregate fields and exact
  constituent turn revision IDs; query responses hydrate the turn payloads.
- Superseded outcome revisions: retain metadata rows (ID, owner, rule,
  fingerprint, watermark, creation time) indefinitely. Keep the current payload,
  eight uncited historical payloads per owner, all payloads cited by retained
  PE projections, and explicitly pinned revisions. Other historical payloads
  become empty strings; an exact read reports `revision_payload_expired`.
  Migration records legacy revision IDs separately, so a refreshed legacy ID
  cannot become eligible for automatic retirement before citation indexing.
- Semantic inference and message records: this policy leaves their payloads
  and metadata intact. A separate, reviewed retention policy is required
  before expiring any semantic payload.
- Operational data: citation and pin rows support safe retention. Bounded
  daily file-size samples (32 days) are stored in a sidecar by the diagnostic
  command when explicitly requested. The report has no private payload text.

The maintained bmux app currently requests session outcomes by session ID without
persisting an exact outcome revision ID. PE itself stores exact revision
references in session, related-session, and artifact-collision projections;
those JSON records are citation-indexed. External durable exact-revision
citations remain unsupported until a public pin/register contract is added,
so new consumers must not persist such citations under this policy.

The eight-revision limit is a count boundary, not a time cutoff. It permits
recent exact-revision inspection while bounding uncited full snapshots from
sustained writes. Stored PE citations and pins can exceed the bound when audit
requires them. Citation indexing includes session, related-session, and
artifact-collision projection JSON. A future durable consumer that cites an
outcome revision must register that reference before depending on the payload.

## Replay and permanent loss

After a payload is retired, current query results remain available and metadata
still identifies the historical revision. The event ledger can rebuild
projections using the current deterministic rules and accepted evidence. An
exact historical JSON snapshot from an older rule or from evidence that was
subsequently corrected cannot always be recreated byte for byte. Retiring it
permanently loses that exact snapshot unless a verified backup retains it.
Consequently, external citations must be pinned and PE projection references
must be indexed before pruning. This is why schema-28 databases start with a
closed legacy-citation gate.

## Maintenance procedure

1. Use `scripts/storage_report.py --deep` for a payload-free report and record
   file/WAL size, free space, rows, logical bytes, page bytes, and alerts.
   Run `--record-sample` daily to compute daily file growth. An ingestion-lag
   value remains unavailable until the live cursor is implemented; the age of
   the last accepted event is reported separately.
2. Deploy a writer with schema 29 and verify focused retention, exact-query,
   citation, and replay tests. Stop all PE-using bmux processes before any
   offline rebuild. Check the database and WAL are stable. Never run a live
   in-place `VACUUM` on the 632 GiB file.
3. Make a SQLite-consistent backup on a separate volume, verify
   `PRAGMA integrity_check`, and retain the original file until the rebuilt
   replacement has been checked and used successfully. A raw file copy while
   WAL writers run is not a backup. Verify free capacity for the full backup,
   pruning WAL, compact output, and a staged replacement before proceeding.
4. Index legacy citations transactionally. Run `pruneOutcomePayloads(dryRun:
   true)` over the full candidate set and inspect row/byte estimates. Then
   prune in bounded transactions, recording rows and logical bytes per pass.
   An interrupted pass commits or rolls back as a unit; rerunning is
   idempotent. Validate current-query and exact cited-revision parity against
   the backup, then replay on a copy and compare current projections.
5. Build a compact replacement with `VACUUM INTO` on the separate volume.
   Verify integrity, schema version, row counts, citations, and current queries.
   Stage the compact file on the destination filesystem only if space permits.
   With all writers stopped, atomically rename the original to a rollback
   path and the verified candidate into place. Do not delete the original
   until the app has reopened and checks pass. Restore the original on failure.

Routine diagnostics thresholds: file over 50 GiB; freelist over 10 GiB and
25% of pages; WAL over 1 GiB; more than 256 revisions in any one session; daily
file growth over 5 GiB. These are investigation alerts, not automatic
vacuum/prune triggers. Inspect the reason and citation coverage before running
maintenance. The next ingestion slice must add a cursor-backed ingestion-lag
threshold (five minutes while an associated session is active).

## Current live blocker

At measurement time five tagged bmux processes were open against the live store.
Available local space varied from about 188 to 193 GiB as the WAL checkpointed.
The live file is 631.6 GiB, and the page bytes in use are about 259 GiB before
pruning. No separate data volume was mounted. A conservative plan requires at
least 632 GiB for a verified SQLite backup plus up to 259 GiB for a compact
candidate on separate storage, and up to 259 GiB of staging space on the local
filesystem before an atomic replacement; leave additional room for WAL and
operating-system writes. Actual requirements may be lower only after a measured
prune and compact dry run. The current 188–193 GiB local space cannot support
the conservative staging bound. The safe backup/rebuild/replacement procedure cannot run under
these conditions. No live deletion, migration, or replacement was attempted.
