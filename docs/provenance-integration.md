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

Current active milestone: none selected after Slice D acceptance. Slice C session-tree read migration and Slice D file-explanation read migration are accepted with explicit GitHub Actions waivers for bmux PR 7 and PR 9.

Slice D migrated only `bmux provenance explain <path>` to the external SQLite-backed provenance-engine client, preserved existing presentation and fallback behavior, used public engine APIs for file-explanation fixture setup, and removed only file-explanation-specific legacy code that became unused. The final engine dependency is merged revision `126afde36671f53a137953200e7883e6b4093ac3`; bmux PR 9 merged at `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` on 2026-07-24T21:54:46Z.

The completed first adoption path is `bmux provenance worktrees list`. It reads through provenance-engine `0.1.0` while bmux continues to own CLI output compatibility.

The completed second adoption path is `bmux provenance sessions tree <session-id>`. It reads through provenance-engine revision `2026914454a00ccc6c45d686ea741111b0a01229` while bmux continues to own CLI output compatibility. The engine limit is a combined session-plus-relationship row budget; bmux adapts it at the CLI boundary to preserve the legacy 100-session presentation cap.

Slice D added the third adoption path, `bmux provenance explain <path>`. bmux still resolves the Git worktree and repository-relative path, then resolves the engine worktree through `ProvenanceEngineClient.worktrees(ProvenanceWorktreeListRequest())` and calls `ProvenanceEngineClient.fileExplanation(ProvenanceFileExplanationRequest(...))`.

## Local Operational Notes

- The live handoff index remains `docs/context-efficiency/current-status.md`.
- The local adoption inventory remains `docs/context-efficiency/integration/provenance-engine-adoption.md`.
- The detailed Phase 4 reconnect plan remains `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

Do not begin current context, lifecycle writes, capture append migration, storage migration, daemon transport, retrieval, UI work, GitHub ingestion, or Knowledge Compiler implementation.

Slice D is accepted. Do not begin the next migration slice until it is explicitly selected.

Avoid permanent dual reads.
