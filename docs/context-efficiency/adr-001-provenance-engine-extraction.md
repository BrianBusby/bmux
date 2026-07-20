# ADR-001: Provenance Engine Extraction & Product Boundaries

**Status:** Accepted

**Date:** 2026-07-20

**Primary Consumer:** Codex

---

# Purpose

This document defines the architectural goals, product boundaries, migration strategy, and success criteria for extracting the provenance functionality from **bmux** into an independent repository.

This is **not** a simple repository split.

The objective is to establish the Provenance Engine as an independent product with bmux becoming its first client.

---

# Mission

The Provenance Engine captures, organizes, and retrieves the evidence produced during software development so humans and AI agents can understand why software evolved, recover relevant prior context, and continue work without replaying the project's complete history.

Git records **what changed**.

The Provenance Engine records **how and why software evolved**.

The engine's responsibility is to create a durable engineering memory layer that outlives individual sessions, AI models, and tools.

---

# Vision

The Provenance Engine should become reusable infrastructure capable of serving many engineering tools.

Today:

```text
bmux
```

Future:

```text
               Provenance Engine
                       ^
                       |
      +----------------+----------------+
      |                |                |
    bmux          IDE Plugin        GitHub
      |                |                |
      +-------- Future Clients --------+
      |                |                |
  CI Systems      Review Tools     AI Agents
```

bmux is simply the first client.

The architecture must not assume bmux is the only client.

---

# Architectural Principles

These principles take precedence over implementation details.

---

## Product Independence

The Provenance Engine is an independent product.

It should have:

- its own repository
- its own releases
- its own versioning
- its own documentation
- its own tests
- its own SDK
- its own API

The Provenance Engine must never depend on bmux.

Dependency direction:

```text
bmux
    |
    v
Provenance Engine
```

Never:

```text
bmux
    v
Provenance Engine
    v
bmux
```

---

## Local First

V1 is entirely local.

Requirements:

- SQLite
- no cloud
- no authentication
- no synchronization
- no remote services

Future synchronization should be possible but should not influence V1 architecture.

---

## Durable Knowledge

The engine owns durable engineering knowledge.

Examples:

- sessions
- work items
- evidence
- decisions
- relationships
- repositories
- context bundles

The engine does not own:

- terminal panes
- UI state
- workspace layouts
- model selection
- Codex runtime
- bmux windows

---

## Event-Oriented

Engineering work should be represented as immutable events.

Prefer append-only history over mutable state.

History should always remain reconstructable.

---

## Hierarchical Retrieval

Project knowledge should continuously grow.

Agent context should not.

Retrieval should return only the minimum evidence required for the current task.

---

## Explainability

Every context bundle should explain why each piece of evidence was selected.

The engine should never become a black box.

---

# Product Boundary

## Provenance Engine Owns

- domain model
- event schema
- evidence schema
- work items
- decisions
- relationship graph
- repositories
- storage
- indexing
- search
- retrieval
- context generation
- migrations
- public API
- SDK
- daemon
- CLI

---

## bmux Owns

- session orchestration
- terminal management
- worktrees
- Codex integration
- UI
- model management
- capture adapters
- provenance visualization

---

# Repository Structure

Suggested layout:

```text
provenance-engine/

    packages/

        core/
        contracts/
        storage-sqlite/
        sdk-typescript/
        client/

    apps/

        daemon/
        cli/

    tests/

        unit/
        contract/
        integration/

    docs/

        architecture/
        protocol/
        examples/
```

Implementation details may evolve.

Architectural separation should not.

---

# Public Integration Layer

Applications communicate exclusively through the SDK/API.

Consumers must never manipulate provenance database tables directly.

Public capabilities include:

- register repository
- register worktree
- create session
- finish session
- append event
- append evidence
- create work item
- record decision
- record unresolved question
- retrieve sessions
- retrieve work items
- retrieve evidence
- search
- build context bundle

---

# Runtime Architecture

```text
bmux

    |

    v

SDK

    |

    v

Local Provenance Daemon

    |

    v

SQLite
```

