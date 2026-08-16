# bmux Roadmap

This is the authoritative roadmap for the bmux repository. bmux owns the terminal product, workspace experience, Codex and agent orchestration, UI, notifications, mobile and remote-session workflows, CLI/socket presentation, capture adapters, prompt/context assembly, distribution, and downstream cmux maintenance.

Do not treat `README.md`, `TODO.md`, or the detailed design files under `docs/context-efficiency/` as the project roadmap. They remain useful product notes, backlog, and design history.

## What bmux Is

bmux is a public macOS terminal and agent-workspace product descended from cmux. It combines Ghostty-backed terminals, split panes, workspaces, browser panes, notifications, CLI/socket automation, and agent-aware session workflows for running many coding-agent sessions side by side.

## Ownership Boundary

The authoritative generated ownership boundary is
`docs/generated/ownership-boundary.md`.

Local bmux integration notes live in `docs/provenance-integration.md`.

## Implemented Capabilities

- Native macOS app with Ghostty terminal rendering, vertical workspace tabs, split panes, browser panes, CLI/socket automation, and custom configuration.
- Agent-aware workspace state including notifications, busy/idle detection, unread routing, command/browser automation, and short refs for windows, workspaces, panes, and surfaces.
- Context-efficiency telemetry package and CLI surfaces for read-only Codex rollout inspection.
- Local WorkProvenance capture, projections, lifecycle relationship recording, and provenance CLI presentation for legacy support and observability traces.
- Provenance Engine V1 integration through public SDK boundaries for adopted
  provenance read and write paths. Current milestone state is generated in
  `docs/generated/project-status.md`.
- Workspace Display Durable Context integration that writes accepted display
  facts to Provenance Engine and renders built-in workspace rows from PE
  Workspace Display Current State when populated.
- Transitional legacy boundary clarified as `BmuxLegacyProvenanceClient` for
  remaining bmux-local support paths. New provenance consumer behavior should
  use `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.

## Active Work

The authoritative generated status is:

- [Project status](generated/project-status.md)
- [Ownership boundary](generated/ownership-boundary.md)
- [Repository status](generated/repository-status.md)

This roadmap defines bmux product direction and sequencing. It must not
independently maintain active gates, milestone state, evidence commits, current
implementation slices, dependency-ready work, selected-next work, release
state, or open caveat status.

Use the generated nested roadmap for dependency-ready, selected-next, and
active branch/worktree state. This authored roadmap records durable product
scope: daemon transport, observability API expansion, GitHub ingestion,
Knowledge Compiler implementation, semantic retrieval, broad legacy data
migration, and lifecycle policy automation require explicit roadmap slices
before bmux should pursue them.

## Near-Term Planned Work

- Run an observation period against the accepted runtime cutover.
- Remove or retire legacy WorkProvenance storage and client support after replacement contracts or obsolescence decisions.
- Decide whether lifecycle observability traces need a public engine API or should remain bmux-local diagnostics.
- Continue the richer coding-agent evidence and `SessionWorkModel` sequence with
  PE: bmux should keep provider acquisition, live interaction, approvals,
  streaming deltas, and rendering, while forwarding selected completed evidence
  units to PE through explicit contracts.
- Cut a tagged Provenance Engine release so bmux can depend on a version tag rather than a revision pin.

## Longer-Term Direction

- Provenance-powered bmux context assembly and task handoff features after durable evidence queries are proven.
- Human-readable live coding-agent work views powered by PE
  `SessionWorkModel` snapshots, including thread/turn intent, milestone
  hierarchy, current activity, scoped architecture, risk/validation state, and
  provenance for inferred fields.
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
- Raw execution-telemetry persistence or whole-stream PE ingestion.
- Broad lifecycle policy automation, warnings, or automatic context mutation.
- Broad workspace UI rewrite or automatic workspace naming redesign beyond the
  deterministic display-fact projection slice.
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
