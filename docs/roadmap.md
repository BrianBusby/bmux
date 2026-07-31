# Provenance Engine Roadmap

This is the authoritative roadmap for the provenance-engine repository. It defines implementation sequence and priorities for reusable provenance contracts, storage, SDK boundaries, retrieval, shared evidence, and derived knowledge. The full platform shape is defined in `docs/reference-architecture.md`; this file describes when slices of that architecture should be pursued. bmux product behavior and user experience belong in the bmux roadmap. Coordinated adoption milestones live in `docs/bmux-integration-roadmap.md`.

## Accepted Baseline

- Independent Swift package with `ProvenanceEngineContracts`, `ProvenanceEngineSDK`, and internal `ProvenanceEngineSQLite` modules.
- Public in-process client factory through `ProvenanceEngineClientFactory`.
- SQLite event ledger, current-state projections, schema migration metadata, validation, integrity reports, and repair reports.
- Public read/write contracts for worktrees, session trees, file explanations, current context, event append, lifecycle recording, health, and storage summaries.
- Optional event evidence-origin and evidence-scope metadata so records are not hard-coded as personal-only evidence.
- V1 local-first storage default at `~/.local/state/provenance-engine/provenance.sqlite`.

## Current V1 Adoption

The current roadmap priority is not new engine expansion. Slice E is
operationally accepted, and the active priority is observing and validating the
accepted bmux integration before choosing cleanup, release, or post-V1 work.

Completed:

- `bmux provenance worktrees list` adopted `ProvenanceEngineClientFactory` and `ProvenanceEngineClient.worktrees(...)` through provenance-engine `0.1.0`.
- Slice C: `bmux provenance sessions tree <session-id>` adopted `ProvenanceEngineClientFactory` and `ProvenanceEngineClient.sessionTree(...)` through the accepted session-tree read contract. bmux PR 7 merged at `08763dd0d3256989180dcc04f426da1f24369175` with an explicit GitHub Actions waiver for unavailable Blacksmith runner evidence.
- Slice D: `bmux provenance explain <path>` adopted `ProvenanceEngineClientFactory`, `ProvenanceEngineClient.worktrees(...)`, and `ProvenanceEngineClient.fileExplanation(...)` through the accepted file-explanation contract. bmux PR 9 merged at `c1c5fce0eb7526d321dbed6c8a6f25f0d9aaf374` with a Slice D-specific GitHub Actions waiver for unavailable Blacksmith runner evidence.
- Slice E: bmux adopted `bmux provenance context current`, supported
  lifecycle recording through `recordSessionLifecycle(...)`, accepted
  Git/worktree observation capture through `appendEvent(...)`, production
  default storage cutover to the engine-owned SQLite store, and schema identity
  hardening. bmux merged the operational runtime cutover at
  `3cbacd1501768f79ea377eb2d6aea9113f199d1b`; this repository recorded the
  acceptance update at `0ed9f68b66126ce50ec0f0ce7f7f6569b02a9dbc`.

Current gate:

- Engineering Observation Period after Slice E.
- Observe the operational integration, collect failures or compatibility gaps,
  and decide later whether the next selected work is legacy cleanup,
  observability API design, a tagged engine release, or another explicit slice.

Canonical cross-repository details: `docs/bmux-integration-roadmap.md`.

## Additional Bmux Adoption Paths

The initial V1 package and bmux adoption sequence is complete. Future bmux
adoption work should still be selected one path at a time after observation
findings justify it.

Accepted V1 adoption paths:

- Current session and task context through `currentContext(...)`.
- Supported lifecycle recording through `recordSessionLifecycle(...)`.
- Accepted Git/worktree observation capture through `appendEvent(...)`.
- Operational production default storage cutover to
  `~/.local/state/provenance-engine/provenance.sqlite`.

Still gated:

- Broad legacy bmux-local database migration or deletion.
- A public observability trace API, if observation proves one is needed.
- A tagged Provenance Engine release to replace revision pins.
- Daemon/service transport, only if the in-process SDK boundary proves
  insufficient.
