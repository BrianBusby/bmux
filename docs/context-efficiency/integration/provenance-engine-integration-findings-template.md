# Provenance Engine Integration Findings Template

Use this template after each bmux adoption slice before choosing the next
migration target.

## Slice

- Date:
- bmux branch:
- bmux commit:
- provenance-engine version:
- Engine modules imported:
- Factory or construction path:
- Engine query or write API:
- bmux-owned presentation/adapters:
- Legacy code removed:
- Legacy code intentionally retained:

## Findings

- Was package linking straightforward?
- Did the pinned engine version work cleanly?
- Was `ProvenanceEngineClientFactory` sufficient?
- Was database-location selection straightforward?
- Did the external error model map cleanly into bmux behavior?
- Were output ordering and limits preserved?
- Could tests seed data exclusively through public APIs?
- Did any test still need direct engine-table access?
- Did bmux need fields or behavior missing from the contracts?
- Did any contract contain bmux-specific assumptions?
- Was performance acceptable for the command or workflow?
- Was rollback possible through a scoped Git revert?
- What legacy code became deletable?
- What code had to remain, and why?

## Classification

Choose one:

- Adoption successful - continue.
- Adoption successful with minor contract changes.
- Boundary problem - stop and revise.
- Implementation problem - fix before continuing.

## Next Recommendation

- Recommended next migration path:
- Required engine contract changes:
- Required bmux cleanup before migration:
- Risks or unresolved questions:
