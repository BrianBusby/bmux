# bmux Handoff

## Project Truth Foundation

Project Truth foundation now exists for the bmux and Provenance Engine
integration effort.

- Shared cross-repository facts live in
  `BrianBusby/provenance-engine:project/project-state.yaml`.
- bmux local facts live in `project/repo-status.yaml`.
- `project/shared-project-source.yaml` identifies the canonical shared source.
- Generated current-status pages live under `docs/generated/`.
- Generated files must not be edited manually.

## Commands

```bash
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs validate
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs generate
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs check
```

Set `PROJECT_TRUTH_TOOL_ROOT` when the canonical provenance-engine tool is not
available through a sibling checkout.

## Next Recommended Slice

Add required `project-truth` CI validation, cross-repository invariant checking,
GitHub PR/issue state verification, and drift detection.

Do not select GitHub App synchronization before the read-only CI checks have
been proven.
