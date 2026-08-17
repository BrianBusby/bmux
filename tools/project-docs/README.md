# Project Docs Tool

This is the canonical implementation for Project Truth manifest validation and
generated documentation.

## Setup

Install the pinned tool dependencies into a repository-local virtual
environment:

```bash
python3 -m venv .venv-project-docs
.venv-project-docs/bin/python -m pip install -r tools/project-docs/requirements.txt
```

The repository wrappers use `.venv-project-docs/bin/python` when it exists;
otherwise they use `python3` and fail clearly if dependencies are missing.

## Commands

```bash
./scripts/project-docs validate
./scripts/project-docs generate
./scripts/project-docs check
./scripts/project-docs ci
```

`validate` checks JSON Schemas plus semantic invariants that schemas cannot
express cleanly. `generate` validates first, then rewrites only files under
`docs/generated/`. `check` renders into a temporary directory and compares the
result with committed generated files without modifying the working tree.

`ci` is the non-interactive, read-only gate for GitHub Actions. It validates
schemas, named invariants, generated-document freshness, bounded authored-doc
drift, and read-only GitHub evidence. It exits nonzero for schema, generation,
invariant, GitHub, and authored-doc failures and prefixes each error with a
stable category such as `[schema:...]`, `[generation:...]`, `[invariant:...]`,
`[github:...]`, or `[authored-doc:...]`.

GitHub evidence verification uses `GITHUB_TOKEN` or `GH_TOKEN` when present and
falls back to unauthenticated public API reads. Missing evidence, contradictory
GitHub state, authentication failures, rate limits, and network failures are
reported distinctly. `--skip-github` is reserved for offline diagnosis and unit
tests, not CI.

The bmux wrapper resolves this canonical tool from the monorepo root at
`tools/project-docs`. `PROJECT_TRUTH_TOOL_ROOT` remains available for local tool
development and may point either to a repository root containing
`tools/project-docs` or directly to a `tools/project-docs` directory.
