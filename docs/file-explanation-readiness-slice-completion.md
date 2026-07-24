# File-Explanation Readiness Slice Completion

Branch: `slice-d-file-explanation-readiness`

Milestone: Slice D file-explanation read migration readiness.

Contract assessment: A. Existing contract is sufficient.

This document preserves the engine-side readiness evidence for migrating `bmux provenance explain <path>` to the public Provenance Engine SDK. The actual bmux command migration in PR 9 validated the engine contract without requiring a new public API or storage-boundary exception. bmux PR 9 has merged, the temporary dependency pin was removed, and Slice D is fully accepted.

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

## Real bmux Adoption Evidence

Reviewed bmux PR 9 on 2026-07-24. Final accepted bmux PR head:
`ea72bfd7dc28cd60b093b5a4d0bebc5853c32f59`; merge commit:
`c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` at 2026-07-24T21:54:46Z.

The migrated command uses only the public engine SDK surface:

```swift
let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
    try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
let worktrees = try await client.worktrees(ProvenanceWorktreeListRequest())
let response = try await client.fileExplanation(
    ProvenanceFileExplanationRequest(worktreeID: worktreeEntry.worktree.id, path: target.relativePath)
)
```

The adoption removed the file-explanation-only local SQL reader path, local
request/response DTOs, local domain explanation DTO, legacy client method,
store method, and direct-storage file-explanation fixture seeding. The migrated
path imports `ProvenanceEngineContracts` and `ProvenanceEngineSDK`; no engine
storage module, SQLite table knowledge, or local recreation of the engine query
was required.

The public worktree-list response contains enough stable information for bmux's
current lookup. bmux resolves the Git repository root, lists public worktree
entries, and selects the entry whose public worktree `path` equals the resolved
repository root. This is a small public-contract selection step, not an engine
contract defect.

Adoption finding classification:

- Bmux concern: argument parsing, Git probing, path normalization from user
  input, outside-worktree rejection, fallback messages, exit behavior, JSON/text
  rendering, and fixture setup.
- Provenance Engine contract concern: none found for V1.
- Future architecture concern: rename-aware identity, deleted-file history
  beyond recorded deletion-like file changes, historical path identity,
  case-insensitive matching, symlink identity, semantic explanations, and
  compiled explanations.

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

Required engine revision consumed by bmux: merged Provenance Engine default-branch revision `126afde36671f53a137953200e7883e6b4093ac3`, or any later revision. bmux removed the temporary feature-branch commit `384026e36087dda576e25343907c3e06d8a4d594` from all dependency declarations and lockfiles.

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

After engine acceptance, bmux repinned all required locations:

- `bmux.xcodeproj/project.pbxproj`;
- `bmux.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`;
- `tests/test_provenance_cli.py` dynamic seeder fallback;
- `tests/fixtures/provenance-engine-file-explanation-seeder/Package.swift`;
- `tests/fixtures/provenance-engine-file-explanation-seeder/Package.resolved`;
- `tests/fixtures/provenance-engine-session-tree-seeder/Package.swift`;
- `tests/fixtures/provenance-engine-session-tree-seeder/Package.resolved`.

No bmux API migration changes were required by the engine review.

## Architecture Review

1. Did real consumer adoption validate the documented contract? Yes. bmux PR 9 migrated `provenance explain <path>` through the documented factory, worktree-list, and file-explanation contracts.
2. Was a new public API avoided appropriately? Yes. The small public worktree-list selection step was sufficient and did not justify a specialized lookup API.
3. Did any engine implementation detail leak to bmux? No. The migrated path did not import ProvenanceEngineSQLite, query SQLite directly, read table names, or recreate the engine query.
4. Is worktree/path identity represented at the correct layer? Yes. bmux owns Git-root discovery, user-path handling, repository-relative normalization, outside-worktree rejection, and user-facing fallback behavior. Provenance Engine owns exact path lookup within the selected worktree, newest-current-state evidence selection, and domain response construction.
5. Did the worktree-list contract create meaningful friction? No. The public `ProvenanceWorktreeListEntry` exposes worktree path and repository data needed for bmux's current exact-root selection.
6. Does the Reference Architecture require an update? No. The adoption validates the existing architecture; it does not add a new architectural requirement.
7. What consumer capability is now enabled? Consumers can explain a repository-relative file through public engine SDK contracts and render attributed or unattributed evidence without storage access.
8. What future architecture concerns remain intentionally deferred? Rename-aware identity, deleted-file history, historical path identity, case-insensitive matching, symlink identity, semantic explanations, compiled explanations, daemon/service transport, and shared evidence ingestion remain outside Slice D.
9. What technical debt remains? Later slices still need to migrate current-context, lifecycle/capture, projection storage, and observability paths; GitHub Actions/Blacksmith runner scheduling remains bmux infrastructure debt.
10. Overall confidence: Architecture validated.

## Scope Exclusions

This slice did not implement Knowledge Compiler behavior, semantic retrieval, embeddings, AI-generated explanations, organization-wide evidence search, generalized natural-language queries, historical rename tracking, daemon/service migration, authorization redesign, or bmux command migration.


## Final Slice D Acceptance

Slice D is fully accepted. Engine readiness merged in Provenance Engine PR 5 at
`126afde36671f53a137953200e7883e6b4093ac3`, bmux adoption merged in bmux PR 9
at `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374`, and bmux removed the temporary
feature-branch engine dependency pin everywhere. The next migration slice may
now be selected, but this document does not activate a specific next slice.
