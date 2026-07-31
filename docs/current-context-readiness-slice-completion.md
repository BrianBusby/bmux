# Current-Context Readiness Slice Completion

Branch: Slice E current-context readiness.

Milestone: Prepare `bmux provenance context current` for public Provenance Engine SDK adoption.

Contract assessment: A. Existing public contract is sufficient.

This document preserves the engine-side readiness evidence for migrating `bmux provenance context current` to `ProvenanceEngineClient.currentContext(...)`. It does not mark Slice E accepted. Acceptance requires the bmux repository to consume this readiness work and preserve bmux command behavior through the public SDK.

Historical status note: this file is preserved as the 2026-07-25 engine-side
readiness record. Slice E was later operationally accepted after bmux consumed
the ready contract and merged the runtime cutover at
`3cbacd1501768f79ea377eb2d6aea9113f199d1b`. The current gate is recorded in
`docs/current-status.md` and `docs/bmux-integration-roadmap.md`.

## Baseline Confirmation

Confirmed on 2026-07-25:

- Slice C session-tree adoption is accepted.
- Slice D file-explanation adoption is accepted.
- The pre-readiness local engine baseline is `30c9c867f7ffbe62562b41db2c9ad36a4500592a`.
- The existing public contract includes `ProvenanceCurrentContextRequest`, `ProvenanceCurrentContextResponse`, row DTOs for sessions, file changes, checkpoints, validation runs, and conflicts, plus `ProvenanceEngineClient.currentContext(...)`.
- No bmux files were modified.
- A pre-existing implementation exposure was tightened by changing `ProvenanceSQLiteClientFactory` from `public` to `package` access. The public SDK factory remains unchanged; downstream consumers should construct clients only through `ProvenanceEngineClientFactory`.

## Contract Result

The existing public contract is sufficient:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK

let client: any ProvenanceEngineClient = try ProvenanceEngineClientFactory()
    .sqliteClient(databaseURL: databaseURL)

let response = try await client.currentContext(
    ProvenanceCurrentContextRequest(
        repositoryPath: resolvedGitWorktreeRoot,
        activeSessionLimit: activeSessionLimit,
        dirtyFileLimit: dirtyFileLimit,
        unattributedChangeLimit: unattributedChangeLimit,
        recentCheckpointLimit: recentCheckpointLimit,
        validationRunLimit: validationRunLimit,
        conflictLimit: conflictLimit
    )
)
```

No new API was added. No existing public type was expanded. The contract can represent the current bmux command's domain needs without exposing SQLite details or bmux-specific presentation types.

The only source access change was implementation hardening: `ProvenanceSQLiteClientFactory` is now package-scoped. This preserves `ProvenanceEngineSDK` composition inside the package while preventing downstream packages from constructing the SQLite implementation factory directly.

## Current-Context Semantics

Public behavior:

- Repository lookup: the engine links the matched worktree to its repository projection when available. It does not discover repositories from `cwd`, call Git, or normalize repository roots.
- Worktree resolution: `repositoryPath` is the absolute Git worktree root path resolved by the consumer. If no worktree projection matches, the response is `found == false`, `reason == "no_worktree"`, and every section is empty.
- Empty context: a known worktree with no recorded context returns `found == true` with the worktree, repository if available, and empty section arrays.
- Section ordering: response fields are stable contract fields. Rows inside sections are returned in engine query order.
- Section limits: each request limit independently bounds one section. Negative limits are treated as zero by the SQLite-backed implementation.
- Active sessions: sessions in the matched worktree with non-terminal status are returned newest-updated first. Linked active contribution and work item data are included when present.
- Dirty files: the engine returns the newest file-change projection per path in the matched worktree. This is recorded provenance evidence, not a live filesystem scan.
- Unattributed files: the engine returns the newest per-path file changes whose attribution source is `unattributed`.
- Validation runs: linked validation runs are returned newest completion/start time first.
- Checkpoints: linked checkpoints are returned newest-created first.
- Conflicts: paths touched by more than one active contribution are returned with active contribution count, contribution ID list, and latest path update time.
- Deterministic ordering: active sessions, file rows, checkpoints, and validation runs include deterministic tie-breakers. Conflict rows are ordered by latest update time for the path.
- Response guarantees: `schemaVersion == 1`; arrays are always present; linked records are optional where evidence is partial or unattributed.

Out of scope for V1 current context:

- Live Git status, filesystem scanning, repository normalization, or `cwd` discovery.
- CLI default limit policy.
- Text rendering, JSON rendering, fallback strings, command parsing, and exit-code behavior.
- Semantic retrieval, prompt assembly, lifecycle policy, observability, daemon/service transport, storage migration, Knowledge Compiler behavior, rename-aware identity, or historical identity.

## SDK Readiness Tests

Added `Tests/ProvenanceEngineSDKTests/CurrentContextSDKTests.swift`.

The tests use only:

- `ProvenanceEngineClientFactory`
- `ProvenanceEngineClient.appendEvent(...)`
- `ProvenanceEngineClient.currentContext(...)`

The tests do not import `ProvenanceEngineSQLite`, seed SQLite tables, inspect table names, or recreate storage queries. Fixture data is appended as public `ProvenanceEvent` values, as a consumer would.

Coverage includes:

- Repository/worktree found response with linked repository data.
- Repository/worktree not found response with `no_worktree`.
- Known worktree with empty context.
- Independent section limits.
- Deterministic row ordering for sessions, files, checkpoints, and validation runs.
- Active session summaries with linked contribution and work item.
- Dirty file reporting.
- Unattributed work.
- Checkpoints.
- Validation runs.
- Conflict reporting for overlapping active contributions.
- Terminal session/contribution filtering from active sections while preserving historical file evidence in dirty-file rows.

## Boundary Review

Provenance Engine owns:

- Provenance-domain queries.
- Aggregation over current-state projections.
- Section ordering.
- Section limit application.
- Response construction with domain DTOs.

bmux continues to own:

- CLI arguments.
- Current-directory discovery.
- Git repository root resolution.
- Repository path normalization before request construction.
- Text rendering.
- JSON rendering and compatibility payloads.
- Default CLI limits.
- Fallback messaging and exit behavior.

No presentation logic migrated into Provenance Engine.

## bmux Adoption Handoff

Engine revision to consume: the eventual default-branch merge commit containing this Slice E readiness work, or any later revision. Do not pin the pre-readiness baseline `30c9c867f7ffbe62562b41db2c9ad36a4500592a` for Current Context adoption because it lacks the Slice E SDK tests and documentation.

Modules to import:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK
```

