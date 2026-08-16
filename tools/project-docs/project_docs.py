#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import http.client
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol

import jsonschema
import yaml


TOOL_ROOT = Path(__file__).resolve().parent
SCHEMA_ROOT = TOOL_ROOT.parent.parent / "project" / "schema"
GENERATED_FILES = (
    "project-status.md",
    "nested-roadmap.md",
    "ownership-boundary.md",
    "repository-status.md",
)
GENERATED_WARNING = "GENERATED FILE. DO NOT EDIT MANUALLY."
CANONICAL_SHARED_REPOSITORY = "BrianBusby/provenance-engine"
CANONICAL_SHARED_PATH = "project/project-state.yaml"
PROVIDER_ERROR = object()

DELIVERY_STATUSES = ("proposed", "draft", "open", "merged", "closed", "superseded")
ACCEPTANCE_STATUSES = (
    "proposed",
    "implemented",
    "under_observation",
    "accepted",
    "rejected",
    "superseded",
)
ROADMAP_REFERENCE_FIELDS = ("depends_on", "enables", "sequence_after", "sequence_before")
ROADMAP_PARENT_KINDS = {
    "project": None,
    "program": "project",
    "phase": "program",
    "milestone": "phase",
    "slice": "milestone",
}

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


@dataclass(frozen=True)
class ValidationIssue:
    category: str
    name: str
    path: str
    message: str

    def sort_key(self) -> tuple[str, str, str, str]:
        return (self.category, self.name, self.path, self.message)

    def format(self) -> str:
        label = self.category if not self.name else f"{self.category}:{self.name}"
        return f"[{label}] {self.path}: {self.message}"


@dataclass(frozen=True)
class PullRequestEvidence:
    state: str
    draft: bool
    merged: bool
    owner_login: str | None = None
    owner_url: str | None = None


@dataclass(frozen=True)
class IssueEvidence:
    state: str


@dataclass(frozen=True)
class TagEvidence:
    target_sha: str


class GitHubProviderError(Exception):
    def __init__(self, kind: str, message: str):
        super().__init__(message)
        self.kind = kind
        self.message = message


class GitHubEvidenceProvider(Protocol):
    def repository_exists(self, repository: str) -> bool: ...
    def commit_exists(self, repository: str, sha: str) -> bool: ...
    def pull_request(self, repository: str, number: int) -> PullRequestEvidence | None: ...
    def issue(self, repository: str, number: int) -> IssueEvidence | None: ...
    def tag(self, repository: str, tag: str) -> TagEvidence | None: ...
    def release_exists(self, repository: str, tag: str) -> bool: ...


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


class GitHubRestEvidenceProvider:
    def __init__(self, token: str | None = None, api_url: str | None = None):
        self.token = token
        self.api_url = (api_url or "https://api.github.com").rstrip("/")

    def _get(self, path: str) -> Any | None:
        request = urllib.request.Request(f"{self.api_url}{path}")
        request.add_header("Accept", "application/vnd.github+json")
        request.add_header("X-GitHub-Api-Version", "2022-11-28")
        request.add_header("User-Agent", "project-truth-ci")
        if self.token:
            request.add_header("Authorization", f"Bearer {self.token}")
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                payload = response.read().decode("utf-8")
                return json.loads(payload) if payload else None
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            if exc.code == 404:
                return None
            if exc.code in (401, 403):
                remaining = exc.headers.get("X-RateLimit-Remaining")
                lowered = body.lower()
                if remaining == "0" or "rate limit" in lowered:
                    raise GitHubProviderError("rate_limit", f"GitHub API rate limit hit for {path}") from exc
                raise GitHubProviderError("auth", f"GitHub API denied access to {path}: HTTP {exc.code}") from exc
            raise GitHubProviderError("network", f"GitHub API request failed for {path}: HTTP {exc.code}") from exc
        except (urllib.error.URLError, TimeoutError, http.client.HTTPException) as exc:
            raise GitHubProviderError("network", f"GitHub API request failed for {path}: {exc}") from exc

    def repository_exists(self, repository: str) -> bool:
        return self._get(f"/repos/{quote_slug(repository)}") is not None

    def commit_exists(self, repository: str, sha: str) -> bool:
        return self._get(f"/repos/{quote_slug(repository)}/commits/{urllib.parse.quote(sha)}") is not None

    def pull_request(self, repository: str, number: int) -> PullRequestEvidence | None:
        data = self._get(f"/repos/{quote_slug(repository)}/pulls/{number}")
        if data is None:
            return None
        user = data.get("user", {}) if isinstance(data, dict) else {}
        return PullRequestEvidence(
            state=str(data.get("state", "")),
            draft=bool(data.get("draft")),
            merged=bool(data.get("merged_at")),
            owner_login=str(user.get("login")) if user.get("login") else None,
            owner_url=str(user.get("html_url")) if user.get("html_url") else None,
        )

    def issue(self, repository: str, number: int) -> IssueEvidence | None:
        data = self._get(f"/repos/{quote_slug(repository)}/issues/{number}")
        if data is None:
            return None
        return IssueEvidence(state=str(data.get("state", "")))

    def tag(self, repository: str, tag: str) -> TagEvidence | None:
        data = self._get(f"/repos/{quote_slug(repository)}/git/ref/tags/{urllib.parse.quote(tag, safe='')}")
        if data is None:
            return None
        target = data.get("object", {}) if isinstance(data, dict) else {}
        return TagEvidence(target_sha=str(target.get("sha", "")))

    def release_exists(self, repository: str, tag: str) -> bool:
        return self._get(f"/repos/{quote_slug(repository)}/releases/tags/{urllib.parse.quote(tag, safe='')}") is not None


