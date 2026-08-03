# Documentation Guide

## Current Generated Truth

These files are generated from the project manifests and are authoritative for
current milestone, gate, ownership, policy, caveat, and repository-status facts.

- [generated/project-status.md](generated/project-status.md)
- [generated/ownership-boundary.md](generated/ownership-boundary.md)
- [generated/repository-status.md](generated/repository-status.md)

## Current Authored Guidance

These documents explain architecture, rationale, product direction, and
implementation guidance. They must link to generated status rather than
duplicate volatile facts.

- [roadmap.md](roadmap.md)
- [provenance-integration.md](provenance-integration.md)
- [context-efficiency/current-status.md](context-efficiency/current-status.md)
- [execution-telemetry/README.md](execution-telemetry/README.md)
- [execution-telemetry/architecture.md](execution-telemetry/architecture.md)
- [execution-telemetry/persistence-policy.md](execution-telemetry/persistence-policy.md)

## Decisions

These documents record durable architectural and policy decisions.

- [execution-telemetry/decisions.md](execution-telemetry/decisions.md)
- [context-efficiency/adr-001-provenance-engine-extraction.md](context-efficiency/adr-001-provenance-engine-extraction.md)

Future decisions should go under `docs/decisions/` when they are not tied to an
existing workstream directory.

## Historical Evidence

These records describe what was true at the time they were written. They are not
current status authorities.

- `docs/context-efficiency/integration/provenance-engine-adoption-history.md`
- `docs/execution-telemetry/handoffs/2026-*.md`
- `docs/context-efficiency/*-report.md`
- `docs/context-efficiency/*-plan.md`

Future historical reports should go under `docs/history/`.

## Handoffs

The current handoff is the entry point for the next implementation session.
Archived handoffs are historical records.

- [handoffs/latest.md](handoffs/latest.md)
- [execution-telemetry/handoffs/latest.md](execution-telemetry/handoffs/latest.md)
- `handoffs/archive/`
