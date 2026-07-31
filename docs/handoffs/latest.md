# Provenance Engine Handoff

## Project Truth Foundation

Project Truth foundation now exists for the bmux and Provenance Engine
integration effort.

- Shared cross-repository facts live in `project/project-state.yaml` in this
  repository.
- Provenance Engine local facts live in `project/repo-status.yaml`.
- Generated current-status pages live under `docs/generated/`.
- Generated files must not be edited manually.

## Commands

```bash
./scripts/project-docs validate
./scripts/project-docs generate
./scripts/project-docs check
```

bmux consumes this repository's shared manifest through its
`project/shared-project-source.yaml` pointer and can override the path locally
with `PROJECT_TRUTH_SHARED_STATE=/path/to/project-state.yaml`.

## Next Recommended Slice

Add required `project-truth` CI validation, cross-repository invariant checking,
GitHub PR/issue state verification, and drift detection.

Do not select GitHub App synchronization before the read-only CI checks have
been proven.