The daemon should expose:

- version
- health
- capabilities

Temporary daemon failure should degrade gracefully.

---

# bmux Translation Layer

bmux-specific concepts should terminate at an adapter.

```text
Codex Session

      |

      v

bmux Provenance Adapter

      |

      v

Normalized Provenance Events

      |

      v

SDK

      |

      v

Engine
```

The engine should not understand bmux internals.

---

# Migration Strategy

## Phase 0

Audit the current implementation.

Identify:

- provenance modules
- schemas
- storage
- migrations
- capture paths
- UI consumers
- shared types
- bmux assumptions
- tests

Produce a concise migration report.

---

## Phase 1

Characterize existing behavior.

Strengthen tests.

Document invariants.

---

## Phase 2

Introduce public contracts.

Create interfaces before moving implementations.

---

## Phase 3

Create the Provenance Engine.

Move reusable logic.

Remove bmux assumptions.

Build:

- SDK
- daemon
- CLI

---

## Phase 4

Reconnect bmux.

Replace internal provenance calls.

Use only the SDK.

Preserve behavior.

---

## Phase 5

Support migration of existing provenance data.

Migration should be:

- idempotent
- resumable
- validated
- reversible during development

---

## Phase 6

Remove duplicated implementation from bmux.

---

# Reliability Requirements

Support:

- append-only events
- transactional writes
- deterministic identifiers
- idempotent ingestion
- schema migrations
- diagnostics
- structured logging
- recovery
- graceful degradation

---

# Versioning

Version:

- SDK
- protocol
- event schema

Database schema remains internal.

Historical events should remain readable.

bmux and the engine should release independently.

---

# Testing

Provide:

- unit tests
- contract tests
- integration tests
- migration tests
- compatibility tests

---

# Acceptance Criteria

The extraction is complete when:

- Provenance Engine builds independently.
- No provenance package imports bmux.
- bmux depends only on the SDK.
- bmux no longer reads provenance storage directly.
- Existing functionality is preserved.
- Existing provenance data migrates successfully.
- Context bundles work.
- Another standalone client can consume the engine.
- bmux and the engine can release independently.

---

# V1 Non-Goals

Do not implement:

- cloud sync
- authentication
- enterprise permissions
- collaboration
- billing
- Slack integration
- GitHub Apps
- IDE plugins
- distributed storage
- analytics dashboards
- autonomous organizational learning

These belong in future milestones.

---

# Long-Term Direction

The Provenance Engine should become the engineering memory layer beneath developer tools.

It should connect:

- sessions
- repositories
- work items
- decisions
- evidence
- code evolution

into a searchable graph that enables humans and AI systems to efficiently understand and continue engineering work.

It is not intended to replace Git, issue trackers, or documentation.

It exists to connect them into a coherent history of engineering decisions.

---

# Future Design Work (Not Required for This Extraction)

This ADR intentionally focuses on establishing the product boundary and architecture of the Provenance Engine.

Following completion of the extraction, the next major architectural deliverable will be a comprehensive **Engineering Design Specification (EDS)** describing the internal design of the engine.

That document is expected to define, among other topics:

- Canonical domain model
- Entity lifecycle
- Event taxonomy
- Relationship graph
- Storage abstractions
- Query architecture
- Retrieval algorithms
- Context bundle generation
- Citation and attribution model
- Plugin architecture
- Extension points
- Performance targets
- Operational characteristics

During this extraction, avoid prematurely hard-coding assumptions that would make future refinement difficult.

Prefer modular boundaries, clean abstractions, and replaceable implementations where uncertainty exists.

The primary objective of this ADR is to establish a clean, reusable product boundary, not to finalize the engine's internal architecture.

---

# Guidance for Codex

Treat this document as an architectural decision record rather than a rigid implementation checklist.

If, during implementation, a cleaner architecture emerges that better satisfies the mission and principles described here, prefer the stronger architecture.

When deviating from this proposal, document the reasoning and ensure the resulting design better satisfies the long-term goals of the Provenance Engine.
