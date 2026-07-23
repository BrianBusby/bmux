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

Current active milestone: Slice C, session-tree read migration.

bmux should migrate only the provenance session-tree CLI command to the external SQLite-backed provenance-engine client, preserve existing presentation and fallback behavior, use public engine APIs for fixture setup, and remove only session-tree-specific legacy code that becomes unused.

The completed first adoption path is `bmux provenance worktrees list`. It reads through provenance-engine `0.1.0` while bmux continues to own CLI output compatibility.

## Local Operational Notes

- The live handoff index remains `docs/context-efficiency/current-status.md`.
- The local adoption inventory remains `docs/context-efficiency/integration/provenance-engine-adoption.md`.
- The detailed Phase 4 reconnect plan remains `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`.

Do not begin file explanations, current context, lifecycle writes, capture append migration, storage migration, daemon transport, retrieval, UI work, GitHub ingestion, or Knowledge Compiler implementation.

Wait until the current shared milestone is accepted.

Avoid permanent dual reads.
