#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

import jsonschema
import yaml


TOOL_ROOT = Path(__file__).resolve().parent
SCHEMA_ROOT = TOOL_ROOT.parent.parent / "project" / "schema"
GENERATED_FILES = (
    "project-status.md",
    "ownership-boundary.md",
    "repository-status.md",
)
GENERATED_WARNING = "GENERATED FILE. DO NOT EDIT MANUALLY."

DELIVERY_STATUSES = ("proposed", "draft", "open", "merged", "closed", "superseded")
ACCEPTANCE_STATUSES = (
    "proposed",
    "implemented",
    "under_observation",
    "accepted",
    "rejected",
    "superseded",
)

REPOSITORY_LABELS = {
    "provenance_engine": "Provenance Engine",
    "bmux": "Bmux",
}

RESPONSIBILITY_LABELS = {
    "durable_evidence": "Durable evidence",
    "deterministic_current_state": "Deterministic Current State",
    "schema_compatibility": "Schema compatibility",
    "bounded_provenance_queries": "Bounded provenance queries",
    "workflow_observation": "Workflow observation",
    "execution_telemetry": "Execution telemetry",
    "capture_policy": "Capture policy",
    "runtime_orchestration": "Runtime orchestration",
    "user_interface": "User interface",
    "presentation": "Presentation",
}


class ProjectDocsError(Exception):
    pass


class NoTimestampSafeLoader(yaml.SafeLoader):
    pass


for first_letter, resolvers in list(NoTimestampSafeLoader.yaml_implicit_resolvers.items()):
    NoTimestampSafeLoader.yaml_implicit_resolvers[first_letter] = [
        (tag, regexp)
        for tag, regexp in resolvers
        if tag != "tag:yaml.org,2002:timestamp"
    ]


def load_yaml(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return yaml.load(handle, Loader=NoTimestampSafeLoader)
    except FileNotFoundError as exc:
        raise ProjectDocsError(f"{path}: file does not exist") from exc
    except yaml.YAMLError as exc:
        raise ProjectDocsError(f"{path}: YAML parse failed: {exc}") from exc


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_schema(document: Any, schema_path: Path, document_path: Path) -> None:
    schema = load_json(schema_path)
    validator = jsonschema.Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(document), key=lambda err: list(err.path))
    if errors:
        lines = []
        for error in errors:
            field = ".".join(str(part) for part in error.path) or "<root>"
            lines.append(f"{document_path}: {field}: {error.message}")
        raise ProjectDocsError("\n".join(lines))


def resolve_shared_state(repo_root: Path, explicit_shared_state: str | None) -> tuple[Path, dict[str, Any] | None]:
    if explicit_shared_state:
        return Path(explicit_shared_state).expanduser().resolve(), None

    local_shared = repo_root / "project" / "project-state.yaml"
    if local_shared.exists():
        return local_shared, None

    pointer_path = repo_root / "project" / "shared-project-source.yaml"
    pointer = load_yaml(pointer_path)
    validate_schema(pointer, SCHEMA_ROOT / "shared-project-source.schema.json", pointer_path)

    env_path = os.environ.get("PROJECT_TRUTH_SHARED_STATE")
    if env_path:
        return Path(env_path).expanduser().resolve(), pointer

    repo_name = pointer["repository"].split("/", 1)[1]
    sibling = repo_root.parent / repo_name / pointer["path"]
    if sibling.exists():
        return sibling.resolve(), pointer

    raise ProjectDocsError(
        f"{repo_root}: cannot resolve canonical shared manifest. Set "
        "PROJECT_TRUTH_SHARED_STATE=/path/to/project-state.yaml or keep a sibling "
        f"checkout at ../{repo_name}/{pointer['path']}."
    )


def load_inputs(repo_root: Path, explicit_shared_state: str | None = None) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    shared_path, pointer = resolve_shared_state(repo_root, explicit_shared_state)
    repo_status_path = repo_root / "project" / "repo-status.yaml"
    pointer_path = repo_root / "project" / "shared-project-source.yaml"

    shared = load_yaml(shared_path)
    repo_status = load_yaml(repo_status_path)

    validate_schema(shared, SCHEMA_ROOT / "project-state.schema.json", shared_path)
    validate_schema(repo_status, SCHEMA_ROOT / "repo-status.schema.json", repo_status_path)
    if pointer_path.exists():
        if pointer is None:
            pointer = load_yaml(pointer_path)
            validate_schema(pointer, SCHEMA_ROOT / "shared-project-source.schema.json", pointer_path)

    semantic_validate(shared, repo_status, repo_status_path)

    return {
        "repo_root": repo_root,
        "shared_path": shared_path,
        "repo_status_path": repo_status_path,
        "pointer": pointer,
        "shared": shared,
        "repo_status": repo_status,
    }