def quote_slug(repository: str) -> str:
    owner, name = repository.split("/", 1)
    return f"{urllib.parse.quote(owner, safe='')}/{urllib.parse.quote(name, safe='')}"


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
    issues = schema_issues(document, schema_path, document_path)
    if issues:
        raise_issues(issues)


def schema_issues(document: Any, schema_path: Path, document_path: Path) -> list[ValidationIssue]:
    schema = load_json(schema_path)
    validator = jsonschema.Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(document), key=lambda err: list(err.path))
    issues: list[ValidationIssue] = []
    for error in errors:
        field = ".".join(str(part) for part in error.path) or "<root>"
        issues.append(ValidationIssue("schema", schema_path.name, f"{document_path}:{field}", error.message))
    return issues


def raise_issues(issues: list[ValidationIssue]) -> None:
    if not issues:
        return
    formatted = "\n".join(issue.format() for issue in sorted(issues, key=lambda item: item.sort_key()))
    raise ProjectDocsError(formatted)


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
    issues = invariant_issues(shared, [repo_status], {repo_status.get("repository", "<unknown>"): repo_status_path})
    raise_issues(issues)


def roadmap_nodes(shared: dict[str, Any]) -> list[dict[str, Any]]:
    return shared.get("roadmap", {}).get("nodes", [])


def roadmap_node_path(index: int, node: dict[str, Any]) -> str:
    return f"project/project-state.yaml:roadmap.nodes[{index}] ({node.get('id')})"


def has_evidence_record(evidence: dict[str, Any] | None) -> bool:
    if not evidence:
        return False
    return bool(evidence.get("commits") or evidence.get("pull_requests"))


def first_directed_cycle(edges: dict[str, list[str]]) -> list[str] | None:
    visited: set[str] = set()
    stack: list[str] = []
    in_stack: set[str] = set()

    def visit(node: str) -> list[str] | None:
        if node in in_stack:
            return stack[stack.index(node):] + [node]
        if node in visited:
            return None

        stack.append(node)
        in_stack.add(node)
        for child in sorted(edges.get(node, [])):
            if child not in edges:
                continue
            cycle = visit(child)
            if cycle:
                return cycle
        stack.pop()
        in_stack.remove(node)
        visited.add(node)
        return None

    for node in sorted(edges):
        cycle = visit(node)
        if cycle:
            return cycle
    return None


