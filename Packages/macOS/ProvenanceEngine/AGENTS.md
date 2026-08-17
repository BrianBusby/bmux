# Provenance Engine Agent Notes

This package is the Provenance Engine component inside the bmux monorepo. Keep
the package architecturally independent: PE code may depend on its public
contracts and implementation modules, but it must not import bmux UI/runtime
internals.

## Project-State Rule

When implementation changes a milestone, gate, ownership boundary, persistence
policy, current slice, release state, or known caveat, update the appropriate
file under the monorepo root `project/` directory and regenerate documentation.

Do not manually edit `docs/generated/`.

A project-status change is incomplete until:

1. the manifest is updated;
2. `./scripts/project-docs validate` passes;
3. `./scripts/project-docs generate` has been run;
4. `./scripts/project-docs check` passes;
5. authored documents do not contradict the generated state.

CI enforcement runs the read-only `./scripts/project-docs ci` gate. It validates
schema, generation freshness, named invariants, authored-doc drift, and GitHub
evidence without writing repository state.
