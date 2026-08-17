# bmux Provenance Integration

This document records bmux's reference integration with the Provenance Engine public contract in the monorepo.

The current system architecture starts at [architecture/README.md](architecture/README.md).
The PE package boundary is documented at [architecture/provenance-engine/README.md](architecture/provenance-engine/README.md).
The imported PE package docs remain under `Packages/macOS/ProvenanceEngine/docs/`.

Current milestone, ownership, policy, caveat, and local status facts are
generated from the project manifests:

- [Project status](generated/project-status.md)
- [Ownership boundary](generated/ownership-boundary.md)
- [Repository status](generated/repository-status.md)

The planned high-level live coding-agent projection is documented in
`Packages/macOS/ProvenanceEngine/docs/session-work-model.md`. bmux should treat
that as target direction until generated Project Truth marks the relevant
`SessionWorkModel` slices implemented.

## Public SDK Boundary

bmux imports only the public engine products for adopted provenance paths:

```swift
import ProvenanceEngineContracts
import ProvenanceEngineSDK
```

Client construction happens through the public SDK factory. bmux embeds Provenance Engine as a Swift package; there is no engine daemon or external service to start.

```swift
let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
    try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
```

The SQLite-backed factory is an SDK construction detail. bmux code must not import engine implementation targets, instantiate engine SQLite types directly, or read engine projection tables from adopted read/write paths.

## Runtime Store

The canonical default store is owned by Provenance Engine: `~/.local/state/provenance-engine/provenance.sqlite`.

The previous bmux-local database remains at `~/.local/state/bmux/work-provenance/bmux-work-provenance.sqlite`. That legacy file is not deleted, archived, or opened as the default V1 store. In the local cutover validation it contained the old bmux schema, `PRAGMA user_version = 3`, and no useful event/session/worktree rows.

For tests and development, `BMUX_PROVENANCE_HOME` overrides the home directory used by bmux default-path resolution. Explicit CLI `--database <path>` is supported for provenance CLI fixture/debug use and applies only to that CLI invocation.

Startup breadcrumbs include the effective V1 database path in `app.init.workProvenance.created`. Producer failures are logged instead of being silently discarded.

## Current State Reads

bmux treats Provenance Engine Current State as authoritative present-tense provenance.

Adopted CLI reads:

- `bmux provenance worktrees list` calls `client.worktrees(...)`.
- `bmux provenance sessions tree <session-id>` calls `client.sessionTree(...)`.
- `bmux provenance explain <path>` calls `client.fileExplanation(...)`.
- `bmux provenance context current` calls `client.currentContext(...)`.

bmux still owns command parsing, Git path normalization, output compatibility, fallback text, JSON/text rendering, and UI presentation. The engine owns evidence, deterministic Current State, provenance interpretation, and bounded provenance queries.

## Workspace Display State

Current truth: bmux observes deterministic workspace display facts, writes
accepted evidence to Provenance Engine, and reads PE Workspace Display Current
State for the built-in workspace tab row. The PE-backed row projection covers
workspace title, current directory as branch/directory context when that detail
is enabled, branch, accepted dirty state, PR number/status/url/owner/branch/
staleness, ticket id/title/url/owner facts, current-work summary, the last
submitted prompt display text, and latest projection event id/sequence for
freshness.

Workspace Display Current State is field-reconciled, not an atomic latest-event
blob. Missing observations do not clear known Current State. A later observation
that includes only a branch must preserve previously accepted ticket, PR,
current-work, and prompt facts. Provider lookup failures must preserve the last
accepted value and update freshness/error diagnostics instead of projecting an
empty value.

Fields disappear only when affirmative evidence marks them no longer pertinent,
such as an explicit PR clear, successful provider evidence that a branch has no
PR, ticket replacement/removal, repository/worktree switch, or a session-context
policy clear for session-scoped fields. Explicit clears are represented in PE
workspace display evidence through `clearedFields`; bmux does not infer clears
from incomplete payloads, observer reconnect, app activation, API timeout,
telemetry events that omit fields, compaction, or live session disappearance.

Workspace display facts have separate lifecycles:

- Workspace/repository facts: repository/worktree/current directory/branch and
  dirty state. These follow the active workspace/worktree.
- Work-item facts: ticket id/title/url/owner and PR number/title/url/owner/state.
  These normally survive session transitions while the workspace/worktree remains
  associated with the same work.
- Session/work facts: current-work summary, last submitted prompt display text,
  and active session context. These are durable facts but follow the active/root
  session policy for the workspace.

bmux remains the local observer/producer for facts it can directly observe or
fetch from APIs. The tab row does not independently infer current PR/status/
ticket state from live workspace session data once PE has a value; live bmux
sidebar metadata remains only a transitional fallback before PE has populated a
workspace display projection.

