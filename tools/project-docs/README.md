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
```

`validate` checks JSON Schemas plus semantic invariants that schemas cannot
express cleanly. `generate` validates first, then rewrites only files under
`docs/generated/`. `check` renders into a temporary directory and compares the
result with committed generated files without modifying the working tree.

The bmux wrapper resolves this canonical tool through `PROJECT_TRUTH_TOOL_ROOT`
or an expected sibling checkout at `../provenance-engine/tools/project-docs`.