def semantic_validate(shared: dict[str, Any], repo_status: dict[str, Any], repo_status_path: Path) -> None:
    errors: list[str] = []

    milestone_ids = [item["id"] for item in shared.get("milestones", [])]
    duplicate_milestones = sorted({item for item in milestone_ids if milestone_ids.count(item) > 1})
    for milestone_id in duplicate_milestones:
        errors.append(f"project/project-state.yaml: milestones: duplicate milestone id '{milestone_id}'")

    caveat_ids = [item["id"] for item in shared.get("caveats", [])]
    duplicate_caveats = sorted({item for item in caveat_ids if caveat_ids.count(item) > 1})
    for caveat_id in duplicate_caveats:
        errors.append(f"project/project-state.yaml: caveats: duplicate caveat id '{caveat_id}'")

    gate = shared.get("cross_repository", {}).get("active_gate")
    if gate and gate.get("status") != "active":
        errors.append("project/project-state.yaml: cross_repository.active_gate must have status active")

    for index, milestone in enumerate(shared.get("milestones", [])):
        path = f"project/project-state.yaml: milestones[{index}] ({milestone.get('id')})"
        if milestone["acceptance_status"] == "accepted":
            evidence = milestone.get("evidence", {})
            if not evidence.get("commits") and not evidence.get("pull_requests"):
                errors.append(f"{path}: accepted milestone must have commit or pull request evidence")
            if not milestone.get("accepted_at") and not milestone.get("acceptance_reason"):
                errors.append(f"{path}: accepted milestone must have accepted_at or acceptance_reason")
            if milestone["delivery_status"] in ("proposed", "draft"):
                errors.append(f"{path}: accepted milestone cannot have delivery_status {milestone['delivery_status']}")

    ownership = shared.get("ownership", {})
    if ownership.get("durable_evidence") != "provenance_engine":
        errors.append("project/project-state.yaml: durable_evidence must be owned by provenance_engine")
    if ownership.get("deterministic_current_state") != "provenance_engine":
        errors.append("project/project-state.yaml: deterministic_current_state must be owned by provenance_engine")
    if ownership.get("execution_telemetry") != "bmux":
        errors.append("project/project-state.yaml: execution_telemetry must be owned by bmux")

    policies = shared.get("policies", {})
    checkpoints = policies.get("automatic_checkpoint_diagnostics", {})
    if policies.get("raw_execution_telemetry_persisted") is not False:
        errors.append("project/project-state.yaml: raw_execution_telemetry_persisted must be false for this slice")
    if checkpoints.get("status") == "not_implemented" and checkpoints.get("selected_for_implementation"):
        errors.append("project/project-state.yaml: not_implemented automatic checkpoints cannot be selected")

    if "ownership" in repo_status:
        errors.append(f"{repo_status_path}: repo-local manifest cannot redefine shared ownership")

    repository = repo_status.get("repository")
    if repository == "BrianBusby/bmux":
        capabilities = set(repo_status.get("local_capabilities", {}).keys())
        if "durable_evidence" in capabilities or "deterministic_current_state" in capabilities:
            errors.append(f"{repo_status_path}: bmux cannot claim durable evidence or Current State ownership")
    if repository == "BrianBusby/provenance-engine" and "execution_telemetry" in repo_status:
        errors.append(f"{repo_status_path}: Provenance Engine cannot claim live execution telemetry ownership")

    active_slice = repo_status.get("current_work", {}).get("active_slice")
    if isinstance(active_slice, dict):
        selected = active_slice.get("id") is not None or active_slice.get("state") not in (None, "none_selected")
        if selected and not active_slice.get("owner"):
            errors.append(f"{repo_status_path}: selected current slice must have owner")

    if errors:
        raise ProjectDocsError("\n".join(errors))


def titleize(value: str) -> str:
    return value.replace("_", " ").replace("-", " ").title()


def owner_label(owner: str) -> str:
    return REPOSITORY_LABELS.get(owner, titleize(owner))


def status_label(value: Any) -> str:
    if value is None:
        return "None"
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value).replace("_", " ")


def evidence_text(evidence: dict[str, Any]) -> str:
    parts: list[str] = []
    for commit in evidence.get("commits", []):
        parts.append(f"{commit['repository']}@{commit['sha'][:12]}")
    for pr in evidence.get("pull_requests", []):
        parts.append(f"{pr['repository']}#{pr['number']}")
    return ", ".join(parts) if parts else "None recorded"


