# File-Explanation Readiness Slice Completion

Branch: `slice-d-file-explanation-readiness`

Milestone: Slice D file-explanation read migration readiness.

Contract assessment: A. Existing contract is sufficient.

This document preserves the engine-side readiness evidence for migrating `bmux provenance explain <path>` to the public Provenance Engine SDK. The actual bmux command migration remains a follow-up consumer adoption slice.

## Baseline Confirmation

Confirmed on 2026-07-24:

- Provenance Engine `origin/main` is `4bf515ecc7c2a174351fc9458f4c1c61df677c03`.
- Provenance Engine contains Slice C readiness merge `2026914454a00ccc6c45d686ea741111b0a01229` and acceptance documentation merge `4bf515ecc7c2a174351fc9458f4c1c61df677c03`.
- bmux `origin/main` is `2f16abb2d7bca69c2e83c79377f521cc22db6893` and contains Slice C adoption merge `08763dd0d3256989180dcc04f426da1f24369175` from PR 7.
- `docs/current-status.md` and `docs/bmux-integration-roadmap.md` mark Slice C accepted and Slice D file-explanation read migration as the active milestone.
- bmux Issue 8 remains a separate GitHub Actions scheduling issue and is outside this slice.

## Existing bmux Behavior

Inspection target: current bmux `origin/main` after PR 7.

1. Command parsing: `BMUXCLI.runProvenanceCommand` dispatches `provenance explain`; `runProvenanceExplain` accepts exactly one `<path>`, optional global `--json`, and optional `--database <path>`. Unknown flags and extra arguments are CLI errors.
2. Path normalization: `CLIProvenanceGitResolver` trims the requested path, resolves relative paths against the current directory, standardizes the file URL, and converts the result to a repository-relative path. The resolved relative path is sent to the read contract.
3. Git worktree resolution: bmux shells out to `/usr/bin/git -C <probe-directory> rev-parse --show-toplevel`. Missing or outside-worktree paths fail before storage is queried.
4. Existing request construction: after resolving the worktree row by repository root path, bmux calls `fileExplanation(worktreeID:path:)` with the worktree ID and repository-relative path.
5. Storage access: the file-explanation command still opens `WorkProvenanceStore`, reads worktree/repository helpers, and calls `BmuxLegacyProvenanceClient.fileExplanation`. Older `CLIProvenanceSQLiteReader` also contains direct SQL for the same behavior.
6. Evidence lookup behavior: the query matches exact `worktree_id` plus exact `path` from file-change projections.
7. Ordering: when multiple file-change rows match, bmux returns the newest by `updated_at DESC, rowid DESC`.
8. Limit behavior: the command returns one focused explanation. There is no user-facing or request-level list limit.
9. Text rendering: bmux renders header, status, attribution, observed timestamp, change-set summary, diff fingerprint, contribution, intent, session, work item, branch, repository, and an unattributed note when relevant.
10. JSON rendering: bmux emits a presentation payload with `found`, requested/repository/relative paths, reason, file status, attribution fields, timestamp, worktree, repository, and optional linked records.
11. Error handling: missing path, unknown flags, extra arguments, non-Git worktree, and path outside worktree are CLI errors. Missing database, missing worktree, and missing file are bounded not-found outputs.
12. Repository handling: bmux resolves the repository root path first, finds a recorded worktree by that path, and uses the worktree repository ID for fallback repository payloads.
13. Fallback behavior: missing database returns `no provenance database exists yet`; missing worktree returns `no provenance has been recorded for this Git worktree`; missing file returns `no file-level provenance has been recorded for this path`.
14. Existing tests: `tests/test_provenance_cli.py` seeds the old bmux-local SQLite schema directly for file-explanation tests and asserts JSON/text/fallback behavior. Session-tree tests already seed through a Provenance Engine SDK fixture.
15. Accidental vs contractual behavior: command parsing, Git resolution, fallback strings, and presentation payload keys are bmux-owned compatibility. Exact worktree ID plus normalized repository-relative path, newest matching file-change selection, linked domain records, `found`, and `no_file` are engine contract behavior.

## Contract Result

The existing public contract is sufficient:

```swift
let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
let response = try await client.fileExplanation(
    ProvenanceFileExplanationRequest(worktreeID: worktree.id, path: relativePath)
)
```

No new API was added. The current `ProvenanceFileExplanationRequest`, `ProvenanceFileExplanationResponse`, `ProvenanceFileExplanation`, and linked record DTOs can represent the existing bmux behavior without exposing storage internals or bmux-specific naming.

## V1 Path Identity

Supported V1 semantics:

- `worktreeID` is the primary worktree identity and scopes the file lookup.
- `path` is a normalized repository-relative path string matching `ProvenanceFileChangeRecord.path` exactly.
- Relative and absolute user input paths are consumer concerns. Consumers should resolve Git root and normalize to repository-relative path before calling the engine.
- Repository identity is returned through linked worktree and repository records when projections exist. The lookup itself is worktree-scoped.
- Multiple worktrees can contain the same repository-relative path; the requested worktree ID chooses the result.
- Deleted files are supported only as recorded file-change rows with a deletion-like `status` and matching path.

Outside V1:

- Historical rename tracking, moved-file identity, copies, and case-only rename reconciliation.
- Symlink target resolution or canonicalization.
- Filesystem existence checks.
- Case folding or platform-specific path equivalence.
- Repository-root discovery, Git worktree resolution, or absolute-path conversion inside the engine.
- Historical identity across repository moves or multiple checked-out paths beyond the explicit worktree ID supplied by the consumer.

