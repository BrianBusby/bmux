# bmux Handoff

## Project Truth CI and Read-Only Drift Verification

Project Truth read-only CI validation is the current completed infrastructure
slice for the bmux and Provenance Engine integration effort.

- Shared cross-repository facts live in
  `BrianBusby/provenance-engine:project/project-state.yaml`.
- bmux local facts live in `project/repo-status.yaml`.
- `project/shared-project-source.yaml` identifies the canonical shared source.
- Generated current-status pages live under `docs/generated/`, starting with
  [`docs/generated/project-status.md`](../generated/project-status.md).
- Generated files must not be edited manually.
- The continuing project state remains the Engineering Observation Period;
  do not select a new product implementation slice from this handoff alone.

## Commands

```bash
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs validate
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs generate
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs check
PROJECT_TRUTH_SHARED_STATE=../provenance-engine/project/project-state.yaml ./scripts/project-docs ci --peer-repo-root ../provenance-engine
```

Set `PROJECT_TRUTH_TOOL_ROOT` when the canonical provenance-engine tool is not
available through a sibling checkout. It may point either to the Provenance
Engine repository root or directly to `tools/project-docs`.

`ci` validates schema validity, generated-doc freshness, bmux shared-source
semantics, named cross-repository invariants, bounded authored-doc drift, and
read-only GitHub evidence. It uses `GITHUB_TOKEN` or `GH_TOKEN` when available.
Network, auth, rate-limit, missing-resource, and contradictory-evidence
failures are reported separately.

## Next Recommended Slice

Keep the read-only checks under observation as required branch-protection
candidates. Do not build GitHub App synchronization, automatic manifest edits,
provenance-backed project-state events, telemetry checkpoint automation, or new
bmux UI work until the observation gate produces a specific follow-up decision.