def invariant_issues(
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    repo_status_paths: dict[str, Path],
) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []

    def add(name: str, path: str, message: str) -> None:
        issues.append(ValidationIssue("invariant", name, path, message))

    repo_status = repo_statuses[0] if repo_statuses else {}
    repo_status_path = repo_status_paths.get(repo_status.get("repository", ""), Path("project/repo-status.yaml"))

    milestone_ids = [item["id"] for item in shared.get("milestones", [])]
    duplicate_milestones = sorted({item for item in milestone_ids if milestone_ids.count(item) > 1})
    for milestone_id in duplicate_milestones:
        add("unique_milestone_ids", "project/project-state.yaml:milestones", f"duplicate milestone id '{milestone_id}'")

    caveat_ids = [item["id"] for item in shared.get("caveats", [])]
    duplicate_caveats = sorted({item for item in caveat_ids if caveat_ids.count(item) > 1})
    for caveat_id in duplicate_caveats:
        add("unique_caveat_ids", "project/project-state.yaml:caveats", f"duplicate caveat id '{caveat_id}'")

    nodes = roadmap_nodes(shared)
    node_ids = [item["id"] for item in nodes]
    duplicate_nodes = sorted({item for item in node_ids if node_ids.count(item) > 1})
    for node_id in duplicate_nodes:
        add("unique_roadmap_node_ids", "project/project-state.yaml:roadmap.nodes", f"duplicate roadmap node id '{node_id}'")

    node_by_id = {node["id"]: node for node in nodes}
    milestone_id_set = set(milestone_ids)
    hierarchy_edges: dict[str, list[str]] = {node_id: [] for node_id in node_by_id}
    ordering_edges: dict[str, list[str]] = {node_id: [] for node_id in node_by_id}

    for index, node in enumerate(nodes):
        path = roadmap_node_path(index, node)
        node_id = node["id"]
        kind = node["kind"]
        parent = node.get("parent")

        if node["owner"] not in node.get("repositories", []):
            add("roadmap_owner_in_repositories", path, "roadmap node owner must be listed in repositories")

        expected_parent_kind = ROADMAP_PARENT_KINDS[kind]
        if expected_parent_kind is None:
            if parent:
                add("roadmap_project_has_no_parent", path, "project roadmap node must not have a parent")
        elif not parent:
            add("roadmap_parent_required", path, f"{kind} roadmap node must have a parent")
        elif parent not in node_by_id:
            add("roadmap_parent_exists", path, f"parent '{parent}' does not exist")
        else:
            parent_kind = node_by_id[parent]["kind"]
            if parent_kind != expected_parent_kind:
                add("roadmap_parent_kind", path, f"{kind} parent must be {expected_parent_kind}, not {parent_kind}")
            hierarchy_edges[node_id].append(parent)

        mirrored = node.get("mirrors_milestone")
        if mirrored and mirrored not in milestone_id_set:
            add("roadmap_mirrors_existing_milestone", path, f"mirrors_milestone '{mirrored}' does not exist")

        for field in ROADMAP_REFERENCE_FIELDS:
            for ref_id in node.get(field, []):
                if ref_id == node_id:
                    add("roadmap_reference_not_self", path, f"{field} cannot reference the node itself")
                if ref_id not in node_by_id:
                    add("roadmap_reference_exists", path, f"{field} reference '{ref_id}' does not exist")
                    continue
                if field == "depends_on":
                    ordering_edges[ref_id].append(node_id)
                elif field == "enables":
                    ordering_edges[node_id].append(ref_id)
                elif field == "sequence_after":
                    ordering_edges[ref_id].append(node_id)
                elif field == "sequence_before":
                    ordering_edges[node_id].append(ref_id)

        for ref_id in node.get("parallelism", {}).get("with", []):
            if ref_id == node_id:
                add("roadmap_reference_not_self", path, "parallelism.with cannot reference the node itself")
            if ref_id not in node_by_id:
                add("roadmap_reference_exists", path, f"parallelism.with reference '{ref_id}' does not exist")

        if kind == "slice":
            status = node["status"]
            delivery_status = node.get("delivery_status")
            acceptance_status = node.get("acceptance_status")
            material_statuses = ("implemented", "accepted")
            is_materialized = status in material_statuses or acceptance_status in material_statuses
            if is_materialized and not has_evidence_record(node.get("evidence")):
                add("roadmap_slice_requires_evidence", path, "implemented or accepted roadmap slice must have commit or pull request evidence")
            if is_materialized and delivery_status in ("proposed", "draft"):
                add("roadmap_slice_delivery_not_draft", path, f"implemented or accepted roadmap slice cannot have delivery_status {delivery_status}")
            if status == "accepted" or acceptance_status == "accepted":
                if not node.get("accepted_at") and not node.get("acceptance_reason"):
                    add("roadmap_slice_requires_acceptance_evidence", path, "accepted roadmap slice must have accepted_at or acceptance_reason")
            if status == "planned":
                if node.get("completed_at") or node.get("accepted_at"):
                    add("roadmap_planned_slice_not_delivered", path, "planned roadmap slice must not carry completed_at or accepted_at")
                if delivery_status in ("merged", "closed") or acceptance_status in ("implemented", "accepted"):
                    add("roadmap_planned_slice_status_conflict", path, "planned roadmap slice cannot declare delivered or accepted status")

    hierarchy_cycle = first_directed_cycle(hierarchy_edges)
    if hierarchy_cycle:
        add("roadmap_parent_cycle", "project/project-state.yaml:roadmap.nodes", "roadmap parent cycle: " + " -> ".join(hierarchy_cycle))

    ordering_cycle = first_directed_cycle(ordering_edges)
    if ordering_cycle:
        add("roadmap_dependency_cycle", "project/project-state.yaml:roadmap.nodes", "roadmap dependency/sequence cycle: " + " -> ".join(ordering_cycle))

    gate = shared.get("cross_repository", {}).get("active_gate")
    if gate and gate.get("status") != "active":
        add("active_gate_is_active", "project/project-state.yaml:cross_repository.active_gate", "must have status active")

    for index, milestone in enumerate(shared.get("milestones", [])):
        path = f"project/project-state.yaml: milestones[{index}] ({milestone.get('id')})"
        if milestone["acceptance_status"] == "accepted":
            evidence = milestone.get("evidence", {})
            if not evidence.get("commits") and not evidence.get("pull_requests"):
                add("accepted_requires_evidence", path, "accepted milestone must have commit or pull request evidence")
            if not milestone.get("accepted_at") and not milestone.get("acceptance_reason"):
                add("accepted_requires_acceptance_evidence", path, "accepted milestone must have accepted_at or acceptance_reason")
            if milestone["delivery_status"] in ("proposed", "draft"):
                add("accepted_delivery_not_draft", path, f"accepted milestone cannot have delivery_status {milestone['delivery_status']}")
        if milestone["delivery_status"] == "merged" and milestone["acceptance_status"] == "accepted":
            if not milestone.get("accepted_at") and not milestone.get("acceptance_reason"):
                add("merged_not_automatically_accepted", path, "merged delivery must retain explicit acceptance evidence")
        if milestone["acceptance_status"] == "under_observation" and milestone.get("accepted_at"):
            add("observation_not_accepted", path, "under_observation milestone must not carry accepted_at")
        if milestone["delivery_status"] == "superseded" and milestone["acceptance_status"] not in ("superseded", "rejected"):
            add("superseded_not_active", path, "superseded delivery must not remain active or accepted")

    ownership = shared.get("ownership", {})
    if ownership.get("durable_evidence") != "provenance_engine":
        add("ownership_durable_evidence", "project/project-state.yaml:ownership.durable_evidence", "must be owned by provenance_engine")
    if ownership.get("deterministic_current_state") != "provenance_engine":
        add("ownership_current_state", "project/project-state.yaml:ownership.deterministic_current_state", "must be owned by provenance_engine")
    if ownership.get("execution_telemetry") != "bmux":
        add("ownership_execution_telemetry", "project/project-state.yaml:ownership.execution_telemetry", "must be owned by bmux")

    policies = shared.get("policies", {})
    checkpoints = policies.get("automatic_checkpoint_diagnostics", {})
    if policies.get("raw_execution_telemetry_persisted") is not False:
        add("raw_telemetry_not_persisted", "project/project-state.yaml:policies.raw_execution_telemetry_persisted", "must be false for this slice")
    if checkpoints.get("status") == "not_implemented" and checkpoints.get("selected_for_implementation"):
        add("automatic_checkpoints_unselected", "project/project-state.yaml:policies.automatic_checkpoint_diagnostics", "not_implemented automatic checkpoints cannot be selected")

    active_slices: list[tuple[str, dict[str, Any]]] = []
    for candidate in repo_statuses:
        repository = candidate.get("repository", "<unknown>")
        candidate_path = repo_status_paths.get(repository, Path("project/repo-status.yaml"))
        if "ownership" in candidate:
            add("local_cannot_redefine_ownership", str(candidate_path), "repo-local manifest cannot redefine shared ownership")

        if repository == "BrianBusby/bmux":
            capabilities = set(candidate.get("local_capabilities", {}).keys())
            if "durable_evidence" in capabilities or "deterministic_current_state" in capabilities:
                add("bmux_no_durable_ownership", str(candidate_path), "bmux cannot claim durable evidence or Current State ownership")
        if repository == "BrianBusby/provenance-engine" and "execution_telemetry" in candidate:
            add("provenance_no_runtime_capture", str(candidate_path), "Provenance Engine cannot claim live execution telemetry ownership")

        active_slice = candidate.get("current_work", {}).get("active_slice")
        current_state = candidate.get("current_work", {}).get("state")
        if isinstance(active_slice, dict):
            selected = active_slice.get("id") is not None or active_slice.get("state") not in (None, "none_selected")
            if selected:
                active_slices.append((repository, active_slice))
                if not active_slice.get("owner"):
                    add("active_slice_has_owner", str(candidate_path), "selected current slice must have owner")
                if current_state in ("observation", "none_selected"):
                    add("active_slice_matches_repo_state", str(candidate_path), "active implementation slice cannot coexist with observation or none_selected repository state")
            elif current_state == "active":
                add("no_active_slice_matches_repo_state", str(candidate_path), "active repository state must name an active slice")

        telemetry = candidate.get("execution_telemetry", {})
        if telemetry.get("automatic_checkpoint_scheduler") in ("implemented", "under_observation", "accepted"):
            if checkpoints.get("status") == "not_implemented" or not checkpoints.get("selected_for_implementation"):
                add("automatic_checkpoints_not_claimed", str(candidate_path), "automatic checkpoint scheduling cannot be claimed before the shared policy selects and implements it")
        if telemetry.get("raw_execution_telemetry_persisted") in ("implemented", "under_observation", "accepted"):
            if policies.get("raw_execution_telemetry_persisted") is False:
                add("raw_telemetry_not_persisted", str(candidate_path), "repo-local capabilities cannot claim durable raw execution telemetry persistence")

    if len(active_slices) > 1:
        repositories = ", ".join(f"{repo}:{slice_['id']}" for repo, slice_ in active_slices)
        add("no_conflicting_active_slices", "project/repo-status.yaml", f"multiple active implementation slices are selected: {repositories}")

    shared_caveats = {item["id"]: item for item in shared.get("caveats", [])}
    for candidate in repo_statuses:
        repository = candidate.get("repository", "<unknown>")
        candidate_path = repo_status_paths.get(repository, Path("project/repo-status.yaml"))
        for caveat in candidate.get("local_caveats", []):
            shared_caveat = shared_caveats.get(caveat["id"])
            if shared_caveat and shared_caveat["status"] in ("open", "monitoring") and caveat["status"] in ("resolved", "superseded"):
                add("known_caveats_do_not_disappear", str(candidate_path), f"local caveat {caveat['id']} cannot be {caveat['status']} while shared caveat is {shared_caveat['status']}")

    return issues