Refresh triggers are intentionally separate from rendering. The row renders from
the cached PE Workspace Display Current State snapshot. bmux observation updates
PE from local events: runtime startup and workspace-list observation, workspace
current-directory/title/display-metadata notifications after local observer
writes, app activation, and workspace row appearance. GitHub/Linear/Git lookups
belong to bmux observers and must not run synchronously during row rendering.

Observed facts should include workspace created/selected/renamed events, tab
renames, worktree branch changes, repository HEAD changes, PR metadata
found/changed/cleared events, PR state transitions (`open`, `merged`, `closed`),
ticket enrichment, current-work summary changes, submitted prompt changes, and
auto-name applied/suppressed/cleared events. Live session data must not be the
durable or steady-state display source of truth for these fields after PE has
accepted the corresponding fact.

The last submitted prompt fact is a bounded workspace-display text fact, not
general transcript persistence. bmux currently supplies the same submitted
prompt preview used by the sidebar row; PE persists/projects that accepted
display value. Expanding this into raw prompt or transcript storage requires a
separate privacy/capture-policy slice.

bmux may use optimistic UI only as temporary pending state, such as immediately
reflecting a user rename while writing to PE. The pending value must reconcile
from PE Current State and must roll back or surface an error if PE rejects the
write.

Planning diagnostics should be read-only and should compare:

```text
observed bmux UI/model display
vs
PE Current State
vs
latest accepted evidence
```

Suggested commands:

```bash
bmux provenance diagnostics workspace-display --workspace <id> --json
bmux provenance diagnostics workspace-display --workspace <id> --watch --json
bmux provenance diagnostics workspace-rename --workspace <id> --json
```

Branch/PR diagnostics should measure whether display updates correctly when a
workspace moves from `main` to `feature/foo`, from `feature/foo` to
`feature/bar`, maps to PR `#N`, changes PR state from open to merged or closed,
leaves a PR-backed branch, or leaves a Git worktree. Rename diagnostics should
cover sidebar rename, command palette rename, `CLI rename-workspace`,
workspace-action rename, clear-name, auto-name, and agent `/rename` if
supported.

Diagnostics should record workspace id; tab or surface id when applicable;
repository root; branch before/after; PR before/after; PR status before/after;
ticket before/after; current-work before/after; prompt before/after; displayed
value; PE projected value; latest accepted evidence value/event/source/origin;
field-level observed timestamp; PE Current State projection timestamp, revision,
or cursor; display observed timestamp; freshness; explicit-clear state; last
refresh attempt/failure when available; latency in milliseconds; pass/fail; and
stale/cleared-state correctness. Rename diagnostics should additionally record
old title, new title or a
privacy-preserving hash, title source, whether the name is user-set, whether
auto-name was suppressed, request timestamp, rollback/error state if the write
failed, and later overwrite or revert detection.

This slice must stay focused on deterministic display facts. It must not
include broad GitHub ingestion, Knowledge Compiler work, semantic or AI
interpretation of PRs, raw execution telemetry persistence, raw live session
event storage, transcript storage, broad UI rewrite, automatic workspace naming
redesign, or GitHub write synchronization.

## Producer Writes

bmux records observable activity through public engine writes:

- Agent lifecycle changes are normalized into `ProvenanceSessionLifecycleRequest` and sent through `client.recordSessionLifecycle(...)`.
- Git/worktree observations are normalized into immutable `ProvenanceEvent` values and sent through `client.appendEvent(...)`.
- Selected structured Codex execution-telemetry facts are normalized into typed
  coding-agent evidence records and sent through `client.appendEvent(...)`.

bmux producer responsibilities are limited to observing engineering activity, assigning stable producer identities when available, recording observable or declared facts, and retaining best-effort error state for diagnostics. bmux must not compute deterministic Current State or reinterpret evidence already owned by the engine.

Captured workflows today:

- Worktree observation records Git repository/worktree/change-set/file-change evidence for bmux workspaces whose current directory is inside a Git repository.
- Agent lifecycle recording records hook-derived Codex/Claude-style subagent lifecycle through `ProvenanceSessionLifecycleRequest`.
- Supported live sidecar execution telemetry sessions record broad
  session/provider/lifecycle presence through the public lifecycle recorder,
  with cwd used only to derive a worktree id when possible.
- Codex sidecar telemetry records provider thread identity, provider turn
  lifecycle, submitted prompt text, provider plan updates, completed command
  facts, completed visible reasoning summaries, and file-change attribution
  through typed PE coding-agent evidence payloads.

Not every agent UI action implies a recorded session. Opening an agent-session surface alone creates UI state; durable lifecycle evidence is recorded when supported hooks/feed events reach bmux. Engine durability covers accepted events after they reach the SDK; producer delivery reliability remains bmux-owned.

