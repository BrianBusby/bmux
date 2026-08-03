<!--
GENERATED FILE. DO NOT EDIT MANUALLY.
Sources:
- BrianBusby/provenance-engine:project/project-state.yaml
- project/shared-project-source.yaml
- project/repo-status.yaml
Regenerate with: ./scripts/project-docs generate
-->


# Ownership Boundary

| Responsibility | Owner |
| --- | --- |
| Bounded provenance queries | Provenance Engine |
| Capture policy | Bmux |
| Deterministic Current State | Provenance Engine |
| Durable evidence | Provenance Engine |
| Execution telemetry | Bmux |
| Presentation | Bmux |
| Runtime orchestration | Bmux |
| Schema compatibility | Provenance Engine |
| User interface | Bmux |
| Workflow observation | Bmux |

## Durable Versus Ephemeral Policy

| Policy | Value |
| --- | --- |
| Raw execution telemetry persisted | false |
| Live projection persisted | false |
| Narrow lifecycle projection enabled | true |
| Automatic checkpoint diagnostics | not implemented |
| Automatic checkpoint diagnostics selected | false |