def validate_shared_source_issues(context: dict[str, Any]) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []
    repo_root = context["repo_root"]
    repo_status = context["repo_status"]
    pointer = context["pointer"]
    shared = context["shared"]
    shared_path = context["shared_path"]
    pointer_path = repo_root / "project" / "shared-project-source.yaml"

    def add(name: str, path: str, message: str) -> None:
        issues.append(ValidationIssue("invariant", name, path, message))

    if repo_status.get("repository") == "BrianBusby/bmux":
        if pointer is None:
            add("shared_source_declared", str(pointer_path), "bmux must declare the canonical shared project-state source")
        else:
            if pointer.get("repository") != CANONICAL_SHARED_REPOSITORY:
                add("shared_source_repository", str(pointer_path), f"repository must be {CANONICAL_SHARED_REPOSITORY}")
            if pointer.get("path") != CANONICAL_SHARED_PATH:
                add("shared_source_path", str(pointer_path), f"path must be {CANONICAL_SHARED_PATH}")
        unauthorized_copy = repo_root / "project" / "project-state.yaml"
        if unauthorized_copy.exists():
            add("no_copied_shared_manifest", str(unauthorized_copy), "bmux must resolve the shared manifest through shared-project-source.yaml instead of committing a copy")

    if pointer is not None:
        if shared.get("project", {}).get("shared_state_owner") != pointer.get("repository"):
            add("shared_source_owner_matches_manifest", str(pointer_path), "pointer repository must match project.shared_state_owner in the resolved shared manifest")
        if not shared_path.exists():
            add("shared_source_resolves", str(pointer_path), f"resolved shared manifest does not exist: {shared_path}")

    return issues


