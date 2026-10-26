# Live Codex transcript cursor hardening

## Source rules and owners

The bmux `AGENTS.md` project-state and tagged-build rules, `skills/bmux-testing`,
`skills/bmux-architecture`, `skills/bmux-dev-workflow`, and the personal
continuous-code-quality guidance govern this slice. The maintained CLI monitor
(`CLI/BMUXCLI+CodexTranscriptMonitor.swift`) owns provider-session association,
file discovery, and polling. The canonical importer
(`CLI/CLIProvenanceCodexTranscriptImporter*.swift`) owns Codex normalization and
stable event identity. PE remains the only durable evidence/projection writer
through `ProvenanceEngineClient.appendEvent`.

## Measured gap

The monitor currently creates an in-memory `LiveImportState` on each start. The
importer reads all bytes from the current offset to EOF in one allocation. A
malformed line fails the whole batch and is retried forever; a replacement with
the same size is not detected. Stable event IDs make a restart duplicate-safe,
but they are not a persisted bounded cursor. The PE storage report consequently
has no cursor-backed ingestion lag.

## Implemented slice

- Store only versioned cursor metadata (source identity, provider session,
  acknowledged complete-line byte offset, line number, timestamp) in a private,
  bounded bmux state file. Never store raw transcript text, pending prompt text,
  or parser reasoning in the cursor.
- On restart, validate file identity and reconstruct parser context by scanning
  the acknowledged prefix in bounded chunks with PE appends disabled; resume
  emitting from the saved offset. This recovery scan is off terminal input and
  rendering paths. If the file changed, start at zero; stable event IDs keep
  accepted facts idempotent.
- Read at most 64 KiB per append cycle, cap a single buffered line, skip malformed
  lines with counts, and process backlog without waiting for another file event.
  Advance and persist the cursor only after all accepted events in the chunk
  receive a PE acknowledgment. A failed append replays the chunk.
- Expose metadata-only cursor lag, skipped-line and retry counters through
  `bmux provenance diagnostics codex-transcript <provider-session-id> --json`.
  Treat an unrefreshed status, an active retry, or a backlog older than five
  minutes as needing attention. Expire cursor and status files after 30 days
  of inactivity; no transcript payload enters operational diagnostics.

## Verification and open risk

Regression tests cover bounded reads, malformed lines, same-size replacement,
restart recovery, partial lines, failed PE appends, and incorrect provider
session association. Focused bmuxTests and project-doc gates pass locally;
tagged build and ordinary-Codex dogfood remain required.
The recovery scan is bounded in memory but linear in transcript length on a
process restart; measure restart and live lag during dogfood before treating the
five-minute threshold as met. The legacy historical importer still reads a
whole file for explicit one-off imports and is outside this live-tail slice.
The cursor source identity combines device, inode, and a prefix digest after
the file reaches 256 bytes. In-place same-size rewrites of files shorter than
256 bytes are not detectable; the exact provider session ID check still
prevents associating a different session. A file that disappears is retried
when the monitor next discovers it. The storage gate remains closed for
sustained ingestion until old app builds stop writing legacy outcome revisions
and PE live maintenance has a safe capacity path.