Public SDK calls:

```swift
let client: any ProvenanceEngineClient = try ProvenanceEngineClientFactory()
    .sqliteClient(databaseURL: databaseURL)
let response = try await client.currentContext(
    ProvenanceCurrentContextRequest(repositoryPath: resolvedGitWorktreeRoot)
)
```

bmux migration steps:

1. Update the bmux package pin to the Slice E readiness merge commit or later.
2. Keep existing bmux command parsing for `bmux provenance context current`.
3. Keep bmux-owned current directory and Git worktree root resolution.
4. Keep bmux-owned missing-database and missing-worktree fallback behavior.
5. Construct the engine client through `ProvenanceEngineClientFactory().sqliteClient(databaseURL:)`.
6. Pass the resolved Git worktree root to `ProvenanceCurrentContextRequest.repositoryPath`.
7. Pass bmux's existing default/user section limits into the request.
8. Map the domain response into the existing bmux JSON and text presentation payloads.
9. Preserve existing empty-section behavior in bmux rendering.
10. Replace current-context CLI tests that seed or inspect bmux-local SQLite internals with SDK-seeded fixtures where practical.
11. Remove current-context-only local SQL helpers once the migrated command is accepted.

Legacy code to remove after acceptance:

- bmux current-context-only direct SQLite query helpers.
- bmux duplicate current-context domain DTOs that simply mirror engine DTOs.
- Permanent dual-read paths for current context.
- Current-context fixture seeding that depends on bmux-local table knowledge when an SDK fixture can express the same evidence.

Validation plan for bmux:

- Run the existing current-context CLI tests before migration to lock compatibility expectations.
- Add or update SDK-seeded fixture tests for found, missing, empty, limits, dirty/unattributed files, validation runs, checkpoints, and conflicts.
- Run focused bmux current-context CLI tests.
- Confirm no current-context production path imports `ProvenanceEngineSQLite` or reads engine SQLite tables directly.
- Confirm text and JSON outputs remain stable, including fallback strings and empty sections.

Compatibility expectations:

- Engine response semantics, domain ordering, and section limits are stable V1 contract behavior.
- bmux output format, field names, fallback messages, and command defaults remain bmux-owned compatibility behavior.
- Missing worktree maps from engine `no_worktree` only after bmux has already handled any missing database or non-Git-directory cases.

Acceptance criteria:

- `bmux provenance context current` reads through `ProvenanceEngineClient.currentContext(...)`.
- bmux no longer uses bmux-local current-context SQL for this command path.
- Existing text, JSON, empty-section, limit, and fallback behavior is preserved.
- No file-explanation, lifecycle recording, capture, observability, projection migration, storage migration, daemon/service transport, semantic retrieval, Knowledge Compiler, rename-aware identity, historical identity, or V2 feature work is started.

## Architecture Review

1. Was the existing public contract sufficient? Yes. Classification A.
2. Did current-context reveal any API weaknesses? No blocking weakness. The request cleanly accepts a consumer-resolved worktree root and independent section limits, while the response exposes domain rows needed by bmux.
3. Was a new API avoided? Yes. No public surface changed.
4. Does the engine continue to own provenance-domain behavior? Yes. Queries, aggregation, ordering, limit application, and response construction stay in the engine.
5. Does bmux continue to own presentation? Yes. CLI parsing, Git/cwd handling, text/JSON formatting, defaults, and fallbacks remain bmux responsibilities.
6. Does the Reference Architecture change? No.
7. What risks remain before bmux adoption? bmux may have presentation compatibility hidden in its legacy SQL adapter; conflict contribution ID string ordering should be treated as an engine-provided domain value but not as user-facing formatting; missing database and non-Git cwd fallbacks must remain bmux-owned; current-context tests in bmux may need fixture migration away from direct table seeding.
8. Overall confidence: Architecture validated.

## Scope Exclusions

This slice did not implement bmux migration, lifecycle recording, capture migration, observability migration, projection migration, storage migration, daemon/service transport, semantic retrieval, Knowledge Compiler behavior, rename-aware identity, historical identity, or V2 features.

## Readiness Status

Historical readiness result: engine readiness was complete. At the time this
record was authored, bmux adoption and review had not happened yet.

## Validation Results

Validated on 2026-07-25:

- `swift build`: passed.
- `swift test --filter CurrentContextSDKTests`: 5 tests passed.
- `swift test`: 83 tests passed.
- `swift package describe --type json`: passed; public products remain `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.
- Public import validation: a temporary external package importing `ProvenanceEngineContracts` and `ProvenanceEngineSDK` built successfully.
- Implementation access validation: a temporary external package attempting to construct `ProvenanceSQLiteClientFactory` failed with `cannot find 'ProvenanceSQLiteClientFactory' in scope`.
- `git diff --check`: passed.
- Consumer-style SDK tests contain no `import ProvenanceEngineSQLite`.