def collect_evidence_repositories(shared: dict[str, Any], repo_statuses: list[dict[str, Any]]) -> set[str]:
    repositories = {shared.get("project", {}).get("shared_state_owner", "")}
    repositories.update(repo.get("slug", "") for repo in shared.get("repositories", {}).values())
    repositories.update(repo.get("repository", "") for repo in repo_statuses)
    for milestone in shared.get("milestones", []):
        evidence = milestone.get("evidence", {})
        repositories.update(item.get("repository", "") for item in evidence.get("commits", []))
        repositories.update(item.get("repository", "") for item in evidence.get("pull_requests", []))
    for node in roadmap_nodes(shared):
        evidence = node.get("evidence", {})
        repositories.update(item.get("repository", "") for item in evidence.get("commits", []))
        repositories.update(item.get("repository", "") for item in evidence.get("pull_requests", []))
    for caveat in shared.get("caveats", []):
        issue = caveat.get("issue")
        if issue:
            repositories.add(issue.get("repository", ""))
    return {repo for repo in repositories if repo}


def github_evidence_issues(
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    provider: GitHubEvidenceProvider,
) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []

    def add(name: str, path: str, message: str) -> None:
        issues.append(ValidationIssue("github", name, path, message))

    def call(name: str, path: str, fn):
        try:
            return fn()
        except GitHubProviderError as exc:
            add(exc.kind, path, f"{name}: {exc.message}")
            return PROVIDER_ERROR

    for repository in sorted(collect_evidence_repositories(shared, repo_statuses)):
            exists = call("repository", repository, lambda repository=repository: provider.repository_exists(repository))
            if exists is False:
                add("missing_repository", repository, "repository does not exist or is not visible")

    def check_evidence(base_path: str, evidence: dict[str, Any], delivery: str | None, subject: str) -> None:
        for commit in evidence.get("commits", []):
            path = f"{base_path}.evidence.commits[{commit['repository']}@{commit['sha']}]"
            exists = call("commit", path, lambda commit=commit: provider.commit_exists(commit["repository"], commit["sha"]))
            if exists is False:
                add("missing_commit", path, "commit does not exist in the declared repository")
        for pr in evidence.get("pull_requests", []):
            path = f"{base_path}.evidence.pull_requests[{pr['repository']}#{pr['number']}]"
            state = call("pull request", path, lambda pr=pr: provider.pull_request(pr["repository"], pr["number"]))
            if state is PROVIDER_ERROR:
                continue
            if state is None:
                add("missing_pr", path, "pull request does not exist in the declared repository")
                continue
            if delivery == "merged" and not state.merged:
                add("pr_merged_state_mismatch", path, f"{subject} declares merged delivery but pull request is not merged")
            elif delivery == "open" and (state.state != "open" or state.draft):
                add("pr_open_state_mismatch", path, f"{subject} declares open delivery but pull request is not an open non-draft PR")
            elif delivery == "draft" and (state.state != "open" or not state.draft):
                add("pr_draft_state_mismatch", path, f"{subject} declares draft delivery but pull request is not an open draft PR")
            elif delivery == "closed" and (state.state != "closed" or state.merged):
                add("pr_closed_state_mismatch", path, f"{subject} declares closed delivery but pull request is merged or still open")
            declared_owner = pr.get("owner")
            if declared_owner:
                if state.owner_login != declared_owner.get("login"):
                    add("pr_owner_login_mismatch", path, "declared pull request owner login does not match GitHub")
                if state.owner_url != declared_owner.get("profile_url"):
                    add("pr_owner_url_mismatch", path, "declared pull request owner profile URL does not match GitHub")

    for milestone_index, milestone in enumerate(shared.get("milestones", [])):
        milestone_path = f"project/project-state.yaml:milestones[{milestone_index}]({milestone.get('id')})"
        evidence = milestone.get("evidence", {})
        check_evidence(milestone_path, evidence, milestone.get("delivery_status"), "milestone")

    for node_index, node in enumerate(roadmap_nodes(shared)):
        evidence = node.get("evidence")
        if not evidence:
            continue
        node_path = f"project/project-state.yaml:roadmap.nodes[{node_index}]({node.get('id')})"
        check_evidence(node_path, evidence, node.get("delivery_status"), "roadmap node")

    for caveat_index, caveat in enumerate(shared.get("caveats", [])):
        issue = caveat.get("issue")
        if not issue:
            continue
        path = f"project/project-state.yaml:caveats[{caveat_index}]({caveat['id']}).issue[{issue['repository']}#{issue['number']}]"
        state = call("issue", path, lambda issue=issue: provider.issue(issue["repository"], issue["number"]))
        if state is PROVIDER_ERROR:
            continue
        if state is None:
            add("missing_issue", path, "issue does not exist in the declared repository")
            continue
        if caveat["status"] in ("open", "monitoring") and state.state != "open":
            add("issue_state_mismatch", path, f"caveat is {caveat['status']} but GitHub issue is {state.state}")
        if caveat["status"] in ("resolved", "superseded") and state.state != "closed":
            add("issue_state_mismatch", path, f"caveat is {caveat['status']} but GitHub issue is {state.state}")

    for repo_status in repo_statuses:
        release = repo_status.get("release", {})
        tag = release.get("latest_tag")
        if not tag:
            continue
        repository = repo_status.get("repository", "<unknown>")
        path = f"project/repo-status.yaml:release[{repository}@{tag}]"
        tag_state = call("tag", path, lambda repository=repository, tag=tag: provider.tag(repository, tag))
        if tag_state is PROVIDER_ERROR:
            continue
        if tag_state is None:
            add("missing_tag", path, "tag does not exist in the declared repository")
            continue
        if not tag_state.target_sha:
            add("tag_target_missing", path, "tag did not resolve to a target commit or tag object")
        if release.get("release_status") in ("released", "prerelease"):
            exists = call("release", path, lambda repository=repository, tag=tag: provider.release_exists(repository, tag))
            if exists is False:
                add("missing_release", path, "release_status requires a GitHub Release for the latest tag")

    return issues


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
        owner = pr.get("owner")
        suffix = ""
        if owner:
            suffix = f" by [{owner['login']}]({owner['profile_url']})"
        parts.append(f"{pr['repository']}#{pr['number']}{suffix}")
    return ", ".join(parts) if parts else "None recorded"


