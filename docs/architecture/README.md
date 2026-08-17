# Architecture Documentation

This directory is the canonical authored architecture map for the bmux monorepo.
Use generated Project Truth for volatile status and these authored pages for
boundaries, direction, and implementation orientation.

## Status Sources

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Ownership boundary](../generated/ownership-boundary.md)
- [Repository status](../generated/repository-status.md)

## Map Entrypoints

1. [System overview](system-overview.md) covers the Level 1 product/system map.
2. [Component map](component-map.md) covers Level 2 major components.
3. [Data flows](data-flows.md) covers Level 3 session, workspace, Project Truth, and knowledge flows.
4. [Implementation map](implementation-map.md) covers Level 4 ownership and code locations.
5. [Architecture progress](progress.md) shows implemented, active, and planned architecture areas.
6. [Provenance Engine boundary](provenance-engine/README.md) records the independent package boundary inside the monorepo.

## Legend

- CURRENT means implemented or merged in the imported repository state or active bmux mainline.
- ACTIVE means open/in-progress migration or product work recorded by Project Truth or an open PR.
- PLANNED means target architecture recorded in Project Truth or authored design docs.
- EXTERNAL means a provider, service, repository, account system, or protocol outside the monorepo.

Do not encode important meaning by color alone. Mermaid diagrams use labels that
include the status text.

