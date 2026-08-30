# Bmux Context Efficiency: Current Status

This file is the live handoff index for context-efficiency, provenance, and
handoff work. Volatile project-state facts are generated from manifests and must
not be maintained here.

## Current Generated Truth

- [Project status](../generated/project-status.md)
- [Ownership boundary](../generated/ownership-boundary.md)
- [Repository status](../generated/repository-status.md)

Update `project/repo-status.yaml` for monorepo-local slice, release, capability,
or caveat changes. Shared milestone, gate, ownership, roadmap, and policy
changes belong in root `project/project-state.yaml`. The old
`project/shared-project-source.yaml` pointer is obsolete.

## Read Order

1. `AGENTS.md`
2. `docs/README.md`
3. `docs/generated/project-status.md`
4. `docs/generated/ownership-boundary.md`
5. `docs/generated/repository-status.md`
6. `docs/architecture/README.md`
7. `docs/architecture/system-overview.md`
8. `docs/architecture/implementation-map.md`
9. `docs/product/coding-session-views.md`
10. `docs/planning/monorepo-migration-ledger.md`
11. `docs/roadmap.md`
12. `docs/provenance-integration.md`
13. `docs/context-efficiency/roadmap.md`
14. `docs/context-efficiency/milestones.md`
15. `docs/context-efficiency/adr-001-provenance-engine-extraction.md`
16. Relevant bmux skills for Swift/package/build/test/localization work.

## Current Boundary

Do not add new provenance consumer behavior to bmux-local direct SQLite readers,
`WorkProvenanceStore`, or `BmuxLegacyProvenanceClient`. Those remain only for
legacy support, tests, and lifecycle trace presentation until a separate cleanup
slice removes or replaces them.

Execution telemetry remains bmux-owned high-frequency runtime state. Provenance
Engine receives only explicitly approved durable engineering evidence through
the public SDK. The accepted next direction is more precise: raw provider
streams and deltas stay live/ephemeral in bmux, while selected completed or
meaningful evidence units may become durable PE evidence once explicit
contracts, retention policy, and privacy review exist.

Live Terminal Codex Evidence Ingestion and Coding-Agent Evidence Source
Reconciliation remain implemented. Engineering Observation Period dogfood in a
normal live Codex terminal session exposed a correctness gap that is now
represented by `live_codex_evidence_convergence_correctness` and marked
implemented after real dogfood validation. The correction slice owns continuous
transcript tail convergence, factual projection freshness, visible
commentary/summary classification, provider/model/effort metadata, and identity
labeling for ordinary bmux-hosted Codex CLI sessions.

Hook and transcript observations now converge on provider turn identity when
Codex exposes it. The hook feed payload forwards `turn_id`, hook prompt
evidence uses that provider turn instead of a synthetic hook turn, transcript
prompt IDs canonicalize by provider turn when available, and prompt-only
transcript backfill no longer creates duplicate transcript-specific turns.

Three-view session boundary: one coding-agent session should be viewable as
Native, Terminal, and Session. Native is the provider-native surface and escape
hatch. Terminal is bmux's React live interaction surface, building on
`agent-chat`. Session is a separate React smart summary surface backed by PE
factual and semantic models. bmux should not turn Terminal into a semantic
engine or build parallel Swift and React Smart Session products.

Normal terminal Codex rich evidence is implemented for active bmux-managed
Codex sessions under the current factual evidence contract. Historical import
remains available via `bmux provenance import codex-transcripts`, and active
sessions use the same canonical evidence semantics through live transcript
ingestion. PE semantic work must consume this reconciled factual foundation
rather than repairing hook/transcript duplication, stale projections, or
metadata mistakes downstream.

Deterministic Turn Outcome Projection is implemented in the Provenance Engine
package inside the bmux monorepo. `turnOutcome(...)` exposes a revisioned,
rebuildable factual outcome for one coding-agent turn with field or item
evidence references, source evidence watermark, repository/worktree boundary,
validation command attempts, explicit continuation state, and completeness
metadata. It remains below semantic `SessionWorkModel` interpretation and does
not summarize, rank, or inject cross-session context.

Session Outcome aggregation is implemented on branch
`session-outcome-aggregation` as the next factual PE layer above Turn Outcome.
`sessionOutcome(...)` exposes a revisioned, rebuildable outcome projection for
one coding-agent session, aggregates exact accepted `TurnOutcome` revisions,
preserves ordered constituent turn references, reconciles latest factual plan
state, records repository/worktree/branch/HEAD boundaries without silently
mixing incompatible boundaries, and exposes completeness/source-availability
metadata. It remains below semantic `SessionWorkModel`, Smart Session UI,
cross-session retrieval, context injection, and Knowledge Compiler output.

Cross-session work awareness foundation is implemented on branch
`cross-session-work-awareness-foundation` as the first PE-owned read-only
related-session layer above Session Outcome and SessionWorkModel.
`relatedSessions(...)` accepts a target PE session id plus bounded result,
omission, recent-time, and revision options. It returns deterministic
related-session briefs with typed relationship reasons, exact Session Outcome
revision ids, compact Session Outcome facts, optional existing SessionWorkModel
semantic fields with their original provenance, freshness/source-watermark
metadata, and explicit completeness states. It remains read-only and does not
add prompt injection, agent coordination, raw transcript sharing, proactive UI,
artifact-collision warnings, Knowledge Compiler behavior, or new milestone,
blocker, decision, risk, approach-change, or architecture inference.

