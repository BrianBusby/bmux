# Project Truth

bmux consumes shared project state from Provenance Engine instead of copying it.

## Shared State

`project/shared-project-source.yaml` points at the canonical shared manifest:

```text
BrianBusby/provenance-engine:project/project-state.yaml
```

Local generation resolves that shared manifest through either:

1. `PROJECT_TRUTH_SHARED_STATE=/path/to/project-state.yaml`; or
2. the expected sibling checkout layout:

```text
repos/
  bmux/
  provenance-engine/
```

The absolute local path is not committed.

## Local State

`project/repo-status.yaml` records bmux-only facts: active implementation slice,
execution telemetry capability state, local release state, and bmux-owned
caveats.

Do not place shared ownership boundaries, shared gates, or cross-repository
milestone acceptance in bmux's local manifest.

## Commands

```bash
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs validate
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs generate
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs check
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs ci --peer-repo-root ../provenance-engine
```

`PROJECT_TRUTH_TOOL_ROOT` may point at a non-sibling copy of Provenance Engine
or directly at the canonical `tools/project-docs` implementation.

```bash
PROJECT_TRUTH_TOOL_ROOT=../provenance-engine ./scripts/project-docs validate
PROJECT_TRUTH_TOOL_ROOT=../provenance-engine/tools/project-docs ./scripts/project-docs validate
```

Generated files live under `docs/generated/` and must not be edited manually.
The authoritative generated status starts at
[`docs/generated/project-status.md`](../docs/generated/project-status.md).

`ci` is deterministic and read-only. It validates schemas, generated-document
freshness, bmux shared-source semantics, named cross-repository invariants,
bounded authored-document drift, and GitHub evidence for referenced
repositories, commits, pull requests, issues, tags, and releases. It uses
`GITHUB_TOKEN` or `GH_TOKEN` when available. Missing evidence, contradictory
GitHub state, authentication failures, rate limits, and network failures fail
with separate categories.

This validation does not copy the shared manifest into bmux, write manifests,
edit documentation automatically, synchronize through a GitHub App, or persist
GitHub responses as project state.
