# Provenance Engine Current Status

The authoritative current project facts are generated from manifests:

- [Project status](generated/project-status.md)
- [Ownership boundary](generated/ownership-boundary.md)
- [Repository status](generated/repository-status.md)

Do not update this file with active gates, milestone state, current caveats, or
release state. Update the appropriate manifest under `project/`, regenerate
with `./scripts/project-docs generate`, and verify with
`./scripts/project-docs check`.

## Authored Context

- Platform north star: `docs/reference-architecture.md`
- Implemented architecture and V1 boundaries: `docs/architecture.md`
- Product roadmap and sequencing guidance: `docs/roadmap.md`
- Technical adopter contract: `docs/integration-contract.md`
- Cross-repository bmux integration roadmap: `docs/bmux-integration-roadmap.md`

## Historical Evidence

The prior current-status page mixed current facts with historical verification
notes. Historical evidence remains in:

- `docs/session-tree-read-slice-completion.md`
- `docs/file-explanation-readiness-slice-completion.md`
- `docs/current-context-readiness-slice-completion.md`
- `docs/write-side-validation-milestone.md`
- `docs/v1-boundary-review.md`