def generated_header(context: dict[str, Any]) -> str:
    repo_root = context["repo_root"]
    shared_path = context["shared_path"]
    repo_status_path = context["repo_status_path"]
    pointer = context["pointer"]
    sources = []
    if pointer:
        sources.append(f"{pointer['repository']}:{pointer['path']}")
        sources.append("project/shared-project-source.yaml")
    else:
        sources.append(path_relative(repo_root, shared_path))
    sources.append(path_relative(repo_root, repo_status_path))

    source_lines = "\n".join(f"- {source}" for source in sources)
    return (
        "<!--\n"
        f"{GENERATED_WARNING}\n"
        "Sources:\n"
        f"{source_lines}\n"
        "Regenerate with: ./scripts/project-docs generate\n"
        "-->\n\n"
    )


def path_relative(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.name


def render_project_status(context: dict[str, Any]) -> str:
    shared = context["shared"]
    lines = [generated_header(context), "# Project Status", ""]
    gate = shared["cross_repository"]["active_gate"]
    lines.extend(
        [
            "## Active Gate",
            "",
            f"- ID: `{gate['id']}`",
            f"- Title: {gate['title']}",
            f"- Status: {status_label(gate['status'])}",
            "",
            "## Shared Milestones",
            "",
            "| Milestone | Owner | Delivery | Acceptance | Evidence |",
            "| --- | --- | --- | --- | --- |",
        ]
    )
    for milestone in shared["milestones"]:
        lines.append(
            "| "
            f"{milestone['title']} (`{milestone['id']}`) | "
            f"{owner_label(milestone['owner'])} | "
            f"{status_label(milestone['delivery_status'])} | "
            f"{status_label(milestone['acceptance_status'])} | "
            f"{evidence_text(milestone['evidence'])} |"
        )
    lines.extend(["", "## Open Shared Caveats", ""])
    open_caveats = [c for c in shared["caveats"] if c["status"] in ("open", "monitoring")]
    if open_caveats:
        lines.extend(["| Caveat | Owner | Status | Issue |", "| --- | --- | --- | --- |"])
        for caveat in open_caveats:
            issue = caveat.get("issue")
            issue_text = f"{issue['repository']}#{issue['number']}" if issue else ""
            lines.append(
                f"| {caveat['title']} (`{caveat['id']}`) | "
                f"{owner_label(caveat['owner'])} | {status_label(caveat['status'])} | {issue_text} |"
            )
    else:
        lines.append("None.")

    checkpoints = shared["policies"]["automatic_checkpoint_diagnostics"]
    lines.extend(
        [
            "",
            "## Automatic Checkpoints",
            "",
            f"- Implementation status: {status_label(checkpoints['status'])}",
            f"- Selected for implementation: {status_label(checkpoints['selected_for_implementation'])}",
        ]
    )
    if checkpoints["status"] == "not_implemented":
        lines.append("- Operational statement: automatic diagnostic checkpoints are not operational.")
    return "\n".join(lines).rstrip() + "\n"


def render_ownership_boundary(context: dict[str, Any]) -> str:
    shared = context["shared"]
    lines = [
        generated_header(context),
        "# Ownership Boundary",
        "",
        "| Responsibility | Owner |",
        "| --- | --- |",
    ]
    for key in sorted(shared["ownership"]):
        lines.append(f"| {RESPONSIBILITY_LABELS.get(key, titleize(key))} | {owner_label(shared['ownership'][key])} |")

    policies = shared["policies"]
    checkpoints = policies["automatic_checkpoint_diagnostics"]
    lines.extend(
        [
            "",
            "## Durable Versus Ephemeral Policy",
            "",
            "| Policy | Value |",
            "| --- | --- |",
            f"| Raw execution telemetry persisted | {status_label(policies['raw_execution_telemetry_persisted'])} |",
            f"| Live projection persisted | {status_label(policies['live_projection_persisted'])} |",
            f"| Narrow lifecycle projection enabled | {status_label(policies['narrow_lifecycle_projection_enabled'])} |",
            f"| Automatic checkpoint diagnostics | {status_label(checkpoints['status'])} |",
            f"| Automatic checkpoint diagnostics selected | {status_label(checkpoints['selected_for_implementation'])} |",
        ]
    )
    return "\n".join(lines).rstrip() + "\n"


def render_repository_status(context: dict[str, Any]) -> str:
    repo = context["repo_status"]
    lines = [
        generated_header(context),
        "# Repository Status",
        "",
        f"Repository: `{repo['repository']}`",
        "",
        "## Current Work",
        "",
    ]
    active_slice = repo["current_work"].get("active_slice")
    if isinstance(active_slice, dict) and active_slice.get("id"):
        lines.extend(
            [
                f"- Active slice: {active_slice['title']} (`{active_slice['id']}`)",
                f"- Slice state: {status_label(active_slice['state'])}",
                f"- Owner: {active_slice.get('owner', '')}",
            ]
        )
    else:
        lines.append("- Active slice: none selected")
    if repo["current_work"].get("state"):
        lines.append(f"- Repository state: {status_label(repo['current_work']['state'])}")

    release = repo["release"]
    lines.extend(
        [
            "",
            "## Release",
            "",
            f"- Latest tag: {release['latest_tag'] if release['latest_tag'] else 'None'}",
            f"- Release status: {status_label(release['release_status'])}",
        ]
    )

    for section in ("local_capabilities", "execution_telemetry"):
        if section in repo:
            lines.extend(["", f"## {titleize(section)}", "", "| Capability | State |", "| --- | --- |"])
            for key in sorted(repo[section]):
                lines.append(f"| {titleize(key)} | {status_label(repo[section][key])} |")

    lines.extend(["", "## Local Caveats", ""])
    caveats = repo.get("local_caveats", [])
    if caveats:
        lines.extend(["| Caveat | Status |", "| --- | --- |"])
        for caveat in caveats:
            lines.append(f"| `{caveat['id']}` | {status_label(caveat['status'])} |")
    else:
        lines.append("None.")
    return "\n".join(lines).rstrip() + "\n"


def render_all(context: dict[str, Any]) -> dict[str, str]:
    return {
        "project-status.md": render_project_status(context),
        "ownership-boundary.md": render_ownership_boundary(context),
        "repository-status.md": render_repository_status(context),
    }


def write_generated(context: dict[str, Any], output_root: Path | None = None) -> None:
    repo_root = context["repo_root"]
    docs_root = output_root if output_root else repo_root / "docs" / "generated"
    docs_root.mkdir(parents=True, exist_ok=True)
    for filename, content in render_all(context).items():
        (docs_root / filename).write_text(content, encoding="utf-8")


def check_generated(context: dict[str, Any]) -> None:
    repo_root = context["repo_root"]
    committed_root = repo_root / "docs" / "generated"
    stale: list[str] = []
    with tempfile.TemporaryDirectory(prefix="project-docs-") as tmp:
        tmp_root = Path(tmp)
        write_generated(context, tmp_root)
        for filename in GENERATED_FILES:
            committed = committed_root / filename
            generated = tmp_root / filename
            if not committed.exists():
                stale.append(str(committed))
                continue
            committed_text = committed.read_text(encoding="utf-8")
            generated_text = generated.read_text(encoding="utf-8")
            if committed_text != generated_text:
                stale.append(str(committed))
                diff = difflib.unified_diff(
                    committed_text.splitlines(),
                    generated_text.splitlines(),
                    fromfile=str(committed),
                    tofile=f"generated/{filename}",
                    lineterm="",
                )
                sys.stderr.write("\n".join(diff) + "\n")
    if stale:
        formatted = "\n".join(f"- {path}" for path in stale)
        raise ProjectDocsError(f"Generated documentation is stale:\n{formatted}")


def replace_generated_block(text: str, block_name: str, replacement: str) -> str:
    start = f"<!-- BEGIN GENERATED: {block_name} -->"
    end = f"<!-- END GENERATED: {block_name} -->"
    pattern = re.compile(
        rf"({re.escape(start)})(.*?)(\n?{re.escape(end)})",
        flags=re.DOTALL,
    )
    match = pattern.search(text)
    if not match:
        raise ProjectDocsError(f"generated block '{block_name}' not found")
    body = "\n" + replacement.rstrip()
    return pattern.sub(rf"\1{body}\3", text, count=1)


def ensure_generated_warning(repo_root: Path) -> None:
    for filename in GENERATED_FILES:
        path = repo_root / "docs" / "generated" / filename
        if not path.exists():
            raise ProjectDocsError(f"{path}: generated file is missing")
        first_block = path.read_text(encoding="utf-8")[:300]
        if GENERATED_WARNING not in first_block:
            raise ProjectDocsError(f"{path}: generated-file warning is missing")


def command_validate(args: argparse.Namespace) -> None:
    context = load_inputs(Path(args.repo_root), args.shared_state)
    ensure_generated_warning(context["repo_root"]) if args.require_generated else None


def command_generate(args: argparse.Namespace) -> None:
    context = load_inputs(Path(args.repo_root), args.shared_state)
    write_generated(context)


def command_check(args: argparse.Namespace) -> None:
    context = load_inputs(Path(args.repo_root), args.shared_state)
    ensure_generated_warning(context["repo_root"])
    check_generated(context)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and render project truth documentation.")
    parser.add_argument("command", choices=("validate", "generate", "check"))
    parser.add_argument("--repo-root", default=os.getcwd())
    parser.add_argument("--shared-state", default=os.environ.get("PROJECT_TRUTH_SHARED_STATE"))
    parser.add_argument("--require-generated", action="store_true")
    args = parser.parse_args(argv)

    try:
        if args.command == "validate":
            command_validate(args)
        elif args.command == "generate":
            command_generate(args)
        elif args.command == "check":
            command_check(args)
        return 0
    except ProjectDocsError as exc:
        sys.stderr.write(f"project-docs: {exc}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