def repository_list_text(repositories: list[str]) -> str:
    return ", ".join(owner_label(repository) for repository in repositories)


def reference_list_text(node_ids: list[str] | None) -> str:
    if not node_ids:
        return ""
    return ", ".join(f"`{node_id}`" for node_id in node_ids)


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


def render_nested_roadmap(context: dict[str, Any]) -> str:
    shared = context["shared"]
    nodes = roadmap_nodes(shared)
    children: dict[str | None, list[dict[str, Any]]] = {}
    for node in nodes:
        children.setdefault(node.get("parent"), []).append(node)

    lines = [
        generated_header(context),
        "# Nested Roadmap",
        "",
        "This view is generated from `project/project-state.yaml` and preserves the roadmap hierarchy, sequencing, and evidence references.",
        "",
        "## Roadmap Tree",
        "",
    ]

    def append_node(node: dict[str, Any], depth: int) -> None:
        indent = "  " * depth
        concept = node["concept_classification"]
        parts = [
            node["kind"],
            f"status: {status_label(node['status'])}",
            f"owner: {owner_label(node['owner'])}",
            f"repositories: {repository_list_text(node['repositories'])}",
            f"concept: {status_label(concept['primary'])}",
            f"layer: {status_label(concept['architecture_layer'])}",
            f"execution: {status_label(node['execution']['assignment'])} / {owner_label(node['execution']['assigned_to'])}",
            f"parallelism: {status_label(node['parallelism']['classification'])}",
        ]
        if node.get("delivery_status"):
            parts.append(f"delivery: {status_label(node['delivery_status'])}")
        if node.get("acceptance_status"):
            parts.append(f"acceptance: {status_label(node['acceptance_status'])}")
        if node.get("mirrors_milestone"):
            parts.append(f"mirrors: `{node['mirrors_milestone']}`")

        lines.append(f"{indent}- **{node['title']}** (`{node['id']}`) - " + "; ".join(parts))

        detail_lines: list[str] = []
        for label, key in (
            ("Depends on", "depends_on"),
            ("Enables", "enables"),
            ("Sequence after", "sequence_after"),
            ("Sequence before", "sequence_before"),
        ):
            text = reference_list_text(node.get(key))
            if text:
                detail_lines.append(f"{label}: {text}")
        parallel_with = reference_list_text(node.get("parallelism", {}).get("with"))
        if parallel_with:
            detail_lines.append(f"Parallel with: {parallel_with}")
        if node.get("evidence"):
            detail_lines.append(f"Evidence: {evidence_text(node['evidence'])}")
        if node.get("rationale"):
            detail_lines.append(f"Rationale: {node['rationale']}")
        if node.get("acceptance_reason"):
            detail_lines.append(f"Acceptance reason: {node['acceptance_reason']}")
        criteria = node.get("acceptance", {}).get("criteria", [])
        if criteria:
            detail_lines.append("Acceptance criteria: " + "; ".join(criteria))

        for detail in detail_lines:
            lines.append(f"{indent}  {detail}")

        for child in children.get(node["id"], []):
            append_node(child, depth + 1)

    roots = children.get(None, []) + children.get("", [])
    for node in nodes:
        if node["kind"] == "project" and node["id"] not in [root["id"] for root in roots]:
            roots.append(node)
    for root in roots:
        append_node(root, 0)

    next_nodes = [
        node
        for node in nodes
        if node.get("execution", {}).get("assignment") == "next_eligible"
    ]
    lines.extend(["", "## Next Eligible Work", ""])
    if next_nodes:
        for node in next_nodes:
            depends_on = reference_list_text(node.get("depends_on")) or "None"
            lines.append(f"- {node['title']} (`{node['id']}`) - depends on: {depends_on}")
    else:
        lines.append("None.")

    blocked_or_deferred = [
        node
        for node in nodes
        if node["status"] in ("blocked", "deferred") or node.get("execution", {}).get("assignment") == "deferred"
    ]
    lines.extend(["", "## Deferred Or Blocked Work", ""])
    if blocked_or_deferred:
        for node in blocked_or_deferred:
            depends_on = reference_list_text(node.get("depends_on")) or "None"
            lines.append(f"- {node['title']} (`{node['id']}`) - status: {status_label(node['status'])}; depends on: {depends_on}")
    else:
        lines.append("None.")

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
        "nested-roadmap.md": render_nested_roadmap(context),
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
        raise ProjectDocsError(
            "[generation:generated_docs_fresh] Generated documentation is stale:\n"
            f"{formatted}\nRegenerate with: ./scripts/project-docs generate"
        )


