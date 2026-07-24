# bmux Provenance Integration

This document records bmux-local integration responsibilities. The canonical cross-repository bmux to provenance-engine integration roadmap lives in provenance-engine:

https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md

The provenance-engine integration contract remains the technical authority for public APIs:

https://github.com/BrianBusby/provenance-engine/blob/main/docs/integration-contract.md

## Repository Boundary

bmux owns the product workflow around provenance:

- command parsing and CLI/socket presentation
- JSON and text output compatibility
- user-facing fallback messages
- terminal, workspace, browser, notification, and UI behavior
- Codex and agent orchestration
- transcript and hook capture at the bmux boundary
- Git observation scheduling and duplicate-capture policy
- prompt/context assembly and user-facing reports

provenance-engine owns reusable provenance infrastructure:

- public event and evidence contracts
- durable event ledger and projections
- evidence persistence and storage integrity
- query and retrieval APIs
- SDK and future transport boundaries
- shared evidence-store architecture
- Knowledge Compiler artifacts
- versioning, release, and compatibility policy

## Current bmux-Owned Integration Work

Current active milestone: Slice D file-explanation read migration adoption review. Slice C session-tree read migration is accepted with an explicit GitHub Actions waiver for bmux PR 7.

Slice D migrates only `bmux provenance explain <path>` to the external SQLite-backed provenance-engine client, preserves existing presentation and fallback behavior, uses public engine APIs for file-explanation fixture setup, and removes only file-explanation-specific legacy code that became unused. The engine readiness dependency is PR 5 at exact revision `384026e36087dda576e25343907c3e06d8a4d594`; that PR is still open/draft and Slice D is not accepted until both repositories complete review.

The completed first adoption path is `bmux provenance worktrees list`. It reads through provenance-engine `0.1.0` while bmux continues to own CLI output compatibility.

The completed second adoption path is `bmux provenance sessions tree <session-id>`. It reads through provenance-engine revision `2026914454a00ccc6c45d686ea741111b0a01229` while bmux continues to own CLI output compatibility. The engine limit is a combined session-plus-relationship row budget; bmux adapts it at the CLI boundary to preserve the legacy 100-session presentation cap.

The Slice D adoption branch adds the third adoption path, `bmux provenance explain <path>`. bmux still resolves the Git worktree and repository-relative path, then resolves the engine worktree through `ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())` and calls `ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest(...))`.

## Local Operational Notes

- The live handoff index remains `docs/context-efficiency/current-status.md`.
- The local adoption inventory remains `docs/context-efficiency/integration/provenance-engine-adoption.md`.
- The detailed Phase 4 reconnect plan remains `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

Do not begin current context, lifecycle writes, capture append migration, storage migration, daemon transport, retrieval, UI work, GitHub ingestion, or Knowledge Compiler implementation.

Do not mark Slice D accepted until Provenance Engine PR 5 and the bmux adoption PR are accepted.

Avoid permanent dual reads.
