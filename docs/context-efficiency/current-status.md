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
Reconciliation are the latest implemented slices. bmux now tails active
ordinary Codex CLI JSONL transcripts from the existing Codex monitor path,
feeds newly completed lines through the same canonical transcript adapter used
by historical import, and writes PE thread, turn, prompt, plan, command,
visible reasoning summary, and file-change attribution evidence incrementally
without requiring Agent Chat.

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

Normal terminal Codex rich evidence is no longer the current data-foundation
gap for active bmux-managed Codex sessions. Historical import remains available
via `bmux provenance import codex-transcripts`; active sessions now use the
same evidence semantics through live transcript ingestion. The next PE semantic
work should consume this reconciled factual foundation rather than repairing
hook/transcript duplication downstream.

Planning target: PE owns the future `SessionWorkModel` projection for one
coding-agent session. bmux should consume PE factual projection, semantic
messages, and eventually the revisioned `SessionWorkModel` snapshot for Smart
Session summaries. Current factual Session UI work should be treated as factual
consumer groundwork/diagnostics and data-access foundation, not the final React
Smart Session product. Use generated Project Truth for active work,
dependency-ready work, selected-next work, and safe parallel work.

Monorepo migration status: bmux is the canonical repository and PE now lives as
a package under `Packages/macOS/ProvenanceEngine`. Cross-component slices should
use one branch and one worktree unless a future release/extraction task
explicitly requires a separate PE checkout. The original PE repository remains
an archival and recovery reference until the migration is accepted.

Verification for planning/docs-only Project Truth slices:

- Project Truth: `./scripts/project-docs validate && ./scripts/project-docs generate && ./scripts/project-docs check`
- Read-only CI gate locally when GitHub evidence access is available: `./scripts/project-docs ci`
- Run `git diff --check` in the monorepo.

Runtime tests or tagged reloads are only required when production app/runtime
behavior changes; this three-view clarification is planning/documentation only.

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