- Shared evidence, GitHub ingestion, retrieval, and Knowledge Compiler work.

Execution-telemetry live state, capture policy, diagnostics, orchestration, UI,
and analytics remain bmux-owned. Provenance Engine receives only explicitly
approved durable engineering evidence and broad lifecycle facts through the
public SDK.

## External Evidence Model Validation

Status: planned and gated after Engineering Observation Period findings justify
the next post-V1 evidence-model slice.

This phase validates repository and external evidence without conflating it with personal AI-session evidence. It should refine origin/scope usage, authorization expectations, compatibility rules, and evidence-store boundaries before adding broad ingestion.

## Shared Evidence-Store Design

Status: planned and gated.

Design personal, project, and organization evidence scopes so shared repository evidence is ingested once for a repository or organization instead of being independently collected and summarized by every engineer.

## GitHub Ingestion Spike

Status: post-V1 spike only.

The spike should ingest raw objective evidence only:

- Commits and commit metadata.
- Changed files and changed symbols.
- Pull request metadata and bodies.
- PR comments.
- Submitted reviews.
- Inline review comments.
- Merge status.
- Commit-to-PR relationships.
- Review thread resolution.

No AI summarization should run during this spike. The spike exists to validate storage shape, incremental sync, authentication, API limits, ingestion performance, commit-to-PR relationships, changed-file/symbol preservation, and review-thread-to-diff relationships before introducing interpretation.

## Pull Request Decision Summary Compiler

Status: planned after the GitHub ingestion spike.

The Knowledge Compiler consumes immutable evidence and produces versioned knowledge artifacts. Evidence remains immutable; knowledge can be regenerated by newer compiler versions.

Initial artifact:

```text
Pull Request Decision Summary
```

Suggested fields:

- Intent.
- Accepted constraints.
- Rejected alternatives.
- Important review findings.
- Deferred work.
- Final outcome.
- Supporting evidence references.

## Evidence-Aware Retrieval Validation

Status: exploratory until compiled PR decision summaries exist.

Retrieval should prefer compiled knowledge plus minimal supporting evidence. Agents should not receive thousands of commits, full PR discussions, or complete review threads by default.

## Organization-Scale Deployment

Status: deferred.

Daemon or service transport, shared deployment, authorization enforcement, compatibility policy across released versions, and organization-scale storage operations belong after local V1 adoption and evidence-aware retrieval have both been validated.

## V1 Write-Side Validation Result

Status: complete in provenance-engine as of 2026-07-25.

The write-side architecture has been validated by a generic non-bmux producer
using only `ProvenanceEngineContracts` and `ProvenanceEngineSDK`. The result is
recorded in `docs/write-side-validation-milestone.md`.

Accepted conclusion: `appendEvent(...)` remains the V1 write primitive. The
validated friction is payload verbosity and stable-ID guidance, not storage or
bmux leakage. Future write-side improvements should be producer convenience and
documentation work unless new consumer evidence justifies a public contract
change.

## Canonical V1 Boundary

The canonical V1 boundary is `docs/v1-boundary-review.md`.

V1 is complete when independent producers and consumers can record and retrieve
local engineering provenance through the public SDK, with immutable evidence as
the system of record and deterministic Current State rebuilt from that evidence,
without depending on bmux, storage internals, or future knowledge-platform
components.

Capabilities outside that definition should be treated as post-V1 unless a
future boundary review explicitly reclassifies them.

## V1 Freeze Refinement

The V1 freeze boundary includes producer-neutral lifecycle recording through
`recordSessionLifecycle(...)`, durable accepted local SDK writes, and Current
State as the first-class deterministic engine layer between immutable evidence
and public read APIs. The deprecated `recordSubsessionLifecycle(...)` wrapper is
compatibility-only and should not be used by new producers.

Producer delivery reliability before engine acceptance, distributed queues,
remote services, Knowledge Compiler, semantic retrieval, and organization-scale
evidence stores remain post-V1.