def generated_drift_issues(context: dict[str, Any]) -> list[ValidationIssue]:
    repo_root = context["repo_root"]
    committed_root = repo_root / "docs" / "generated"
    issues: list[ValidationIssue] = []
    with tempfile.TemporaryDirectory(prefix="project-docs-") as tmp:
        tmp_root = Path(tmp)
        write_generated(context, tmp_root)
        for filename in GENERATED_FILES:
            committed = committed_root / filename
            generated = tmp_root / filename
            if not committed.exists():
                issues.append(ValidationIssue("generation", "generated_docs_fresh", str(committed), "generated file is missing; regenerate with ./scripts/project-docs generate"))
                continue
            committed_text = committed.read_text(encoding="utf-8")
            generated_text = generated.read_text(encoding="utf-8")
            if committed_text != generated_text:
                issues.append(ValidationIssue("generation", "generated_docs_fresh", str(committed), "generated file is stale; regenerate with ./scripts/project-docs generate"))
    return issues


VOLATILE_STATUS_PATTERNS = (
    re.compile(r"\bactive gate is\b", re.IGNORECASE),
    re.compile(r"\bactive product gate is\b", re.IGNORECASE),
    re.compile(r"\bno (?:subsequent )?(?:implementation )?slice is selected\b", re.IGNORECASE),
    re.compile(r"\bCI enforcement is not implemented yet\b", re.IGNORECASE),
    re.compile(r"\blatest tag:\s*`?[^`\n]+`?", re.IGNORECASE),
    re.compile(r"\brelease status:\s*`?[^`\n]+`?", re.IGNORECASE),
)