The engine does not ingest or own the full execution telemetry stream. Raw
provider envelopes, streaming deltas, unrestricted assistant transcript text,
raw reasoning deltas, hidden chain-of-thought, unrestricted command output,
token-update streams, diagnostics scheduling, UI, and analytics remain bmux-
owned unless a later policy slice explicitly changes that boundary.

The accepted target direction is more precise than the older shorthand that
"execution telemetry remains bmux-owned." bmux owns provider acquisition, live
interaction, approvals, ephemeral state, and rendering. PE owns accepted durable
evidence and deterministic projections for selected completed or meaningful
units once explicit contracts exist.

Implemented durable Codex units preserve source identity where available and
relate to existing PE session, repository, worktree, change-set, and file-change
models where bmux can establish those relationships. Approval, validation,
error, and compaction evidence remain unimplemented. Model-derived milestone,
intent, current-activity, or architecture meaning must not be written into
deterministic PE Current State.

## Three-view Session Presentation Boundary

bmux should preserve three distinct views for one coding-agent session:

- Native: provider-native fidelity and escape hatch.
- Terminal: React live interaction through the `agent-chat` direction.
- Session: React smart summary backed by PE factual and semantic models.

The React Terminal surface is allowed to stay close to provider/runtime events
because it is the live interaction layer: streaming responses, tool lifecycle,
provider controls, approvals, interrupts, modes, skills, and working-directory
controls. It should not become the source of durable session meaning.

The React Smart Session surface should consume PE contracts for higher-level
understanding. Its first foundation can use `factualSessionProjection(...)`,
`factualSessionTurnDetail(...)`, semantic inference records, and semantic
messages. Later richer presentation should consume the PE `SessionWorkModel`
contract for completed/current turn summaries, progress, blockers, approach
changes, validations, risks, and milestone relationships. bmux should not build
a parallel semantic model from raw Terminal events.

The current factual Session view work is still valuable: it proves the factual
projection consumer shape, establishes data-access and diagnostic behavior, and
helps inspect provenance. Because that work is native Swift/factual-only, it
should be treated as scaffolding or diagnostics for the final Smart Session path
unless a future slice deliberately migrates or reuses pieces in the React
surface.

## Future SessionWorkModel Consumer Direction

The planned PE high-level projection is named `SessionWorkModel`. bmux should
consume it as a domain model for one coding-agent session, not create a parallel
bmux-owned semantic model.

Expected bmux responsibilities when that contract exists:

- forward policy-approved completed evidence units through public PE contracts;
- render a human-readable live coding-agent work view from the authoritative
  PE snapshot;
- treat push or delta notifications as hints and re-fetch the revisioned
  `SessionWorkModel` snapshot for reconciliation;
- keep live approvals, raw streams, UI interaction, and fallback behavior in
  bmux;
- present provenance/confidence on inferred fields instead of flattening them
  into facts.

Expected PE-owned semantic fields include thread intent, turn intent, session
phase, current activity, milestone hierarchy and descriptions, blocker/risk
state, scoped thread/current-turn architecture projections, milestone-to-
architecture links, and later milestone-to-diff/Git/GitHub attribution.

Current implemented behavior remains the lower-level V1 contract set:
`currentContext`, `sessionTree`, `fileExplanation`, `workspaceDisplay`,
lifecycle recording, and selected worktree/display evidence writes.

## Smoke Test

Use the tagged debug build and bundled CLI when validating local integration:

```bash
./scripts/reload.sh --tag slice-e-v1
BMUX_TAG=slice-e-v1 scripts/bmux-debug-cli.sh list-workspaces
sqlite3 ~/.local/state/provenance-engine/provenance.sqlite "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
sqlite3 ~/.local/state/provenance-engine/provenance.sqlite "SELECT COUNT(*) FROM provenance_events;"
bmux provenance worktrees list
bmux provenance context current
bmux provenance explain <changed-file>
bmux provenance sessions tree <session-id>
```

Required schema identity rows live in `provenance_metadata`: `schema_family = provenance-engine`, `schema_identity_version = 1`, and the current `schema_version`.

## Remaining Local Code

Some bmux-local storage and observability files remain for historical compatibility tests and lifecycle trace presentation. They are not the adopted runtime source of truth for Current State reads or lifecycle writes.

Do not add new provenance consumer behavior to `WorkProvenanceStore`, `BmuxLegacyProvenanceClient`, or direct SQLite readers. New consumer behavior must use `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.

## Reference Integration Checklist

Future producers should follow bmux's adopted pattern:

1. Import `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.
2. Create a `ProvenanceEngineClient` through `ProvenanceEngineClientFactory`.
3. Record lifecycle with `recordSessionLifecycle(...)`.
4. Record immutable evidence with `appendEvent(...)`.
5. Read present-tense provenance through Current State APIs.
6. Keep presentation and workflow policy in the consumer.
7. Keep evidence interpretation and deterministic state in the engine.