## SDK Readiness Tests

Added `Tests/ProvenanceEngineSDKTests/ProvenanceEngineFileExplanationSDKTests.swift`.

The tests use `ProvenanceEngineClientFactory`, seed only with public `appendEvent`, query only with `fileExplanation`, and do not import `ProvenanceEngineSQLite` or inspect SQLite tables.

Coverage includes successful explanation, missing file, normalized path handling at the consumer boundary, newest matching evidence, attributed evidence, unattributed evidence, single-result limit semantics, and worktree/repository identity for the same repository-relative path.

## bmux Adoption Handoff

Required engine revision: use the merged Provenance Engine revision containing this document and `ProvenanceEngineFileExplanationSDKTests`, or any later revision. During review, use branch `slice-d-file-explanation-readiness`.

Modules to import:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK
```

Client construction:

```swift
let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
    try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
```

Request type: `ProvenanceFileExplanationRequest`.

Response type: `ProvenanceFileExplanationResponse`.

Response semantics:

- `found == true` means `explanation` contains the newest file-change explanation for the requested worktree and path.
- `found == false`, `reason == "no_file"`, and `explanation == nil` means no matching file-change projection exists.
- Linked records are optional because producers may append unattributed or partially linked evidence.

Path normalization expectations:

- Keep `CLIProvenanceGitResolver` or equivalent bmux-owned logic.
- Pass the resolved worktree ID and normalized repository-relative path into the engine.
- Do not pass raw absolute paths or user-entered relative paths directly unless already normalized to repository-relative form.

Ordering semantics: the engine returns the newest exact match by `updatedAt` descending with deterministic append-storage insertion order as a tie-breaker.

Limit semantics: no request limit exists; the V1 response is one explanation.

Error semantics:

- Missing database remains a bmux fallback before client construction.
- Missing worktree remains a bmux fallback, normally by resolving worktrees through the public `worktrees` contract or a transitional helper during migration.
- Missing file maps from engine `no_file` to the existing bmux fallback string.
- Storage open/query failures remain thrown errors and should preserve existing CLI error handling.

Prohibited dependencies:

- Do not import `ProvenanceEngineSQLite` from bmux.
- Do not read engine SQLite tables directly.
- Do not keep a permanent dual-read implementation after migration acceptance.

Compatibility expectations:

- bmux owns text and JSON output compatibility.
- bmux should preserve existing fallback strings and payload keys.
- The engine owns DTO semantics and exact-match newest-file lookup behavior.

Known limitations:

- No semantic explanation generation, retrieval, embeddings, Knowledge Compiler, or organization-wide evidence search.
- No rename-aware path identity.
- No engine-side Git path resolution.
- No daemon/service transport change.

Exact migration steps:

1. Update bmux's provenance-engine package pin to the required engine revision.
2. In `runProvenanceExplain`, construct the engine client through `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)` after the existing missing-database fallback.
3. Keep bmux Git target resolution and repository-relative path normalization unchanged.
4. Resolve the worktree without importing or querying engine SQLite internals. Prefer the public `worktrees(ProvenanceWorktreeListRequest())` contract and select the current repository path at the bmux boundary.
5. Call `client.fileExplanation(ProvenanceFileExplanationRequest(worktreeID:path:))`.
6. Map `ProvenanceFileExplanationResponse` into the existing `CLIProvenanceExplanation` presentation payload.
7. Preserve `no_database`, `no_worktree`, and `no_file` fallback rendering.
8. Replace file-explanation CLI tests that seed direct bmux-local SQLite with SDK-seeded fixtures, matching the Slice C session-tree pattern.
9. Remove file-explanation-only local query helpers after the migrated command is accepted.
10. Confirm no bmux file-explanation path imports `ProvenanceEngineSQLite` or reads storage tables directly.

## Architecture Review

1. Did this reinforce the Reference Architecture? Yes. The slice kept Provenance Engine responsible for reusable contracts and private storage-backed projections while leaving bmux responsible for CLI behavior, Git resolution, fallback text, and rendering.
2. Did the public API feel sufficient? Yes. `fileExplanation(worktreeID:path:)` represented the current consumer read path without extension.
3. Did implementation require storage knowledge? No for the SDK tests and adopter contract. Storage inspection was used only to compare current bmux behavior and confirm existing engine behavior, not as a consumer dependency.
4. Is path identity represented at the correct architectural layer? Yes for V1. bmux owns user path and Git worktree resolution; the engine owns exact worktree-scoped repository-relative file identity.
5. Should the Reference Architecture change? No. This is validation evidence, not a new architectural requirement.
6. What can consumers now do? Consumers can seed file-change evidence through public events and read focused file explanations through the public SDK without importing SQLite internals.
7. What technical debt was introduced? No intentional code debt. Documentation now records V1 exact-path limitations; future rename-aware identity remains explicit debt outside this slice.
8. What future opportunities emerged? Current-context migration can reuse the same path-identity boundary. A future versioned path-identity contract may be warranted after real rename or historical lookup requirements appear.
9. Overall confidence: Architecture validated.

## Scope Exclusions

This slice did not implement Knowledge Compiler behavior, semantic retrieval, embeddings, AI-generated explanations, organization-wide evidence search, generalized natural-language queries, historical rename tracking, daemon/service migration, authorization redesign, or bmux command migration.
