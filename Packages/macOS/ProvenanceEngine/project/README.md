# Project Truth

Provenance Engine owns the canonical cross-repository project-state manifest for
the bmux and Provenance Engine integration effort.

## Authority

`project/project-state.yaml` is the shared source for volatile facts that cross
repository boundaries: active gates, shared milestones, ownership boundaries,
telemetry persistence policy, automatic checkpoint status, and shared caveats.

`project/repo-status.yaml` is local to this repository. It records
Provenance Engine-specific current work, release state, local capabilities, and
local caveats.

bmux does not copy the shared manifest. Its `project/shared-project-source.yaml`
points back to this repository and path.

## Status Semantics

Delivery state describes the Git or review lifecycle: `proposed`, `draft`,
`open`, `merged`, `closed`, or `superseded`.

Acceptance state describes architectural acceptance: `proposed`, `implemented`,
`under_observation`, `accepted`, `rejected`, or `superseded`.

A merged pull request is delivery evidence. It is not automatic architectural
acceptance.

## Evidence

Milestone evidence uses structured repository references:

```yaml
evidence:
  commits:
    - repository: BrianBusby/bmux
      sha: 3cbacd1501768f79ea377eb2d6aea9113f199d1b
  pull_requests:
    - repository: BrianBusby/bmux
      number: 12
```

Do not encode live GitHub URLs when repository slug plus number is sufficient.

## Commands

```bash
./scripts/project-docs validate
./scripts/project-docs generate
./scripts/project-docs check
```

Generated files live under `docs/generated/` and must not be edited manually.
The authoritative generated status starts at
[`docs/generated/project-status.md`](../docs/generated/project-status.md).

## CI Validation

Use the deterministic CI gate before making Project Truth changes mergeable:

```bash
./scripts/project-docs ci
```

`ci` validates schemas, named invariants, generated-document freshness,
bounded authored-document drift, and read-only GitHub evidence. It uses
`GITHUB_TOKEN` or `GH_TOKEN` when available and otherwise performs unauthenticated
public GitHub reads. In CI, evidence verification fails closed for missing
resources, API authentication failures, rate limits, and network failures.

For coordinated local validation with a bmux sibling checkout, include bmux's
repo-local manifest in cross-repository invariant checks:

```bash
./scripts/project-docs ci --peer-repo-root ../bmux
```

`--skip-github` exists only for offline unit tests and local diagnosis; do not
use it for branch-protection checks.

This validation remains read-only. It does not implement GitHub App
synchronization, automatic manifest updates, automatic documentation commits,
or provenance-backed project-state events.
