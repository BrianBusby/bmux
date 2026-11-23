# Proposed replay-stable Codex source evidence

Status: design proposal only; no contract, schema, privacy policy, rollout, or
slice acceptance is changed by this document. Read with
[session visibility](session-visibility.md),
[provenance integration](../provenance-integration.md), and the current Project
Truth. The immediate motivation is the rejected-event and replay evidence in
[draft PR #269](https://github.com/BrianBusby/bmux/pull/269). The integration
document's idempotency description is a target for verified retries, not proof
that every current duplicate classification is correct.

## Current boundary

`CLI/CLIProvenanceCodexTranscriptImporter+IDs.swift` derives an event ID from
provider session, line ordinal or line number, and an emission kind. It does
not prove that two observations with that ID contain the same source record,
that they came from the same source incarnation, or that their context is the
same. The importer catches error-description substrings mentioning
`provenance_events` and a constraint/duplicate word; the hook-association path
also uses this classifier. PE's public append response identifies an accepted
event but has no typed duplicate disposition or public event-by-ID comparison.
The internal SQLite repository inserts raw event and projection in one
transaction, so throwing from projection also rolls back that raw event.

Live acquisition in `CLIProvenanceCodexTranscriptImporter+Live.swift` opens a
file and inspects that descriptor, reads at most 64 KiB per pass, buffers an
incomplete line, and assigns the cursor only after the pass succeeds. The
current cursor file in `CLIProvenanceCodexTranscriptCursor.swift` records a
path, provider session, device/inode, an optional hash of the first 256 bytes,
line and byte offsets. A digest is absent for files shorter than 256 bytes;
matching device/inode and prefix cannot establish append-only continuity or
exclude rewrites, inode reuse, replacement or ABA. Restoring a cursor replays
its prefix and falls back to fresh state on verification failure. The cursor
store expires operational files after 30 days. The batch parser instead reads
a whole file and does not retain original source bytes or byte ranges in
`TranscriptLine`. Neither a line number nor the optional provider ordinal is
an independently established globally unique record identity.

`CLIProvenanceCodexTranscriptImporter+Git.swift` queries the current Git
branch, HEAD, dirty state and other local context while building an event. A
later import of the same transcript can therefore generate a different PE
event even if its provider bytes did not change. Comparing complete newly
constructed event payloads is conservative, but does not by itself give useful
idempotent retry across these normal context changes. Conversely, matching an
ID, decoded text, timestamp, or content digest without a proven source scope
cannot prove a replay.

## Proposed proof and disposition

The following is a candidate contract to review, not an accepted wire format:

1. At a complete-line boundary, the adapter supplies a versioned source
   reference: provider and provider session/thread identity with evidence of
   their association; a verified source-incarnation reference and coverage
   state; exact source byte range and line position; the event emission slot;
   parser/normalizer version; and a content commitment. Record position and
   content must be bound to the same captured file descriptor and the same
   validated metadata. A line that produces several PE events needs a distinct
   stable emission slot for each event. An unsupported or ambiguous provider
   association, record boundary, or source incarnation yields **unverifiable**.
2. A proposed v1 byte commitment would cover the exact line bytes excluding
   the terminating LF, with CR and all other bytes preserved, plus a
   domain-separated encoding of the proof version and scope. This is not a
   JSON canonicalization rule: whitespace, ordering, duplicate keys, malformed
   UTF-8, partial/oversized lines and provider format changes need explicit
   handling. Before implementation, choose and specify canonical encoding,
   digest/MAC algorithm, exact delimiter and end-of-file semantics, maximum
   sizes and test vectors. If the ingestion path cannot retain enough bytes to
   verify a line within policy and bounds, it must report unknown rather than
   fabricate a match.
3. The reference must also bind every source-derived context input relevant to
   that emission: validated session/thread and applicable turn association,
   preceding metadata/context state or its verifiable checkpoint, and parsing
   version. Equal line bytes at the same apparent offset are insufficient if
   preceding context changed. The proof must define how a checkpoint is built,
   restored and invalidated, including how it covers lines spanning read
   chunks. A hash chain can detect some changes relative to a trusted retained
   checkpoint; it does not authenticate a producer, prove file continuity by
   itself, or resolve missing history. No identity is established from timing
   or similar text.
4. Keep local Git/workspace enrichment separate from the provider source proof.
   A verified replay returns the previously accepted interpretation and must
   not overwrite it with a newly sampled HEAD or dirty state. If refreshed Git
   facts are wanted, emit a separately scoped and timestamped observation using
   its own identity and provenance. How to migrate legacy events whose provider
   and Git facts are already combined remains an open design choice.
5. PE, not a string classifier in bmux, decides inside a serialized append
   transaction: **inserted**, **verified existing source observation**,
   **conflict**, **unverifiable**, or a propagated storage/other error. A
   verified existing result requires matching evidence under a supported proof
   version and unambiguous ownership; it must not mean that a plan was
   accepted, a command succeeded, or an external effect occurred. A duplicate
   event ID with a different source commitment or scope is a conflict, not
   successful deduplication. Equality of hashes alone is not enough when the
   underlying source incarnation or context is uncertain.

The API should negotiate a new capability/version explicitly. An older server
or client that cannot validate the proof must return unsupported/unknown rather
than treating a new request as an ordinary append or an arbitrary constraint
as a verified duplicate. The existing append contract must not silently change
its error or idempotency semantics for unrelated callers. Both the transcript
adapter and the hook-association consumer need a shared, reviewed disposition
path; hook evidence has different available source identity and must not borrow
transcript proof. Existing older clients that continue to classify text cannot
be made safe by a new response field they ignore.

## Atomicity, conflict evidence, and recovery

For a new accepted source observation, PE must atomically bind the source proof,
raw accepted event and applicable projection effects; a success receipt must
mean that this transaction committed. For a verified retry, PE returns the
existing evidence reference without applying the event a second time. A cursor
or batch checkpoint can advance only over every complete source unit whose
emissions have each reached a supported durable disposition. The separate
cursor file is not atomic with SQLite: a crash after commit and before cursor
write must retry safely, and the converse must never acknowledge an uncommitted
unit. Multiple events from a single line and multi-line chunks must survive a
failure after an earlier committed prefix without dropping or duplicating it.

For conflicting source claims, preserve the original event and the new claim's
minimal policy-approved evidence, source references and reason in one durable
transaction; record affected scope and do not promote ambiguous projections.
The existing event-ID primary key cannot retain two different payloads under the
same ID, and the current public response cannot say "raw retained, projection
unresolved." The implementation must explicitly design conflict records,
retention, bounded capacity and inspection before claiming this behavior. It
must not silently replace or drop the first event. If preserving a rejected
claim's required evidence is not permitted, cannot be verified, or cannot be
made durable, leave the source unit unacknowledged and expose a durable or
reconstructible observation gap. A source-file path alone is not durable
retention: the file can rotate or disappear. Independently scanning prompts,
approvals, failures, or finish-time pending prompts after an ingestion gap also
needs capability-aware handling; an unrelated commentary or later successful
read must not clear an unresolved gap.

Partial lines, truncation, replacement, resumed imports, duplicate/out-of-order
records and conflicting or absent metadata require explicit transition rules.
An old prefix or provider ordinal may be reused. A new source incarnation is
not automatically the same session or a continuation; where that association
cannot be proven, quarantine or leave it unresolved. Existing scanners,
subscriptions, native/React views and CLI diagnostics must agree on the same
gap and its scope. Successful local PE reads are not proof of live provider
connection health. Bound buffers, retry frequency, output and storage, and
measure their behavior rather than silently dropping evidence.

## Migration, privacy, and compatibility

Existing events have event IDs and selected normalized payloads but no
replay-stable line commitment, proven incarnation or context proof. Do not
backfill proof merely from their IDs or from the current transcript path. A
legacy row remains **unverifiable** unless a separately reviewed reconstruction
can establish its exact original source and coverage; missing, rotated, edited,
expired or privacy-deleted evidence remains unknown. Backfill, if adopted,
needs bounded work, a durable watermark and reconciliation with concurrent
appends; a partially migrated store must not appear fully verified. Replay of
recorded artifacts must be deterministic; any new parsing/reinterpretation is a
separately versioned recomputation.

The existing integration boundary keeps raw provider envelopes, unrestricted
transcripts and hidden reasoning out of PE; expanded raw prompt/transcript
capture requires its own policy. A source digest or keyed MAC can itself be
sensitive or linkable, particularly for predictable short lines. A keyed MAC
may reduce offline guessing but creates key storage, access, rotation, backup,
loss and cross-device comparison questions; it is not an identity or tamper
proof. Scope data, paths, byte offsets, hashes, timestamps and conflict
metadata also need data-minimization and access review. Specify retention,
deletion, encryption/permissions and diagnostic redaction before persistence.
If keys or source evidence expire, previous proof must not silently remain
verifiable. Do not put raw transcript text or secret-bearing errors in logs.

A mixed-version rollout needs both writer and reader compatibility, not merely
`PRAGMA user_version`: #258 demonstrated an already-open old writer after a
migration. An event-only trigger misses independent PE writers, and a trigger
prototype is not a proven fleet-wide fence. Until a reviewed fence or managed
drain, snapshot consistency and old-bundle cutover are proven, old clients may
still bypass proof or hide unknown state. Database restore/copy and sidecar
rollback need an external continuity authority or explicit unknown; a local
UUID/hash alone cannot establish history across rollback. No production release
or broad transport change is implied.

## Decisions and validation before implementation

Resolve with evidence: stable provider session/thread and source-incarnation
association; proof scope and key/retention policy; line and context encodings;
what evidence may be retained on conflict; bounded backfill and gaps; handling
of old clients and unavailable proof; and whether/how verified retries remain
possible when a legacy row lacks proof. Choose whether failing closed may pause
normal recovery only together with visible, actionable reconciliation; the
#269 synthetic duplicate-prefix control shows that treating every duplicate as
an error alone can prevent later work from being imported.

Minimum tests include exact same-source retries with changed Git state; same ID
with changed source bytes, context or session; identical text in different
incarnations/sessions; duplicate provider ordinals; ambiguous child/fork and
metadata; different emission slots; Unicode, delimiters, duplicate keys,
partial/oversized lines and 64 KiB boundaries; rename/rotation, inode reuse,
in-place rewrite and ABA; concurrent monitors; source deletion and privacy/key
expiry; crash at every event/proof/checkpoint boundary; committed prefix and
failed suffix; legacy backfill, replay/rebuild and migration interruption;
conflict persistence without cross-session leakage; old reader/writer and
new-client negotiation; restore/copy; bounded queues and five-session load.
Test both public SDK dispositions and normal CLI/native consumers, including
explicit unknown, status recovery and no false acknowledgment. Source and
binary versions, test transport and unavailable native checks must be recorded.