AUTHORED_DOCS = (
    "docs/current-status.md",
    "docs/roadmap.md",
    "docs/handoffs/latest.md",
    "docs/execution-telemetry/implementation-status.md",
    "project/README.md",
)


def authored_doc_drift_issues(repo_root: Path) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []
    for relative in AUTHORED_DOCS:
        path = repo_root / relative
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        is_historical = text.lstrip().startswith("> **Historical record:**")
        if "docs/generated/project-status.md" not in text and "generated/project-status.md" not in text:
            issues.append(ValidationIssue("authored-doc", "generated_status_link", relative, "authored status-bearing document must link to generated project status"))
        if is_historical:
            continue
        for pattern in VOLATILE_STATUS_PATTERNS:
            match = pattern.search(text)
            if match:
                issues.append(ValidationIssue("authored-doc", "volatile_status_claim", relative, f"contains duplicated volatile status claim '{match.group(0)}'; reference docs/generated/ instead"))
    return issues


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


def load_peer_repo_statuses(peer_roots: list[str]) -> tuple[list[dict[str, Any]], dict[str, Path]]:
    statuses: list[dict[str, Any]] = []
    paths: dict[str, Path] = {}
    for peer_root in peer_roots:
        root = Path(peer_root).expanduser().resolve()
        path = root / "project" / "repo-status.yaml"
        status = load_yaml(path)
        validate_schema(status, SCHEMA_ROOT / "repo-status.schema.json", path)
        repository = status.get("repository", str(path))
        statuses.append(status)
        paths[repository] = path
    return statuses, paths


def command_ci(args: argparse.Namespace) -> None:
    context = load_inputs(Path(args.repo_root), args.shared_state)
    repo_statuses = [context["repo_status"]]
    repo_status_paths = {context["repo_status"].get("repository", "<current>"): context["repo_status_path"]}
    peer_statuses, peer_paths = load_peer_repo_statuses(args.peer_repo_root)
    repo_statuses.extend(peer_statuses)
    repo_status_paths.update(peer_paths)

    issues: list[ValidationIssue] = []
    issues.extend(invariant_issues(context["shared"], repo_statuses, repo_status_paths))
    issues.extend(validate_shared_source_issues(context))
    ensure_generated_warning(context["repo_root"])
    issues.extend(generated_drift_issues(context))
    issues.extend(authored_doc_drift_issues(context["repo_root"]))

    if not args.skip_github:
        token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        provider = GitHubRestEvidenceProvider(token=token, api_url=os.environ.get("GITHUB_API_URL"))
        issues.extend(github_evidence_issues(context["shared"], repo_statuses, provider))

    raise_issues(issues)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and render project truth documentation.")
    parser.add_argument("command", choices=("validate", "generate", "check", "ci"))
    parser.add_argument("--repo-root", default=os.getcwd())
    parser.add_argument("--shared-state", default=os.environ.get("PROJECT_TRUTH_SHARED_STATE"))
    parser.add_argument("--require-generated", action="store_true")
    parser.add_argument("--peer-repo-root", action="append", default=[], help="Additional checkout root whose project/repo-status.yaml participates in cross-repository invariants.")
    parser.add_argument("--skip-github", action="store_true", help="Skip live GitHub evidence verification. Do not use in CI.")
    args = parser.parse_args(argv)

    try:
        if args.command == "validate":
            command_validate(args)
        elif args.command == "generate":
            command_generate(args)
        elif args.command == "check":
            command_check(args)
        elif args.command == "ci":
            command_ci(args)
        return 0
    except ProjectDocsError as exc:
        sys.stderr.write(f"project-docs: {exc}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
