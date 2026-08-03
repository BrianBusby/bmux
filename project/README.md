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
```

`PROJECT_TRUTH_TOOL_ROOT` may point at a non-sibling copy of the canonical
`tools/project-docs` implementation.

Generated files live under `docs/generated/` and must not be edited manually.