Artifact and change collision awareness is implemented as the next PE-owned
deterministic read above Session Outcome and related-session discovery.
`artifactCollisions(...)` returns bounded possible-collision candidates for a
target session, exact normalized artifact path, participating sessions,
repository/worktree/branch/HEAD boundaries, temporal overlap state, freshness,
completeness, source watermarks, Session Outcome and related-session projection
revisions, and supporting evidence references. It is intentionally possible
collision awareness only: it does not infer semantic incompatibility, rename
identity, overwrite risk, correctness, obsolescence, coordination policy,
prompt/context injection, bmux UI, proactive notification, whole-transcript
sharing, or Knowledge Compiler behavior.

Live prompt-link repair is implemented for active Codex sessions: on
`UserPromptSubmit`, bmux now starts/resumes transcript observation and runs the
bounded Codex prompt backfill even when no mobile chat subscriber is attached,
so PE can receive prompt evidence and a `lastSubmittedPromptSessionID` for the
Session tab. Dogfood on build 480 showed prompt evidence was recorded but not
linked when transcript backfill resolved only the runtime workspace id; the
runtime now resolves prompt evidence through all routed app tab managers so the
stable workspace display row receives the session link. This does not complete
the broader semantic-session product. Routed workspace display refreshes now
notify the owning tab manager rather than only the startup manager, so linked
prompt state can update immediately in the window that owns the workspace.

Milestone inference is implemented on branch `session-milestone-inference` and
PR #84. SessionWorkModel now exposes bounded coding-agent milestone semantics
from existing semantic inference records: plan-derived milestone collections,
prompt fallback only when no usable plan exists, reported state basis,
identity basis, evidence references, hierarchy validation, bounded omissions,
ambiguity notes, producer version, and existing semantic supersession metadata.
Provider-reported completion is not validation, merge, or acceptance proof.
Blockers, approach changes, progress, milestone-to-code relationships,
milestone-to-architecture relationships, risk, and scoped architecture remain
future semantic slices.

Planning target: PE owns the `SessionWorkModel` projection for one
coding-agent session. bmux should consume PE factual projection, semantic
messages, and the revisioned `SessionWorkModel` snapshot for Smart Session
summaries. Current factual Session UI work should be treated as factual
consumer groundwork/diagnostics and data-access foundation, not the final React
Smart Session product. Use generated Project Truth for active work,
dependency-ready work, selected-next work, and safe parallel work.

Monorepo migration status: bmux is the canonical repository and PE now lives as
a package under `Packages/macOS/ProvenanceEngine`. Cross-component slices should
use one branch and one worktree unless a future release/extraction task
explicitly requires a separate PE checkout. The original PE repository remains
an archival and recovery reference until the migration is accepted.

Verification for this milestone-inference branch:

- Project Truth: `./scripts/project-docs validate`, `./scripts/project-docs generate`, `./scripts/project-docs check`, and authenticated `./scripts/project-docs ci`
- Provenance Engine: `swift test --package-path /Users/brianbusby/repos/.bmux-worktrees/session-milestone-inference/Packages/macOS/ProvenanceEngine`
- Milestone focus: `swift test --package-path /Users/brianbusby/repos/.bmux-worktrees/session-milestone-inference/Packages/macOS/ProvenanceEngine --filter MilestoneInferenceTests --filter ProvenanceEngineSessionWorkModelClientFactoryTests`
- Regression focus: semantic inference, SessionWorkModel, Turn Outcome, Session Outcome, related-session, artifact-collision, SDK, migration, and rebuild suites through the full PE package test
- Guards: `python3 scripts/swift_file_length_budget.py --repo-root . --base-ref origin/main`, `git diff --check`, `./scripts/lint-pbxproj-test-wiring.sh`, and `python3 scripts/check-package-resolved-policy.py`

Runtime tests or tagged reloads are only required when production app/runtime
behavior changes; this branch changes PE package contracts/storage only.

Codex transcript importer verification is covered by the
`WorkProvenanceStoreTests` suite in the `bmux-unit` scheme.

Known local quirk: the normal Xcode app build script can fail while building the
Ghostty CLI helper with Zig unresolved macOS symbols on this machine. The focused
test used the repo-supported `BMUX_SKIP_ZIG_BUILD=1` stub path. The tagged
reload succeeded through `reload.sh`, which automatically skipped the local
Ghostty CLI helper build for this macOS SDK/Zig combination.
Additional local quirk: `cd agent-chat && bun x tsc --noEmit` currently fails
on `adapters/lines.ts` because `ReadableStream<Uint8Array<ArrayBufferLike>>`
lacks an async iterator in the active TypeScript library environment. The
focused Codex telemetry test still passes.

## Current Handoffs

- Project Truth: `docs/handoffs/latest.md`
- Execution telemetry: `docs/execution-telemetry/handoffs/latest.md`

## Historical Evidence

Historical slice details remain in:

- `docs/context-efficiency/integration/provenance-engine-adoption-history.md`
- `docs/context-efficiency/integration/provenance-engine-adoption.md`
- `docs/execution-telemetry/implementation-status.md`
- `docs/execution-telemetry/handoffs/`
