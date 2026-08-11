# bmux Provenance Integration

This document records bmux's reference integration with the finalized Provenance Engine V1 public contract.

The cross-repository roadmap remains in provenance-engine:

https://github.com/BrianBusby/provenance-engine/blob/main/docs/bmux-integration-roadmap.md

The Provenance Engine integration contract remains the technical authority for public APIs:

https://github.com/BrianBusby/provenance-engine/blob/main/docs/integration-contract.md

Current milestone, ownership, policy, caveat, and local status facts are
generated from the project manifests:

- [Project status](generated/project-status.md)
- [Ownership boundary](generated/ownership-boundary.md)
- [Repository status](generated/repository-status.md)

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

## Future Context Architecture

The long-term sequence is local provenance, early local Knowledge Compiler
validation, shared evidence validation/design, shared compiler maturation,
retrieval, measured agent-context validation, then service, multi-user, and
product integration. This document does not activate those slices.

Provenance Engine owns immutable durable engineering evidence, evidence
identity/origin/scope/relationships/lineage, deterministic Current State, local
and shared evidence-store semantics, authorization/filtering semantics,
Knowledge Compiler framework and artifacts, evidence-aware retrieval, bounded
context packages with evidence references, and compatibility/versioning for PE
service contracts.

bmux owns observation/capture adapters in the developer environment,
Codex/Claude/agent orchestration, live PTYs and terminal/session transport,
remote attachment/control, desktop and mobile UX, notifications, approvals,
prompt/context assembly policy, temporary UI state, and product fallback
behavior.

The first future Knowledge Compiler work should be a small local validation
slice after PE stores enough real evidence to derive a useful higher-level
signal, such as an `ImplementationOutcome`. Later shared/multi-source compiler
validation can use artifacts such as `PRDecisionSummary`. Every durable
compiled artifact must keep supporting evidence references and compiler/version
lineage so it can be regenerated or invalidated.

bmux should not reconstruct provenance knowledge from raw shared storage. PE
should not become a live terminal streaming service. Hot PTY bytes, terminal
snapshots, input, approvals, reconnect, and session control remain bmux
transport responsibilities.

## Workspace Display State

Current truth: workspace tab titles, sidebar titles, branch labels, PR numbers,
PR owner fields, PR state, stale PR clearing, and custom sidebar workspace
display fields are not yet implemented as a PE-backed display source. They
remain bmux-local/live display state until a dedicated Workspace Display Current
State Projection slice is selected and implemented.

Desired truth: bmux observes deterministic display facts, writes accepted
evidence to Provenance Engine, and reads PE Current State for display metadata.
The display projection should cover workspace title and title source, repository
and worktree identity, branch, accepted dirty state if already part of worktree
observation, PR number/status/url/owner login/owner profile URL/branch/staleness,
and projection revision/cursor/timestamp.

Observed facts should include workspace created/selected/renamed events, tab
renames, worktree branch changes, repository HEAD changes, PR metadata
found/changed/cleared events, PR state transitions (`open`, `merged`, `closed`),
and auto-name applied/suppressed/cleared events. Live session data must not be
the durable or steady-state display source of truth for these fields.

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
evidence accepted timestamp; PE Current State projection timestamp, revision,
or cursor; display observed timestamp; expected and observed display values;
latency in milliseconds; pass/fail; and stale/cleared-state correctness. Rename
diagnostics should additionally record old title, new title or a
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

bmux producer responsibilities are limited to observing engineering activity, assigning stable producer identities when available, recording observable or declared facts, and retaining best-effort error state for diagnostics. bmux must not compute deterministic Current State or reinterpret evidence already owned by the engine.

Captured workflows today:

- Worktree observation records Git repository/worktree/change-set/file-change evidence for bmux workspaces whose current directory is inside a Git repository.
- Agent lifecycle recording records hook-derived Codex/Claude-style subagent lifecycle through `ProvenanceSessionLifecycleRequest`.
- Supported live sidecar execution telemetry sessions record only broad
  session/provider/lifecycle presence through the same public lifecycle
  recorder, with cwd used only to derive a worktree id when possible.

Not every agent UI action implies a recorded session. Opening an agent-session surface alone creates UI state; durable lifecycle evidence is recorded when supported hooks/feed events reach bmux. Engine durability covers accepted events after they reach the SDK; producer delivery reliability remains bmux-owned.

The engine does not ingest or own the full execution telemetry stream. Raw
provider envelopes, message text, reasoning, command output, approval payloads,
token details, changed-file paths, diagnostics scheduling, UI, and analytics
remain bmux-owned unless a later policy slice explicitly changes that boundary.

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
