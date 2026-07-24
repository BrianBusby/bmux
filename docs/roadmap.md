# bmux Roadmap

This is the authoritative roadmap for the bmux repository. bmux owns the terminal product, workspace experience, Codex and agent orchestration, UI, notifications, mobile and remote-session workflows, CLI/socket presentation, capture adapters, prompt/context assembly, distribution, and downstream cmux maintenance.

Do not treat `README.md`, `TODO.md`, or the detailed design files under `docs/context-efficiency/` as the project roadmap. They remain useful product notes, backlog, and design history.

## What bmux Is

bmux is a public macOS terminal and agent-workspace product descended from cmux. It combines Ghostty-backed terminals, split panes, workspaces, browser panes, notifications, CLI/socket automation, and agent-aware session workflows for running many coding-agent sessions side by side.

## Ownership Boundary

bmux owns:

- terminal, pane, workspace, browser, notification, and navigation behavior
- Codex session orchestration, subsessions, lifecycle hooks, and local runtime policy
- transcript capture and provenance event production at the bmux boundary
- CLI/socket command parsing, fallback text, JSON/text compatibility, and user-facing reports
- context assembly, prompt handoff workflows, and provenance-powered bmux features
- mobile and remote-session interaction
- distribution, release strategy, upstream cmux integration, and bmux-specific cleanup

provenance-engine owns reusable provenance contracts, durable evidence storage, query DTOs, SDK/transport boundaries, shared evidence, retrieval APIs, Knowledge Compiler artifacts, versioning, and storage compatibility. Cross-repository milestones are canonical in the provenance-engine shared roadmap:

https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md

Local bmux integration notes live in `docs/provenance-integration.md`.

## Implemented Capabilities

- Native macOS app with Ghostty terminal rendering, vertical workspace tabs, split panes, browser panes, CLI/socket automation, and custom configuration.
- Agent-aware workspace state including notifications, busy/idle detection, unread routing, command/browser automation, and short refs for windows, workspaces, panes, and surfaces.
- Context-efficiency telemetry package and CLI surfaces for read-only Codex rollout inspection.
- Local WorkProvenance capture, projections, lifecycle relationship recording, and provenance CLI presentation.
- First external provenance-engine adoption path: `bmux provenance worktrees list` now reads through provenance-engine `0.1.0`.
- Second external provenance-engine adoption path: `bmux provenance sessions tree <session-id>` now reads through `ProvenanceEngineClient.sessionTree(...)` at engine revision `2026914454a00ccc6c45d686ea741111b0a01229`.
- Transitional legacy boundary clarified as `BmuxLegacyProvenanceClient` for remaining bmux-local provenance paths.

## Active Work

Active gate: Slice D file-explanation read migration.

Accepted Slice C scope: migrated only the provenance session-tree CLI command to the external SQLite-backed provenance-engine client.

Preserved existing JSON, text, missing-database, no-session, and bounds behavior.

Session-tree CLI fixture setup now uses public provenance-engine APIs.

Removed only session-tree legacy code that became unused.

GitHub Actions waiver for Slice C: bmux PR 7 Actions remained unavailable
because PR-event runs produced zero jobs/check runs and manual workflow runs
queued without assignment to `blacksmith-4vcpu-ubuntu-2404`. No failing CI result
was observed, and branch protection did not require those checks. The waiver is
limited to Slice C and does not remove CI expectations for later work.

Out of scope for Slice D: current context, lifecycle writes, worktree
observation capture, storage migration, daemon transport, UI work, observability
expansion, GitHub ingestion, and Knowledge Compiler implementation.

## Near-Term Planned Work

- Produce the integration findings report after each accepted migration slice.
- Choose the next single bmux provenance path from the completed findings rather than opening parallel paths.
- Continue the provenance read migration in the current order: file explanations, then current context.
- Reconnect lifecycle writes only after durable read paths prove contract compatibility.
- Reconnect capture append paths while keeping Git observation policy and runtime degradation in bmux.
- Remove migrated bmux-local provenance query code slice by slice.

## Longer-Term Direction

- Provenance-powered bmux context assembly and task handoff features after durable evidence queries are proven.
- Session awareness across related workspaces and subsessions.
- User-facing reports that explain current session, task, and artifact state without exposing engine internals.
- Mobile and remote-session workflows that preserve bmux orchestration and UI ownership.
- Model and capacity management for long-running agent work.
- Distribution and release strategy for public bmux builds.
- Ongoing downstream cmux integration where it fits bmux product goals.

## Deferred or Exploratory Work

- Daemon or service transport for provenance-engine.
- Storage ownership migration out of bmux-local provenance SQLite.
- Evidence-backed retrieval adoption from shared project or organization evidence.
- GitHub ingestion and Knowledge Compiler features.
- Broad lifecycle policy automation, warnings, or automatic context mutation.
- Organization-scale provenance deployment.

These ideas should remain gated by the shared integration roadmap and by explicit findings from prior slices.

## Detailed Design Documents

- Current bmux provenance integration state: `docs/provenance-integration.md`
- Context-efficiency live handoff index: `docs/context-efficiency/current-status.md`
- Original context-efficiency roadmap and durable project memory: `docs/context-efficiency/roadmap.md`
- Implementation milestone history: `docs/context-efficiency/milestones.md`
- Provenance extraction ADR: `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
- Phase 4 reconnect details: `docs/context-efficiency/provenance-engine-phase4-reconnect-plan.md`
- Local adoption inventory: `docs/context-efficiency/integration/provenance-engine-adoption.md`
- Browser automation plan: `docs/agent-browser-port-spec.md`
- Remote daemon plan: `docs/remote-daemon-spec.md`
- iOS/mobile plans: `docs/ios-swift-mobile-plan.md` and `plans/`
- Backlog and historical project log: `TODO.md` and `PROJECTS.md`

## Superseded Planning Notes

The context-efficiency and provenance extraction documents remain valuable detailed design and history. They are no longer the canonical product roadmap for bmux as a whole, and they should not duplicate the shared bmux to provenance-engine integration roadmap.
