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

## Live maintenance result, 2026-10-28

The live schema-29 store was taken offline after all five bmux clients were
closed. The original 631.6 GiB file passed full SQLite integrity checking. A
verified 24,808,249,904-byte compressed archive of that exact file is retained
at `~/.local/state/provenance-engine/provenance.sqlite.precompact-20261028.zst`;
a full decompression hash matched the original. Temporary rebuildable bmux
DerivedData caches were removed to provide staging capacity. The archive is on
the same filesystem, so it protects against maintenance mistakes but not volume
failure.

Legacy citation indexing completed and opened the schema-29 safety gate. The
first full, no-deletion prune dry run reported 35,962 eligible rows and
235,466,870,125 logical payload bytes. That was a first-pass estimate:
retiring source revisions removed their citation edges and exposed further
redundant snapshots. Bounded, resumable prune passes retired 107,535 payloads
and 244,154,276,037 logical bytes in total, retaining every revision metadata
row. A final dry run reported zero eligible rows. One run stopped after 19,000
committed rows because a concurrent monitoring read made its WAL checkpoint
busy; the idempotent rerun completed the remaining 88,535 rows.

Post-prune ledger and current session/turn payload fingerprints matched the
pre-prune clone exactly (89,425 events, 664 current sessions, 2,057 current
turns). All retained citation targets and current revisions had nonempty
payloads; full `integrity_check` and foreign-key checks passed. The pruned
file had 66,858,944 free pages out of 71,876,688. `VACUUM INTO` produced a
20,285,796,352-byte candidate, whose metadata counts, protected fingerprints,
full integrity check, and foreign keys matched the pruned source. It was
atomically swapped into the live path with a rollback copy retained. An
existing tagged bmux build opened the replacement and appended an event. The
large temporary rollback copies were then removed; the verified compressed
original remains. The live file measured 20,350,136,320 bytes after app writes,
with 992,021,815,296 bytes free on the filesystem (about 924 GiB), versus
678,207,881,216 bytes and roughly 202 GiB free at the original measurement.

The older pr221 smoke-test app was closed after verification. Sustained live
terminal ingestion remains gated on a deployed bounded-writer build and tagged
runtime dogfood; reopening an older writer could recreate full snapshots.

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
3. With writers closed and WAL checkpointed, make a SQLite-consistent recovery
   copy and verify its full `PRAGMA integrity_check`. A separate volume protects
   against volume failure; a verified same-volume compressed archive protects
   only against maintenance mistakes. Retain the original or a verified recovery
   copy until the replacement has been checked and used successfully. A raw
   file copy while WAL writers run is not a backup. Verify free capacity for
   the recovery copy, pruning WAL, compact output, and staged replacement.
4. Index legacy citations transactionally. Run `pruneOutcomePayloads(dryRun:
   true)` over the full candidate set and inspect row/byte estimates. Then
   prune in bounded transactions, recording rows and logical bytes per pass.
   An interrupted pass commits or rolls back as a unit; rerunning is
   idempotent. Validate current-query and exact cited-revision parity against
   the backup, then replay on a copy and compare current projections.
5. Build a compact replacement with `VACUUM INTO` on a filesystem with
   verified staging capacity.
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

## Current rollout gate

The live reclamation and citation-index maintenance are complete. Keep older
bmux builds that predate the bounded outcome writer closed. Before sustained
Codex terminal ingestion, deploy the bounded-writer build and verify file-size,
freelist, revision-count, and ingestion-lag diagnostics during tagged dogfood.
The retained compressed original is a recovery archive on the same volume;
maintain a separate-volume backup if protection against volume failure is
required.
