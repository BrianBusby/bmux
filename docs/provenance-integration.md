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

Current active milestone: Slice C acceptance gate. Slice C session-tree read
migration is locally validated and ready for bmux PR acceptance, but not fully
accepted until bmux PR checks and merge complete.

Slice C migrated only the provenance session-tree CLI command to the external SQLite-backed provenance-engine client, preserved existing presentation and fallback behavior, used public engine APIs for fixture setup, and removed only session-tree-specific legacy code that became unused.

The completed first adoption path is `bmux provenance worktrees list`. It reads through provenance-engine `0.1.0` while bmux continues to own CLI output compatibility.

The completed second adoption path is `bmux provenance sessions tree <session-id>`. It reads through provenance-engine revision `2026914454a00ccc6c45d686ea741111b0a01229` while bmux continues to own CLI output compatibility. The engine limit is a combined session-plus-relationship row budget; bmux adapts it at the CLI boundary to preserve the legacy 100-session presentation cap.

## Local Operational Notes

- The live handoff index remains `docs/context-efficiency/current-status.md`.
- The local adoption inventory remains `docs/context-efficiency/integration/provenance-engine-adoption.md`.
- The detailed Phase 4 reconnect plan remains `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

Do not begin current context, lifecycle writes, capture append migration, storage migration, daemon transport, retrieval, UI work, GitHub ingestion, or Knowledge Compiler implementation.

File explanations may begin only after the Slice C acceptance gate closes, in a
new focused Slice D branch or session.

Avoid permanent dual reads.
