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
Execution telemetry status and policy live in `docs/execution-telemetry/`.

## Implemented Capabilities

- Native macOS app with Ghostty terminal rendering, vertical workspace tabs, split panes, browser panes, CLI/socket automation, and custom configuration.
- Agent-aware workspace state including notifications, busy/idle detection, unread routing, command/browser automation, and short refs for windows, workspaces, panes, and surfaces.
- Context-efficiency telemetry package and CLI surfaces for read-only Codex rollout inspection.
- Local WorkProvenance capture, projections, lifecycle relationship recording, and provenance CLI presentation for legacy support and observability traces.
- Provenance Engine V1 read adoption for `bmux provenance worktrees list`, `bmux provenance sessions tree <session-id>`, `bmux provenance explain <path>`, and `bmux provenance context current`.
- Slice E operational Provenance Engine V1 runtime cutover: default production storage now resolves to the engine-owned store, lifecycle recording and worktree observation write through public SDK APIs, and incompatible stores are rejected by engine schema identity checks.
- Transitional legacy boundary clarified as `BmuxLegacyProvenanceClient` for remaining bmux-local support paths. New provenance consumer behavior should use `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.

## Active Work

Active gate: Engineering Observation Period after Slice E.

Slice E is complete with named caveats: bmux is operationally integrated with
Provenance Engine V1 for adopted read and write paths. Production defaults now
open the canonical engine-owned SQLite store at
`~/.local/state/provenance-engine/provenance.sqlite`; the old bmux-local
database remains intact and is no longer the default V1 store.

bmux continues to own workflow capture, Git path normalization, fallback
behavior, CLI/socket presentation, and runtime policy. Provenance Engine owns
durable evidence, schema compatibility, deterministic Current State, and
bounded provenance queries.

Named caveats: `bmux provenance traces lifecycle-ingestion` still reads
bmux-local observability SQLite because V1 has no public observability trace
API, and opening an agent-session surface alone does not create lifecycle
evidence unless supported hooks/feed events reach bmux.

GitHub Actions waivers for Slice C and Slice D: bmux PR 7 and PR 9 Actions remained unavailable as acceptance evidence. No failing CI result was observed, branch protection did not require checks, and the runner scheduling issue remains tracked in bmux issue 8. Slice E validation is recorded in `docs/context-efficiency/current-status.md`.

Still out of scope until a new slice is explicitly selected: daemon transport, UI work, observability API expansion, GitHub ingestion, Knowledge Compiler implementation, semantic retrieval, broad legacy data migration, and lifecycle policy automation.

## Near-Term Planned Work

- Run an Engineering Observation Period against the Slice E runtime cutover.
- Remove or retire legacy WorkProvenance storage and client support after replacement contracts or obsolescence decisions.
- Decide whether lifecycle observability traces need a public engine API or should remain bmux-local diagnostics.
- Cut a tagged Provenance Engine release so bmux can depend on a version tag rather than a revision pin.

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
