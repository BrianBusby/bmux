#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
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
from dataclasses import dataclass, field
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
PARALLEL_ACTIVE_CLASSIFICATIONS = ("safe", "conditional")
SELECTED_NEXT_ASSIGNMENT = "selected_next"
IMPLEMENTATION_CANDIDATE_ASSIGNMENTS = (SELECTED_NEXT_ASSIGNMENT, "planned", "unassigned")
CAPABILITY_MATURITIES = ("captured", "gated", "ready", "active", "validated", "complete")
CAPABILITY_MATURITY_ORDER = {value: index for index, value in enumerate(CAPABILITY_MATURITIES)}
IMPLEMENTATION_GATED_MATURITIES = ("captured", "gated")
IMPLEMENTATION_NON_CANDIDATE_MATURITIES = (
    "captured",
    "gated",
    "active",
    "validated",
    "complete",
)
DEPENDENCY_SATISFYING_MATURITIES = ("validated", "complete")
DEPENDENCY_SATISFYING_STATUSES = ("implemented", "accepted")
DEPENDENCY_SATISFYING_ACCEPTANCE_STATUSES = ("implemented", "under_observation", "accepted")
DEPENDENCY_REFERENCE_FIELDS = ("depends_on", "sequence_after")

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
    number: int | None = None
    merged_at: str | None = None
    merge_commit_sha: str | None = None
    head_ref: str | None = None
    head_owner_login: str | None = None


@dataclass(frozen=True)
class ReconciliationChange:
    name: str
    path: str
    message: str
    node_id: str | None = None


@dataclass(frozen=True)
class ReconciliationDecision:
    name: str
    path: str
    message: str
    node_id: str | None = None


@dataclass
class NodeReconciliationUpdate:
    node_id: str
    status: str | None = None
    delivery_status: str | None = None
    acceptance_status: str | None = None
    capability_maturity: str | None = None
    completed_at: str | None = None
    execution_assignment: str | None = None
    clear_active_metadata: bool = False
    add_commits: list[dict[str, Any]] = field(default_factory=list)
    upsert_pull_requests: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class RepoStatusReconciliationUpdate:
    repository: str
    clear_active_slice_id: str | None = None


@dataclass
class ReconciliationPlan:
    changes: list[ReconciliationChange]
    decisions: list[ReconciliationDecision]
    issues: list[ValidationIssue]
    node_updates: dict[str, NodeReconciliationUpdate]
    repo_status_updates: dict[str, RepoStatusReconciliationUpdate]

    @property
    def clean(self) -> bool:
        return not self.changes and not self.decisions and not self.issues


@dataclass(frozen=True)
class ActiveSliceAssignment:
    node_id: str
    title: str
    path: str
    classification: str
    worktree_required: bool
    active_worktree: str | None
    active_branch: str | None
    active_agent: str | None
    active_session: str | None
    likely_conflict_domains: frozenset[str]
    contract_dependencies: frozenset[str]
    conflict_note: str | None


@dataclass(frozen=True)
class DependencyReadiness:
    node_id: str
    title: str
    blockers: tuple[str, ...]

    @property
    def ready(self) -> bool:
        return not self.blockers


@dataclass(frozen=True)
class NextWorkSummary:
    primary_frontier: dict[str, Any] | None
    frontier_active_or_selected: tuple[dict[str, Any], ...]
    active: tuple[dict[str, Any], ...]
    selected_next: tuple[dict[str, Any], ...]
    ready_candidates: tuple[dict[str, Any], ...]
    gated_or_blocked: tuple[dict[str, Any], ...]


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
    def commit_reachable_from_default_branch(self, repository: str, sha: str) -> bool: ...
    def pull_request(self, repository: str, number: int) -> PullRequestEvidence | None: ...
    def pull_requests_for_head(self, repository: str, owner: str, branch: str) -> list[PullRequestEvidence]: ...
    def issue(self, repository: str, number: int) -> IssueEvidence | None: ...
    def tag(self, repository: str, tag: str) -> TagEvidence | None: ...
    def release_exists(self, repository: str, tag: str) -> bool: ...


class ProjectDocsError(Exception):
    def __init__(self, message: str, exit_code: int = 1):
        super().__init__(message)
        self.message = message
        self.exit_code = exit_code


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
        self._default_branch_cache: dict[str, str | None] = {}

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
            if exc.code == 429:
                raise GitHubProviderError("rate_limit", f"GitHub API rate limit hit for {path}") from exc
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

    def default_branch(self, repository: str) -> str | None:
        if repository in self._default_branch_cache:
            return self._default_branch_cache[repository]
        data = self._get(f"/repos/{quote_slug(repository)}")
        branch = str(data.get("default_branch", "")) if isinstance(data, dict) else ""
        self._default_branch_cache[repository] = branch or None
        return self._default_branch_cache[repository]

    def commit_exists(self, repository: str, sha: str) -> bool:
        return self._get(f"/repos/{quote_slug(repository)}/commits/{urllib.parse.quote(sha)}") is not None

    def commit_reachable_from_default_branch(self, repository: str, sha: str) -> bool:
        branch = self.default_branch(repository)
        if not branch:
            return False
        basehead = urllib.parse.quote(f"{sha}...{branch}", safe=".")
        data = self._get(f"/repos/{quote_slug(repository)}/compare/{basehead}")
        if not isinstance(data, dict):
            return False
        return data.get("status") in ("ahead", "identical")

    def _pull_request_evidence_from_data(self, data: dict[str, Any]) -> PullRequestEvidence:
        user = data.get("user", {}) if isinstance(data, dict) else {}
        head = data.get("head", {}) if isinstance(data, dict) else {}
        head_user = head.get("user", {}) if isinstance(head, dict) else {}
        return PullRequestEvidence(
            state=str(data.get("state", "")),
            draft=bool(data.get("draft")),
            merged=bool(data.get("merged_at")),
            owner_login=str(user.get("login")) if user.get("login") else None,
            owner_url=str(user.get("html_url")) if user.get("html_url") else None,
            number=int(data["number"]) if data.get("number") else None,
            merged_at=str(data.get("merged_at")) if data.get("merged_at") else None,
            merge_commit_sha=str(data.get("merge_commit_sha")) if data.get("merge_commit_sha") else None,
            head_ref=str(head.get("ref")) if isinstance(head, dict) and head.get("ref") else None,
            head_owner_login=str(head_user.get("login")) if isinstance(head_user, dict) and head_user.get("login") else None,
        )

    def pull_request(self, repository: str, number: int) -> PullRequestEvidence | None:
        data = self._get(f"/repos/{quote_slug(repository)}/pulls/{number}")
        if data is None:
            return None
        return self._pull_request_evidence_from_data(data)

    def pull_requests_for_head(self, repository: str, owner: str, branch: str) -> list[PullRequestEvidence]:
        query = urllib.parse.urlencode(
            {
                "state": "all",
                "head": f"{owner}:{branch}",
                "per_page": "20",
            }
        )
        data = self._get(f"/repos/{quote_slug(repository)}/pulls?{query}")
        if not isinstance(data, list):
            return []
        return sorted(
            [self._pull_request_evidence_from_data(item) for item in data if isinstance(item, dict)],
            key=lambda item: item.number or 0,
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

    raise ProjectDocsError(
        f"{repo_root}: cannot resolve canonical project manifest. Expected "
        "project/project-state.yaml in the monorepo root."
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
        pointer = load_yaml(pointer_path)

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


def repository_key_for_slug(shared: dict[str, Any], slug: str) -> str | None:
    matches: list[tuple[str, dict[str, Any]]] = []
    for key, repository in shared.get("repositories", {}).items():
        if repository.get("slug") == slug:
            matches.append((key, repository))
    if not matches:
        return None
    if len(matches) == 1:
        return matches[0][0]
    for key, repository in matches:
        if "canonical" in repository.get("role", ""):
            return key
    return matches[0][0]


def repository_label_for_slug(shared: dict[str, Any], slug: str) -> str:
    key = repository_key_for_slug(shared, slug)
    return owner_label(key) if key else slug


def is_active_implementation_slice(node: dict[str, Any]) -> bool:
    return (
        node.get("kind") == "slice"
        and (
            node.get("status") == "active"
            or node.get("execution", {}).get("assignment") == "current"
        )
    )


def is_selected_next_slice(node: dict[str, Any]) -> bool:
    return node.get("kind") == "slice" and node.get("execution", {}).get("assignment") == SELECTED_NEXT_ASSIGNMENT


def capability_maturity(node: dict[str, Any]) -> str | None:
    value = node.get("capability_maturity")
    return str(value) if value else None


def capability_maturity_text(node: dict[str, Any] | None) -> str:
    if not node:
        return "missing"
    return capability_maturity(node) or "unspecified"


def capability_maturity_satisfies(actual: str | None, required: str) -> bool:
    if actual is None:
        return False
    return CAPABILITY_MATURITY_ORDER[actual] >= CAPABILITY_MATURITY_ORDER[required]


def is_dependency_satisfied(node: dict[str, Any]) -> bool:
    maturity = capability_maturity(node)
    if maturity in DEPENDENCY_SATISFYING_MATURITIES:
        return True
    return (
        node.get("status") in DEPENDENCY_SATISFYING_STATUSES
        or node.get("acceptance_status") in DEPENDENCY_SATISFYING_ACCEPTANCE_STATUSES
        or node.get("execution", {}).get("assignment") == "complete"
    )


def is_implementation_candidate_slice(node: dict[str, Any]) -> bool:
    if node.get("kind") != "slice":
        return False
    maturity = capability_maturity(node)
    if maturity in IMPLEMENTATION_NON_CANDIDATE_MATURITIES:
        return False
    if node.get("status") in ("blocked", "deferred", "superseded", "implemented", "accepted"):
        return False
    if node.get("acceptance_status") in ("implemented", "under_observation", "accepted", "rejected", "superseded"):
        return False
    if node.get("delivery_status") in ("merged", "closed", "superseded"):
        return False
    return node.get("execution", {}).get("assignment") in IMPLEMENTATION_CANDIDATE_ASSIGNMENTS


def readiness_reference_ids(node: dict[str, Any]) -> tuple[str, ...]:
    references: list[str] = []
    for field in DEPENDENCY_REFERENCE_FIELDS:
        references.extend(str(item) for item in node.get(field, []))
    return tuple(references)


def roadmap_gates(node: dict[str, Any]) -> tuple[dict[str, Any], ...]:
    return tuple(node.get("gates", []))


def readiness_blockers(node: dict[str, Any], node_by_id: dict[str, dict[str, Any]]) -> tuple[str, ...]:
    blockers: list[str] = []
    for ref_id in readiness_reference_ids(node):
        ref_node = node_by_id.get(ref_id)
        if ref_node is None:
            blockers.append(f"Missing dependency `{ref_id}`")
        elif not is_dependency_satisfied(ref_node):
            blockers.append(f"{ref_node['title']} (`{ref_id}`) is not dependency-satisfying")

    for gate in roadmap_gates(node):
        gate_id = gate["id"]
        requires = gate["requires"]
        ref_id = str(requires["node"])
        required = str(requires["maturity"])
        ref_node = node_by_id.get(ref_id)
        if ref_node is None:
            blockers.append(f"Gate `{gate_id}` references missing node `{ref_id}`")
            continue
        actual = capability_maturity(ref_node)
        if not capability_maturity_satisfies(actual, required):
            reason = gate.get("reason")
            suffix = f": {reason}" if reason else ""
            blockers.append(
                f"{ref_node['title']} (`{ref_id}`) has maturity {capability_maturity_text(ref_node)}; "
                f"requires {required} for gate `{gate_id}`{suffix}"
            )
    return tuple(blockers)


def dependency_readiness(node: dict[str, Any], node_by_id: dict[str, dict[str, Any]]) -> DependencyReadiness:
    blockers = readiness_blockers(node, node_by_id)
    return DependencyReadiness(node_id=node["id"], title=node["title"], blockers=blockers)


def implementation_candidate_nodes(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [node for node in nodes if is_implementation_candidate_slice(node)]


def selected_next_nodes(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [node for node in nodes if is_selected_next_slice(node)]


def dependency_ready_nodes(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    node_by_id = {node["id"]: node for node in nodes}
    return [
        node
        for node in implementation_candidate_nodes(nodes)
        if dependency_readiness(node, node_by_id).ready
    ]


def gated_or_blocked_nodes(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    node_by_id = {node["id"]: node for node in nodes}
    result: list[dict[str, Any]] = []
    for node in nodes:
        if node.get("kind") != "slice":
            continue
        if node.get("status") in ("implemented", "accepted", "superseded"):
            continue
        if node.get("execution", {}).get("assignment") == "complete":
            continue
        readiness = dependency_readiness(node, node_by_id)
        maturity = capability_maturity(node)
        if (
            maturity in IMPLEMENTATION_GATED_MATURITIES
            or node.get("status") in ("blocked", "deferred")
            or node.get("execution", {}).get("assignment") == "deferred"
            or not readiness.ready
        ):
            result.append(node)
    return result


def primary_frontier_node(shared: dict[str, Any]) -> dict[str, Any] | None:
    frontier_id = shared.get("roadmap", {}).get("primary_capability_frontier")
    if not frontier_id:
        return None
    return {node["id"]: node for node in roadmap_nodes(shared)}.get(frontier_id)


def node_descends_from(node: dict[str, Any], ancestor_id: str, node_by_id: dict[str, dict[str, Any]]) -> bool:
    current: dict[str, Any] | None = node
    while current:
        if current.get("id") == ancestor_id:
            return True
        parent_id = current.get("parent")
        current = node_by_id.get(parent_id) if parent_id else None
    return False


def next_work_summary(shared: dict[str, Any]) -> NextWorkSummary:
    nodes = roadmap_nodes(shared)
    node_by_id = {node["id"]: node for node in nodes}
    frontier = primary_frontier_node(shared)
    frontier_id = frontier["id"] if frontier else None
    active = tuple(node for node in nodes if is_active_implementation_slice(node))
    selected = tuple(selected_next_nodes(nodes))
    ready = tuple(
        node
        for node in dependency_ready_nodes(nodes)
        if node.get("execution", {}).get("assignment") != SELECTED_NEXT_ASSIGNMENT
    )
    frontier_active_or_selected: tuple[dict[str, Any], ...] = tuple()
    if frontier_id:
        frontier_active_or_selected = tuple(
            node
            for node in nodes
            if node.get("kind") == "slice"
            and (is_active_implementation_slice(node) or is_selected_next_slice(node))
            and node_descends_from(node, frontier_id, node_by_id)
        )
    return NextWorkSummary(
        primary_frontier=frontier,
        frontier_active_or_selected=frontier_active_or_selected,
        active=active,
        selected_next=selected,
        ready_candidates=ready,
        gated_or_blocked=tuple(gated_or_blocked_nodes(nodes)),
    )


def metadata_values(node: dict[str, Any], key: str) -> tuple[str, ...]:
    values = node.get("parallelism", {}).get(key, [])
    return tuple(str(value) for value in values)


def active_slice_assignment(index: int, node: dict[str, Any]) -> ActiveSliceAssignment:
    parallelism = node.get("parallelism", {})
    execution = node.get("execution", {})
    return ActiveSliceAssignment(
        node_id=node["id"],
        title=node["title"],
        path=roadmap_node_path(index, node),
        classification=str(parallelism.get("classification", "unknown")),
        worktree_required=bool(parallelism.get("worktree_required", False)),
        active_worktree=execution.get("active_worktree"),
        active_branch=execution.get("active_branch"),
        active_agent=execution.get("active_agent"),
        active_session=execution.get("active_session"),
        likely_conflict_domains=frozenset(metadata_values(node, "likely_conflict_domains")),
        contract_dependencies=frozenset(metadata_values(node, "contract_dependencies")),
        conflict_note=parallelism.get("conflict_note"),
    )


def active_slice_assignments(nodes: list[dict[str, Any]]) -> list[ActiveSliceAssignment]:
    return [
        active_slice_assignment(index, node)
        for index, node in enumerate(nodes)
        if is_active_implementation_slice(node)
    ]


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


def add_active_assignment_issues(
    nodes: list[dict[str, Any]],
    add,
) -> None:
    active = active_slice_assignments(nodes)

    def assignment_list(assignments: list[ActiveSliceAssignment]) -> str:
        return ", ".join(f"`{assignment.node_id}`" for assignment in assignments)

    def add_duplicate_assignment_value(
        attribute: str,
        issue_name: str,
        label: str,
    ) -> None:
        by_value: dict[str, list[ActiveSliceAssignment]] = {}
        for assignment in active:
            value = getattr(assignment, attribute)
            if value:
                by_value.setdefault(value, []).append(assignment)
        for value, assignments in sorted(by_value.items()):
            if len(assignments) > 1:
                add(
                    issue_name,
                    "project/project-state.yaml:roadmap.nodes",
                    f"active {label} {value!r} is claimed by {assignment_list(assignments)}",
                )

    for index, node in enumerate(nodes):
        execution = node.get("execution", {})
        has_active_execution_metadata = any(
            execution.get(key)
            for key in ("active_worktree", "active_branch", "active_agent", "active_session")
        )
        if has_active_execution_metadata and not is_active_implementation_slice(node):
            add(
                "inactive_slice_has_active_assignment",
                roadmap_node_path(index, node),
                "active execution metadata is only valid on active/current implementation slices",
            )

    for assignment in active:
        if assignment.worktree_required:
            if not assignment.active_worktree:
                add(
                    "active_worktree_required",
                    assignment.path,
                    "active slice with worktree_required must declare execution.active_worktree",
                )
            if not assignment.active_branch:
                add(
                    "active_branch_required",
                    assignment.path,
                    "active slice with worktree_required must declare execution.active_branch",
                )
            if not assignment.active_agent and not assignment.active_session:
                add(
                    "active_agent_or_session_required",
                    assignment.path,
                    "active slice with worktree_required must declare execution.active_agent or execution.active_session",
                )

    add_duplicate_assignment_value("active_worktree", "unique_active_worktree", "worktree")
    add_duplicate_assignment_value("active_branch", "unique_active_branch", "branch")

    if len(active) <= 1:
        return

    for assignment in active:
        if assignment.classification == "serial":
            add(
                "active_parallelism_serial",
                assignment.path,
                "serial roadmap slice cannot be active in parallel with another implementation slice",
            )
        elif assignment.classification == "unknown":
            add(
                "active_parallelism_unknown",
                assignment.path,
                "unknown roadmap parallelism cannot be treated as safe for concurrent active work",
            )
        elif assignment.classification not in PARALLEL_ACTIVE_CLASSIFICATIONS:
            add(
                "active_parallelism_classification",
                assignment.path,
                f"active parallel classification must be one of {', '.join(PARALLEL_ACTIVE_CLASSIFICATIONS)}",
            )

    for left_index, left in enumerate(active):
        for right in active[left_index + 1:]:
            if left.classification != "safe" or right.classification != "safe":
                continue
            for attribute, issue_name, label in (
                ("likely_conflict_domains", "active_safe_conflict_domain_overlap", "likely conflict domains"),
                ("contract_dependencies", "active_safe_contract_dependency_overlap", "contract dependencies"),
            ):
                overlap = sorted(getattr(left, attribute) & getattr(right, attribute))
                if overlap and not (left.conflict_note or right.conflict_note):
                    overlap_text = ", ".join(f"`{item}`" for item in overlap)
                    add(
                        issue_name,
                        "project/project-state.yaml:roadmap.nodes",
                        f"`{left.node_id}` and `{right.node_id}` are both classified safe but share {label}: {overlap_text}; mark one conditional/serial or add conflict_note",
                    )


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
    primary_frontier_id = shared.get("roadmap", {}).get("primary_capability_frontier")
    if not primary_frontier_id:
        add("primary_capability_frontier_required", "project/project-state.yaml:roadmap.primary_capability_frontier", "roadmap must name one primary capability frontier")
    elif primary_frontier_id not in node_by_id:
        add("primary_capability_frontier_exists", "project/project-state.yaml:roadmap.primary_capability_frontier", f"primary capability frontier '{primary_frontier_id}' does not exist")
    elif node_by_id[primary_frontier_id]["kind"] == "slice":
        add("primary_capability_frontier_not_slice", "project/project-state.yaml:roadmap.primary_capability_frontier", "primary capability frontier must be a container node, not an implementation slice")

    milestone_id_set = set(milestone_ids)
    hierarchy_edges: dict[str, list[str]] = {node_id: [] for node_id in node_by_id}
    ordering_edges: dict[str, list[str]] = {node_id: [] for node_id in node_by_id}

    for index, node in enumerate(nodes):
        path = roadmap_node_path(index, node)
        node_id = node["id"]
        kind = node["kind"]
        parent = node.get("parent")
        assignment = node.get("execution", {}).get("assignment")
        maturity = capability_maturity(node)

        if node["owner"] not in node.get("repositories", []):
            add("roadmap_owner_in_repositories", path, "roadmap node owner must be listed in repositories")

        if assignment == SELECTED_NEXT_ASSIGNMENT and kind != "slice":
            add("selected_next_is_slice", path, "selected_next execution assignment is only valid on implementation slices")

        readiness = dependency_readiness(node, node_by_id)
        if assignment == SELECTED_NEXT_ASSIGNMENT and not readiness.ready:
            add("selected_next_readiness", path, "selected_next slice has unsatisfied prerequisites: " + "; ".join(readiness.blockers))
        if is_active_implementation_slice(node) and not readiness.ready:
            add("active_readiness", path, "active/current slice has unsatisfied prerequisites: " + "; ".join(readiness.blockers))

        if maturity == "active" and node.get("status") != "active" and assignment != "current":
            add("capability_active_requires_current", path, "capability_maturity active must correspond to active status or current execution")
        if maturity in ("captured", "gated") and assignment == SELECTED_NEXT_ASSIGNMENT:
            add("capability_not_selectable", path, f"capability_maturity {maturity} cannot be selected_next")
        if maturity in ("captured", "gated") and is_active_implementation_slice(node):
            add("capability_gated_not_active", path, f"capability_maturity {maturity} cannot be current or active")
        if maturity == "ready" and not readiness.ready:
            add("capability_ready_readiness", path, "capability_maturity ready has unsatisfied prerequisites: " + "; ".join(readiness.blockers))
        if maturity == "complete" and assignment in ("current", SELECTED_NEXT_ASSIGNMENT, "planned"):
            add("capability_complete_not_open", path, "capability_maturity complete cannot coexist with an open implementation assignment")

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

        gate_ids = [gate["id"] for gate in roadmap_gates(node)]
        duplicate_gate_ids = sorted({gate_id for gate_id in gate_ids if gate_ids.count(gate_id) > 1})
        for gate_id in duplicate_gate_ids:
            add("roadmap_gate_ids_unique", path, f"duplicate gate id '{gate_id}'")
        for gate in roadmap_gates(node):
            gate_id = gate["id"]
            ref_id = str(gate["requires"]["node"])
            if ref_id == node_id:
                add("roadmap_reference_not_self", path, f"gate '{gate_id}' cannot reference the node itself")
            if ref_id not in node_by_id:
                add("roadmap_gate_reference_exists", path, f"gate '{gate_id}' reference '{ref_id}' does not exist")
                continue
            ordering_edges[ref_id].append(node_id)

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
            if maturity in ("validated", "complete"):
                if not has_evidence_record(node.get("evidence")):
                    add("capability_maturity_requires_evidence", path, f"capability_maturity {maturity} requires commit or pull request evidence")
                if (
                    status not in ("implemented", "accepted")
                    and acceptance_status not in DEPENDENCY_SATISFYING_ACCEPTANCE_STATUSES
                    and assignment != "complete"
                ):
                    add(
                        "capability_maturity_requires_implementation",
                        path,
                        f"capability_maturity {maturity} requires implemented, under_observation, accepted, or complete delivery state",
                    )

    add_active_assignment_issues(nodes, add)

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

    for candidate in repo_statuses:
        repository = candidate.get("repository", "<unknown>")
        candidate_path = repo_status_paths.get(repository, Path("project/repo-status.yaml"))
        if "ownership" in candidate:
            add("local_cannot_redefine_ownership", str(candidate_path), "repo-local manifest cannot redefine shared ownership")

        if repository == "BrianBusby/bmux":
            capabilities = set(candidate.get("local_capabilities", {}).keys())
            if "durable_evidence" in capabilities or "deterministic_current_state" in capabilities:
                add("bmux_no_durable_ownership", str(candidate_path), "bmux cannot claim durable evidence or Current State ownership")

        active_slice = candidate.get("current_work", {}).get("active_slice")
        current_state = candidate.get("current_work", {}).get("state")
        if isinstance(active_slice, dict):
            selected = active_slice.get("id") is not None or active_slice.get("state") not in (None, "none_selected")
            if selected:
                if not active_slice.get("owner"):
                    add("active_slice_has_owner", str(candidate_path), "selected current slice must have owner")
                if current_state in ("observation", "none_selected"):
                    add("active_slice_matches_repo_state", str(candidate_path), "active implementation slice cannot coexist with observation or none_selected repository state")
                active_slice_id = active_slice.get("id")
                roadmap_slice = node_by_id.get(active_slice_id) if active_slice_id else None
                if roadmap_slice is None:
                    add("active_slice_exists_in_roadmap", str(candidate_path), f"active slice '{active_slice_id}' is not a roadmap node")
                elif roadmap_slice.get("kind") != "slice":
                    add("active_slice_is_roadmap_slice", str(candidate_path), f"active slice '{active_slice_id}' must reference a roadmap slice")
                else:
                    repository_key = repository_key_for_slug(shared, repository)
                    if repository_key and repository_key not in roadmap_slice.get("repositories", []):
                        add("active_slice_repository_matches", str(candidate_path), f"active slice '{active_slice_id}' does not list repository {repository_key}")
                    if not is_active_implementation_slice(roadmap_slice):
                        add("active_slice_is_active_assignment", str(candidate_path), f"active slice '{active_slice_id}' must reference a roadmap slice with status active or execution.assignment current")
                    if active_slice.get("title") and active_slice.get("title") != roadmap_slice.get("title"):
                        add("active_slice_title_matches_roadmap", str(candidate_path), f"active slice title must match roadmap title '{roadmap_slice.get('title')}'")
                    roadmap_execution = roadmap_slice.get("execution", {})
                    for field in ("active_worktree", "active_branch", "active_agent", "active_session"):
                        roadmap_value = roadmap_execution.get(field)
                        local_value = active_slice.get(field)
                        if roadmap_value and not local_value:
                            add("active_slice_metadata_matches_roadmap", str(candidate_path), f"active slice must include {field} from roadmap active assignment")
                        elif roadmap_value and local_value and roadmap_value != local_value:
                            add("active_slice_metadata_matches_roadmap", str(candidate_path), f"active slice {field} must match roadmap value {roadmap_value!r}")
            elif current_state == "active":
                add("no_active_slice_matches_repo_state", str(candidate_path), "active repository state must name an active slice")

        telemetry = candidate.get("execution_telemetry", {})
        if telemetry.get("automatic_checkpoint_scheduler") in ("implemented", "under_observation", "accepted"):
            if checkpoints.get("status") == "not_implemented" or not checkpoints.get("selected_for_implementation"):
                add("automatic_checkpoints_not_claimed", str(candidate_path), "automatic checkpoint scheduling cannot be claimed before the shared policy selects and implements it")
        if telemetry.get("raw_execution_telemetry_persisted") in ("implemented", "under_observation", "accepted"):
            if policies.get("raw_execution_telemetry_persisted") is False:
                add("raw_telemetry_not_persisted", str(candidate_path), "repo-local capabilities cannot claim durable raw execution telemetry persistence")

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

    canonical_manifest = repo_root / "project" / "project-state.yaml"
    if pointer is not None:
        add("obsolete_shared_source_pointer", str(pointer_path), "monorepo Project Truth must use project/project-state.yaml directly")
    if shared_path != canonical_manifest:
        add("canonical_manifest_location", str(shared_path), f"canonical manifest must be {canonical_manifest}")
    if shared.get("project", {}).get("shared_state_owner") != repo_status.get("repository"):
        add("shared_state_owner_matches_monorepo", "project/project-state.yaml:project.shared_state_owner", "project.shared_state_owner must match the monorepo repository")
    if not canonical_manifest.exists():
        add("canonical_manifest_exists", str(canonical_manifest), "canonical Project Truth manifest is missing")

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
        pull_request_states: list[tuple[dict[str, Any], str, PullRequestEvidence | None | object]] = []
        for pr in evidence.get("pull_requests", []):
            path = f"{base_path}.evidence.pull_requests[{pr['repository']}#{pr['number']}]"
            state = call("pull request", path, lambda pr=pr: provider.pull_request(pr["repository"], pr["number"]))
            pull_request_states.append((pr, path, state))
            if state is PROVIDER_ERROR:
                continue
            if state is None:
                add("missing_pr", path, "pull request does not exist in the declared repository")
                continue
        has_merged_pr = any(isinstance(state, PullRequestEvidence) and state.merged for _pr, _path, state in pull_request_states)
        for pr, path, state in pull_request_states:
            if state is PROVIDER_ERROR or state is None:
                continue
            if delivery == "merged" and not state.merged:
                if not has_merged_pr:
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
            if pr.get("merged_at") and state.merged_at and pr.get("merged_at") != state.merged_at:
                add("pr_merged_at_mismatch", path, "declared pull request merged_at does not match GitHub")
            if pr.get("merge_commit_sha") and state.merge_commit_sha and pr.get("merge_commit_sha") != state.merge_commit_sha:
                add("pr_merge_commit_mismatch", path, "declared pull request merge_commit_sha does not match GitHub")

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


ACTIVE_EXECUTION_METADATA_KEYS = ("active_worktree", "active_branch", "active_agent", "active_session")
GITHUB_UNAVAILABLE_ISSUES = ("auth", "rate_limit", "network")
DECISION_BACKED_PR_STATE_ISSUES = ("pr_open_state_mismatch", "pr_draft_state_mismatch", "pr_closed_state_mismatch")


def repository_slug_for_key(shared: dict[str, Any], key: str) -> str | None:
    repository = shared.get("repositories", {}).get(key)
    if not isinstance(repository, dict):
        return None
    slug = repository.get("slug")
    return str(slug) if slug else None


def preferred_repository_for_node(
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    node: dict[str, Any],
) -> str | None:
    preferred_status = repo_statuses[0] if repo_statuses else {}
    preferred_slug = preferred_status.get("repository")
    if preferred_slug:
        preferred_key = repository_key_for_slug(shared, str(preferred_slug))
        if preferred_key in node.get("repositories", []):
            return str(preferred_slug)
    for key in node.get("repositories", []):
        slug = repository_slug_for_key(shared, str(key))
        if slug:
            return slug
    return str(preferred_slug) if preferred_slug else None


def repository_owner(repository: str) -> str:
    return repository.split("/", 1)[0]


def pr_manifest_entry(repository: str, state: PullRequestEvidence) -> dict[str, Any]:
    if state.number is None:
        raise ProjectDocsError("cannot record pull request evidence without a PR number")
    entry: dict[str, Any] = {"repository": repository, "number": state.number}
    if state.merged:
        if state.merged_at:
            entry["merged_at"] = state.merged_at
        if state.merge_commit_sha:
            entry["merge_commit_sha"] = state.merge_commit_sha
    if state.owner_login and state.owner_url:
        entry["owner"] = {"login": state.owner_login, "profile_url": state.owner_url}
    return entry


def merge_date(merged_at: str | None) -> str | None:
    if not merged_at:
        return None
    match = re.match(r"^(\d{4}-\d{2}-\d{2})T", merged_at)
    return match.group(1) if match else None


def evidence_commits(evidence: dict[str, Any] | None) -> list[dict[str, Any]]:
    return evidence.get("commits", []) if isinstance(evidence, dict) else []


def evidence_pull_requests(evidence: dict[str, Any] | None) -> list[dict[str, Any]]:
    return evidence.get("pull_requests", []) if isinstance(evidence, dict) else []


def pull_request_is_recorded(node: dict[str, Any], repository: str, number: int | None) -> bool:
    if number is None:
        return False
    for pr in evidence_pull_requests(node.get("evidence")):
        if pr.get("repository") == repository and pr.get("number") == number:
            return True
    return False


def merge_commit_recorded(node: dict[str, Any], repository: str, sha: str | None) -> bool:
    if not sha:
        return True
    return any(commit.get("repository") == repository and commit.get("sha") == sha for commit in evidence_commits(node.get("evidence")))


def update_for_node(plan: ReconciliationPlan, node_id: str) -> NodeReconciliationUpdate:
    update = plan.node_updates.get(node_id)
    if update is None:
        update = NodeReconciliationUpdate(node_id=node_id)
        plan.node_updates[node_id] = update
    return update


def add_node_change(
    plan: ReconciliationPlan,
    node: dict[str, Any],
    path: str,
    name: str,
    message: str,
) -> None:
    plan.changes.append(ReconciliationChange(name=name, path=path, message=message, node_id=node.get("id")))


def add_node_decision(
    plan: ReconciliationPlan,
    node: dict[str, Any],
    path: str,
    name: str,
    message: str,
) -> None:
    plan.decisions.append(ReconciliationDecision(name=name, path=path, message=message, node_id=node.get("id")))


def set_node_update_field(
    plan: ReconciliationPlan,
    node: dict[str, Any],
    path: str,
    update_field: str,
    current: Any,
    new: Any,
    name: str,
    label: str,
) -> None:
    if current == new:
        return
    update = update_for_node(plan, node["id"])
    existing = getattr(update, update_field)
    if existing == new:
        return
    if existing is not None and existing != new:
        plan.issues.append(
            ValidationIssue(
                "reconcile",
                "conflicting_safe_changes",
                path,
                f"cannot set {label} to both {existing!r} and {new!r}",
            )
        )
        return
    setattr(update, update_field, new)
    add_node_change(plan, node, path, name, f"set {label} from {status_label(current)} to {status_label(new)}")


def queue_pull_request_evidence(
    plan: ReconciliationPlan,
    node: dict[str, Any],
    path: str,
    repository: str,
    state: PullRequestEvidence,
) -> None:
    if state.number is None:
        plan.issues.append(ValidationIssue("reconcile", "missing_pr_number", path, "GitHub PR response did not include a number"))
        return
    entry = pr_manifest_entry(repository, state)
    evidence = node.get("evidence")
    changed = not pull_request_is_recorded(node, repository, state.number)
    for pr in evidence_pull_requests(evidence):
        if pr.get("repository") == repository and pr.get("number") == state.number:
            for key, value in entry.items():
                if key not in pr or pr.get(key) != value:
                    changed = True
            break
    if not changed:
        return
    update = update_for_node(plan, node["id"])
    if any(item.get("repository") == repository and item.get("number") == state.number for item in update.upsert_pull_requests):
        return
    update.upsert_pull_requests.append(entry)
    add_node_change(
        plan,
        node,
        path,
        "record_pull_request_evidence",
        f"record {repository}#{state.number} PR evidence and verified merge metadata when available",
    )


def queue_merge_commit_evidence(
    plan: ReconciliationPlan,
    node: dict[str, Any],
    path: str,
    repository: str,
    sha: str | None,
) -> None:
    if not sha or merge_commit_recorded(node, repository, sha):
        return
    update = update_for_node(plan, node["id"])
    if any(item.get("repository") == repository and item.get("sha") == sha for item in update.add_commits):
        return
    update.add_commits.append({"repository": repository, "sha": sha})
    add_node_change(plan, node, path, "record_merge_commit", f"record merge commit {repository}@{sha[:12]}")


def queue_clear_repo_active_slice(
    plan: ReconciliationPlan,
    repo_status: dict[str, Any],
    node: dict[str, Any],
) -> None:
    active_slice = repo_status.get("current_work", {}).get("active_slice")
    if not isinstance(active_slice, dict) or active_slice.get("id") != node.get("id"):
        return
    repository = repo_status.get("repository", "<unknown>")
    update = plan.repo_status_updates.get(repository)
    if update is None:
        update = RepoStatusReconciliationUpdate(repository=repository)
        plan.repo_status_updates[repository] = update
    if update.clear_active_slice_id == node.get("id"):
        return
    update.clear_active_slice_id = node.get("id")
    plan.changes.append(
        ReconciliationChange(
            name="clear_repo_active_slice",
            path="project/repo-status.yaml:current_work.active_slice",
            message=f"clear repo-local active slice for completed delivery `{node.get('id')}`",
            node_id=node.get("id"),
        )
    )


def github_call(plan: ReconciliationPlan, name: str, path: str, fn):
    try:
        return fn()
    except GitHubProviderError as exc:
        plan.issues.append(ValidationIssue("github", exc.kind, path, f"{name}: {exc.message}"))
        return PROVIDER_ERROR


def reconcile_merged_pull_request(
    plan: ReconciliationPlan,
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    provider: GitHubEvidenceProvider,
    node: dict[str, Any],
    path: str,
    repository: str,
    state: PullRequestEvidence,
) -> None:
    if state.number is None:
        plan.issues.append(ValidationIssue("reconcile", "missing_pr_number", path, "GitHub PR response did not include a number"))
        return
    if state.merge_commit_sha:
        reachable = github_call(
            plan,
            "merge commit reachability",
            f"{path}.evidence.pull_requests[{repository}#{state.number}]",
            lambda: provider.commit_reachable_from_default_branch(repository, state.merge_commit_sha or ""),
        )
        if reachable is PROVIDER_ERROR:
            return
        if reachable is False:
            plan.issues.append(
                ValidationIssue(
                    "github",
                    "merge_commit_not_reachable",
                    f"{path}.evidence.pull_requests[{repository}#{state.number}]",
                    "PR merge commit is not reachable from the repository default branch",
                )
            )
            return

    queue_pull_request_evidence(plan, node, path, repository, state)
    queue_merge_commit_evidence(plan, node, path, repository, state.merge_commit_sha)

    delivery_status = node.get("delivery_status")
    if delivery_status in ("proposed", "open", "draft"):
        set_node_update_field(plan, node, f"{path}.delivery_status", "delivery_status", delivery_status, "merged", "mark_delivery_merged", "delivery_status")

    execution = node.get("execution", {})
    if node.get("status") == "active" or execution.get("assignment") == "current":
        set_node_update_field(plan, node, f"{path}.status", "status", node.get("status"), "implemented", "complete_active_implementation", "status")
        set_node_update_field(
            plan,
            node,
            f"{path}.execution.assignment",
            "execution_assignment",
            execution.get("assignment"),
            "complete",
            "complete_execution_assignment",
            "execution.assignment",
        )
        update = update_for_node(plan, node["id"])
        if any(execution.get(key) for key in ACTIVE_EXECUTION_METADATA_KEYS):
            update.clear_active_metadata = True
            add_node_change(plan, node, f"{path}.execution", "clear_active_assignment", "remove active worktree, branch, agent, and session metadata")
        if node.get("acceptance_status") == "proposed":
            set_node_update_field(
                plan,
                node,
                f"{path}.acceptance_status",
                "acceptance_status",
                node.get("acceptance_status"),
                "implemented",
                "mark_implementation_recorded",
                "acceptance_status",
            )
        if node.get("capability_maturity") in ("active", "ready"):
            set_node_update_field(
                plan,
                node,
                f"{path}.capability_maturity",
                "capability_maturity",
                node.get("capability_maturity"),
                "validated",
                "mark_capability_validated",
                "capability_maturity",
            )
        completed_at = merge_date(state.merged_at)
        if completed_at and not node.get("completed_at"):
            set_node_update_field(plan, node, f"{path}.completed_at", "completed_at", node.get("completed_at"), completed_at, "record_completed_at", "completed_at")
        for repo_status in repo_statuses:
            queue_clear_repo_active_slice(plan, repo_status, node)


def closed_unmerged_delivery_decision_recorded(node: dict[str, Any]) -> bool:
    return (
        node.get("delivery_status") in ("closed", "superseded")
        or node.get("acceptance_status") in ("rejected", "superseded")
        or node.get("status") == "superseded"
    )


def queue_open_pull_request_delivery_state(
    plan: ReconciliationPlan,
    node: dict[str, Any],
    path: str,
    state: PullRequestEvidence,
) -> None:
    delivery_status = node.get("delivery_status")
    if delivery_status not in ("proposed", "open", "draft"):
        return
    target_delivery_status = "draft" if state.draft else "open"
    if delivery_status == target_delivery_status:
        return
    set_node_update_field(
        plan,
        node,
        f"{path}.delivery_status",
        "delivery_status",
        delivery_status,
        target_delivery_status,
        "mark_delivery_draft" if target_delivery_status == "draft" else "mark_delivery_open",
        "delivery_status",
    )


def reconcile_pull_request_state(
    plan: ReconciliationPlan,
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    provider: GitHubEvidenceProvider,
    node: dict[str, Any],
    path: str,
    repository: str,
    state: PullRequestEvidence,
    *,
    discovered_from_active_branch: bool,
    recorded_delivery_has_merged_pr: bool = False,
) -> None:
    if state.merged:
        reconcile_merged_pull_request(plan, shared, repo_statuses, provider, node, path, repository, state)
        return
    if state.state == "open" and state.number is not None:
        if discovered_from_active_branch:
            queue_pull_request_evidence(plan, node, path, repository, state)
        queue_open_pull_request_delivery_state(plan, node, path, state)
        return
    if state.state == "closed" and (recorded_delivery_has_merged_pr or closed_unmerged_delivery_decision_recorded(node)):
        return
    if state.state == "closed":
        add_node_decision(
            plan,
            node,
            path,
            "closed_unmerged_pr",
            f"{repository}#{state.number or '<unknown>'} is closed without merge; explicitly supersede, replace, reopen, or abandon the slice",
        )


def reconcile_commit_only_delivery(
    plan: ReconciliationPlan,
    provider: GitHubEvidenceProvider,
    node: dict[str, Any],
    path: str,
) -> None:
    if node.get("delivery_status") not in ("open", "draft"):
        return
    if node.get("status") != "implemented" and node.get("execution", {}).get("assignment") != "complete":
        return
    evidence = node.get("evidence")
    if evidence_pull_requests(evidence):
        return
    commits = evidence_commits(evidence)
    if not commits:
        return
    for commit in commits:
        repository = commit["repository"]
        sha = commit["sha"]
        reachable = github_call(
            plan,
            "commit reachability",
            f"{path}.evidence.commits[{repository}@{sha}]",
            lambda repository=repository, sha=sha: provider.commit_reachable_from_default_branch(repository, sha),
        )
        if reachable is PROVIDER_ERROR:
            return
        if reachable is False:
            add_node_decision(
                plan,
                node,
                path,
                "commit_not_reachable",
                f"commit {repository}@{sha[:12]} is not reachable from the repository default branch; keep open or record replacement/supersession explicitly",
            )
            return
    set_node_update_field(
        plan,
        node,
        f"{path}.delivery_status",
        "delivery_status",
        node.get("delivery_status"),
        "merged",
        "mark_commit_delivery_merged",
        "delivery_status",
    )


def apply_reconciliation_updates_in_place(
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    plan: ReconciliationPlan,
) -> None:
    node_by_id = {node["id"]: node for node in roadmap_nodes(shared)}
    for update in plan.node_updates.values():
        node = node_by_id.get(update.node_id)
        if not node:
            continue
        for field_name in ("status", "delivery_status", "acceptance_status", "capability_maturity", "completed_at"):
            value = getattr(update, field_name)
            if value is not None:
                node[field_name] = value
        execution = node.setdefault("execution", {})
        if update.execution_assignment is not None:
            execution["assignment"] = update.execution_assignment
        if update.clear_active_metadata:
            for key in ACTIVE_EXECUTION_METADATA_KEYS:
                execution.pop(key, None)
        if update.add_commits or update.upsert_pull_requests:
            evidence = node.setdefault("evidence", {"commits": [], "pull_requests": []})
            commits = evidence.setdefault("commits", [])
            for commit in update.add_commits:
                if not any(existing.get("repository") == commit["repository"] and existing.get("sha") == commit["sha"] for existing in commits):
                    commits.append(copy.deepcopy(commit))
            pull_requests = evidence.setdefault("pull_requests", [])
            for entry in update.upsert_pull_requests:
                existing = next(
                    (
                        item
                        for item in pull_requests
                        if item.get("repository") == entry["repository"] and item.get("number") == entry["number"]
                    ),
                    None,
                )
                if existing is None:
                    pull_requests.append(copy.deepcopy(entry))
                else:
                    for key, value in entry.items():
                        existing[key] = copy.deepcopy(value)

    for repo_status in repo_statuses:
        repository = repo_status.get("repository")
        update = plan.repo_status_updates.get(repository)
        if not update or not update.clear_active_slice_id:
            continue
        current_work = repo_status.setdefault("current_work", {})
        current_work["active_slice"] = {"id": None, "title": None, "state": "none_selected"}
        current_work["state"] = "none_selected"


def apply_reconciliation_plan(
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    plan: ReconciliationPlan,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    reconciled_shared = copy.deepcopy(shared)
    reconciled_repo_statuses = copy.deepcopy(repo_statuses)
    apply_reconciliation_updates_in_place(reconciled_shared, reconciled_repo_statuses, plan)
    return reconciled_shared, reconciled_repo_statuses


def queue_ready_candidate_advancement(plan: ReconciliationPlan, shared: dict[str, Any]) -> bool:
    changed = False
    node_by_id = {node["id"]: node for node in roadmap_nodes(shared)}
    for index, node in enumerate(roadmap_nodes(shared)):
        if node.get("kind") != "slice":
            continue
        if node.get("capability_maturity") != "gated":
            continue
        if node.get("status") not in ("planned", "active"):
            continue
        assignment = node.get("execution", {}).get("assignment")
        if assignment not in ("planned", "unassigned", SELECTED_NEXT_ASSIGNMENT):
            continue
        readiness = dependency_readiness(node, node_by_id)
        if not readiness.ready:
            continue
        path = roadmap_node_path(index, node)
        set_node_update_field(
            plan,
            node,
            f"{path}.capability_maturity",
            "capability_maturity",
            node.get("capability_maturity"),
            "ready",
            "advance_ready_candidate",
            "capability_maturity",
        )
        changed = True
    return changed


def reconciliation_plan(
    shared: dict[str, Any],
    repo_statuses: list[dict[str, Any]],
    provider: GitHubEvidenceProvider,
    *,
    discover_active_branches: bool = True,
) -> ReconciliationPlan:
    plan = ReconciliationPlan(changes=[], decisions=[], issues=[], node_updates={}, repo_status_updates={})
    nodes = roadmap_nodes(shared)

    for index, node in enumerate(nodes):
        if node.get("kind") != "slice":
            continue
        path = roadmap_node_path(index, node)
        evidence = node.get("evidence")

        recorded_pull_requests: list[tuple[str, PullRequestEvidence]] = []
        for pr in evidence_pull_requests(evidence):
            repository = pr["repository"]
            number = pr["number"]
            state = github_call(
                plan,
                "pull request",
                f"{path}.evidence.pull_requests[{repository}#{number}]",
                lambda repository=repository, number=number: provider.pull_request(repository, number),
            )
            if state is PROVIDER_ERROR:
                continue
            if state is None:
                plan.issues.append(
                    ValidationIssue(
                        "github",
                        "missing_pr",
                        f"{path}.evidence.pull_requests[{repository}#{number}]",
                        "pull request does not exist in the declared repository",
                    )
                )
                continue
            if state.number is None:
                state = PullRequestEvidence(
                    state=state.state,
                    draft=state.draft,
                    merged=state.merged,
                    owner_login=state.owner_login,
                    owner_url=state.owner_url,
                    number=number,
                    merged_at=state.merged_at,
                    merge_commit_sha=state.merge_commit_sha,
                    head_ref=state.head_ref,
                    head_owner_login=state.head_owner_login,
                )
            recorded_pull_requests.append((repository, state))

        recorded_delivery_has_merged_pr = any(state.merged for _repository, state in recorded_pull_requests)
        for repository, state in recorded_pull_requests:
            reconcile_pull_request_state(
                plan,
                shared,
                repo_statuses,
                provider,
                node,
                path,
                repository,
                state,
                discovered_from_active_branch=False,
                recorded_delivery_has_merged_pr=recorded_delivery_has_merged_pr,
            )

        if discover_active_branches and is_active_implementation_slice(node):
            execution = node.get("execution", {})
            branch = execution.get("active_branch")
            repository = preferred_repository_for_node(shared, repo_statuses, node)
            if branch and repository:
                owner = repository_owner(repository)
                states = github_call(
                    plan,
                    "pull requests for active branch",
                    f"{path}.execution.active_branch[{repository}:{owner}:{branch}]",
                    lambda repository=repository, owner=owner, branch=branch: provider.pull_requests_for_head(repository, owner, branch),
                )
                if states is PROVIDER_ERROR:
                    continue
                if not states:
                    add_node_decision(
                        plan,
                        node,
                        path,
                        "active_branch_pr_not_found",
                        f"active branch `{branch}` has no discoverable PR in {repository}; record PR evidence or explicitly keep the implementation active",
                    )
                elif len(states) > 1:
                    numbers = ", ".join(str(item.number) for item in states)
                    add_node_decision(
                        plan,
                        node,
                        path,
                        "active_branch_multiple_prs",
                        f"active branch `{branch}` matched multiple PRs ({numbers}); record the current delivery PR explicitly",
                    )
                else:
                    reconcile_pull_request_state(
                        plan,
                        shared,
                        repo_statuses,
                        provider,
                        node,
                        path,
                        repository,
                        states[0],
                        discovered_from_active_branch=True,
                    )

        reconcile_commit_only_delivery(plan, provider, node, path)

    while True:
        preview_shared, preview_repo_statuses = apply_reconciliation_plan(shared, repo_statuses, plan)
        before = len(plan.changes)
        queue_ready_candidate_advancement(plan, preview_shared)
        if len(plan.changes) == before:
            break
        shared = preview_shared
        repo_statuses = preview_repo_statuses

    return plan


def reconciliation_ci_issues(plan: ReconciliationPlan, *, allow_decisions: bool = False) -> list[ValidationIssue]:
    issues = list(plan.issues)
    for change in plan.changes:
        issues.append(
            ValidationIssue(
                "reconcile",
                change.name,
                change.path,
                f"Project Truth needs post-merge reconciliation for `{change.node_id}`. Run ./scripts/project-docs reconcile --apply. {change.message}",
            )
        )
    if not allow_decisions:
        for decision in plan.decisions:
            issues.append(
                ValidationIssue(
                    "reconcile",
                    decision.name,
                    decision.path,
                    f"Project Truth needs an explicit planning decision for `{decision.node_id}`. {decision.message}",
                )
            )
    return issues


def filter_allowed_reconciliation_decision_issues(issues: list[ValidationIssue], plan: ReconciliationPlan) -> list[ValidationIssue]:
    decision_paths = tuple(
        f"{decision.path.replace('] (', '](')}."
        for decision in plan.decisions
        if decision.name == "closed_unmerged_pr"
    )
    if not decision_paths:
        return issues
    filtered: list[ValidationIssue] = []
    for issue in issues:
        if issue.category == "github" and issue.name in DECISION_BACKED_PR_STATE_ISSUES and issue.path.startswith(decision_paths):
            continue
        filtered.append(issue)
    return filtered


def format_reconciliation_plan(plan: ReconciliationPlan, *, include_apply_hint: bool = True) -> str:
    lines: list[str] = []
    if plan.clean:
        return "Project Truth reconciliation is clean.\n"
    if plan.changes:
        lines.extend(["Safe mechanical changes:", ""])
        for change in sorted(plan.changes, key=lambda item: (item.path, item.name, item.message)):
            lines.append(f"- [{change.name}] {change.path}: {change.message}")
        lines.append("")
    if plan.decisions:
        lines.extend(["Human decisions required:", ""])
        for decision in sorted(plan.decisions, key=lambda item: (item.path, item.name, item.message)):
            lines.append(f"- [{decision.name}] {decision.path}: {decision.message}")
        lines.append("")
    if plan.issues:
        lines.extend(["Evidence or state failures:", ""])
        for issue in sorted(plan.issues, key=lambda item: item.sort_key()):
            lines.append(f"- {issue.format()}")
        lines.append("")
    if plan.changes and include_apply_hint:
        lines.append("Apply safe changes with: ./scripts/project-docs reconcile --apply")
    return "\n".join(lines).rstrip() + "\n"


def reconciliation_exit_code(plan: ReconciliationPlan) -> int:
    if any(issue.name in GITHUB_UNAVAILABLE_ISSUES for issue in plan.issues):
        return 2
    if plan.issues:
        return 3
    if plan.changes or plan.decisions:
        return 1
    return 0


def round_trip_yaml():
    try:
        from ruamel.yaml import YAML
    except ImportError as exc:
        raise ProjectDocsError(
            "reconcile --apply requires ruamel.yaml; install pinned Project Truth dependencies with "
            "python3 -m pip install -r tools/project-docs/requirements.txt",
            exit_code=3,
        ) from exc
    yaml_rt = YAML()
    yaml_rt.preserve_quotes = True
    yaml_rt.width = 4096
    yaml_rt.indent(mapping=2, sequence=4, offset=2)
    return yaml_rt


def load_round_trip_yaml(path: Path) -> Any:
    yaml_rt = round_trip_yaml()
    with path.open("r", encoding="utf-8") as handle:
        return yaml_rt.load(handle)


def write_round_trip_yaml(path: Path, document: Any) -> None:
    yaml_rt = round_trip_yaml()
    with path.open("w", encoding="utf-8") as handle:
        yaml_rt.dump(document, handle)


def copy_project_docs_inputs(repo_root: Path, tmp_repo: Path) -> None:
    shutil.copytree(repo_root / "project", tmp_repo / "project")
    generated_root = tmp_repo / "docs" / "generated"
    generated_root.mkdir(parents=True, exist_ok=True)
    for filename in GENERATED_FILES:
        source = repo_root / "docs" / "generated" / filename
        if source.exists():
            shutil.copy2(source, generated_root / filename)
    for relative in AUTHORED_GENERATED_DOCS:
        source = repo_root / relative
        if source.exists():
            destination = tmp_repo / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)


def temporary_sibling(destination: Path, suffix: str) -> Path:
    fd, path = tempfile.mkstemp(prefix=f".{destination.name}.", suffix=suffix, dir=destination.parent)
    os.close(fd)
    return Path(path)


def replace_files_transactionally(replacements: list[tuple[Path, Path]]) -> None:
    staged: list[tuple[Path, Path]] = []
    replaced: list[tuple[Path, Path | None]] = []
    try:
        for source, destination in replacements:
            destination.parent.mkdir(parents=True, exist_ok=True)
            staged_path = temporary_sibling(destination, ".project-reconcile.tmp")
            staged.append((staged_path, destination))
            shutil.copy2(source, staged_path)

        for staged_path, destination in staged:
            backup_path: Path | None = None
            if destination.exists():
                backup_path = temporary_sibling(destination, ".project-reconcile.bak")
                backup_path.unlink()
                os.replace(destination, backup_path)
            try:
                os.replace(staged_path, destination)
            except BaseException:
                if backup_path is not None and backup_path.exists() and not destination.exists():
                    os.replace(backup_path, destination)
                raise
            replaced.append((destination, backup_path))
    except BaseException:
        for destination, backup_path in reversed(replaced):
            if backup_path is not None and backup_path.exists():
                if destination.exists():
                    destination.unlink()
                os.replace(backup_path, destination)
            elif destination.exists():
                destination.unlink()
        for staged_path, _destination in staged:
            if staged_path.exists():
                staged_path.unlink()
        raise

    for _destination, backup_path in replaced:
        if backup_path is not None and backup_path.exists():
            backup_path.unlink()


def write_reconciled_files_atomically(context: dict[str, Any], plan: ReconciliationPlan) -> None:
    repo_root = context["repo_root"]
    shared_doc = load_round_trip_yaml(context["shared_path"])
    repo_status_doc = load_round_trip_yaml(context["repo_status_path"])
    apply_reconciliation_updates_in_place(shared_doc, [repo_status_doc], plan)

    with tempfile.TemporaryDirectory(prefix="project-reconcile-") as tmp:
        tmp_repo = Path(tmp)
        copy_project_docs_inputs(repo_root, tmp_repo)
        write_round_trip_yaml(tmp_repo / "project" / "project-state.yaml", shared_doc)
        write_round_trip_yaml(tmp_repo / "project" / "repo-status.yaml", repo_status_doc)

        tmp_context = load_inputs(tmp_repo)
        write_generated(tmp_context)
        write_authored_generated_blocks(tmp_context)
        check_generated(tmp_context)
        check_authored_generated_blocks(tmp_context)

        replacements = [
            (tmp_repo / "project" / "project-state.yaml", context["shared_path"]),
            (tmp_repo / "project" / "repo-status.yaml", context["repo_status_path"]),
        ]
        for filename in GENERATED_FILES:
            replacements.append((tmp_repo / "docs" / "generated" / filename, repo_root / "docs" / "generated" / filename))
        for relative in AUTHORED_GENERATED_DOCS:
            replacements.append((tmp_repo / relative, repo_root / relative))
        replace_files_transactionally(replacements)


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


def metadata_list_text(values: list[str] | tuple[str, ...] | None) -> str:
    if not values:
        return ""
    return ", ".join(f"`{value}`" for value in values)


def optional_metadata_text(values: list[str] | tuple[str, ...] | None) -> str:
    return metadata_list_text(values) or "None"


def readiness_status_text(readiness: DependencyReadiness) -> str:
    if readiness.ready:
        return "ready"
    return "blocked by " + "; ".join(readiness.blockers)


def active_assignment_safety_text(assignment: ActiveSliceAssignment, active_count: int) -> str:
    if active_count <= 1:
        return "single active assignment"
    if assignment.classification == "safe":
        return "safe if domains stay disjoint"
    if assignment.classification == "conditional":
        return "conditional"
    return "not parallelizable"


def roadmap_node_work_text(node: dict[str, Any]) -> str:
    parts = [
        f"maturity: {capability_maturity_text(node)}",
        f"status: {status_label(node.get('status'))}",
        f"selection: {status_label(node.get('execution', {}).get('assignment'))}",
        f"owner: {owner_label(node.get('owner', 'unassigned'))}",
    ]
    return f"{node['title']} (`{node['id']}`) - " + "; ".join(parts)


def blocker_explanations(node: dict[str, Any], node_by_id: dict[str, dict[str, Any]]) -> tuple[str, ...]:
    blockers = list(dependency_readiness(node, node_by_id).blockers)
    maturity = capability_maturity(node)
    if maturity == "captured":
        blockers.insert(0, "Architecture or product direction is captured, but the slice is not implementation-ready.")
    elif maturity == "gated" and not blockers:
        blockers.insert(0, "Capability maturity is gated; declare satisfied prerequisites and move it to ready before selection.")
    return tuple(blockers)


def render_next_work_markdown(context: dict[str, Any], heading_level: int = 2) -> str:
    shared = context["shared"]
    nodes = roadmap_nodes(shared)
    node_by_id = {node["id"]: node for node in nodes}
    summary = next_work_summary(shared)
    heading = "#" * heading_level
    subheading = "#" * (heading_level + 1)
    lines = [
        f"{heading} What Can Be Worked On Next",
        "",
        f"{subheading} Current Capability Frontier",
        "",
    ]
    if summary.primary_frontier:
        lines.append(
            f"- Primary Capability Frontier: {summary.primary_frontier['title']} (`{summary.primary_frontier['id']}`)"
        )
    else:
        lines.append("- Primary Capability Frontier: none")
    if summary.frontier_active_or_selected:
        lines.append("- Active or selected slices in the frontier:")
        for node in summary.frontier_active_or_selected:
            lines.append(f"  - {roadmap_node_work_text(node)}")
    else:
        lines.append("- Active or selected slices in the frontier: none")

    lines.extend(["", f"{subheading} Active Implementation", ""])
    if summary.active:
        for node in summary.active:
            lines.append(f"- {roadmap_node_work_text(node)}")
    else:
        lines.append("- None.")

    lines.extend(["", f"{subheading} Selected Next", ""])
    if summary.selected_next:
        for node in summary.selected_next:
            readiness = dependency_readiness(node, node_by_id)
            lines.append(f"- {roadmap_node_work_text(node)}; dependency status: {readiness_status_text(readiness)}")
    else:
        lines.append("- None.")

    lines.extend(["", f"{subheading} Ready Candidates", ""])
    if summary.ready_candidates:
        for node in summary.ready_candidates:
            lines.append(f"- {roadmap_node_work_text(node)}")
    else:
        lines.append("- None.")

    lines.extend(["", f"{subheading} Gated / Blocked Downstream Work", ""])
    if summary.gated_or_blocked:
        for node in summary.gated_or_blocked:
            lines.append(f"- {roadmap_node_work_text(node)}")
            for blocker in blocker_explanations(node, node_by_id):
                lines.append(f"  - {blocker}")
    else:
        lines.append("- None.")

    return "\n".join(lines).rstrip() + "\n"


def render_next_work_text(context: dict[str, Any]) -> str:
    shared = context["shared"]
    nodes = roadmap_nodes(shared)
    node_by_id = {node["id"]: node for node in nodes}
    summary = next_work_summary(shared)
    lines: list[str] = ["Primary frontier:"]
    if summary.primary_frontier:
        lines.append(f"  {summary.primary_frontier['title']} ({summary.primary_frontier['id']})")
    else:
        lines.append("  none")

    lines.append("")
    lines.append("Frontier active or selected:")
    if summary.frontier_active_or_selected:
        for node in summary.frontier_active_or_selected:
            lines.append(f"  - {roadmap_node_work_text(node)}")
    else:
        lines.append("  none")

    for label, items in (
        ("Current", summary.active),
        ("Selected next", summary.selected_next),
        ("Ready", summary.ready_candidates),
    ):
        lines.extend(["", f"{label}:"])
        if items:
            for node in items:
                lines.append(f"  - {roadmap_node_work_text(node)}")
        else:
            lines.append("  none")

    lines.extend(["", "Gated:"])
    if summary.gated_or_blocked:
        for node in summary.gated_or_blocked:
            lines.append(f"  - {roadmap_node_work_text(node)}")
            for blocker in blocker_explanations(node, node_by_id):
                lines.append(f"    - {blocker}")
    else:
        lines.append("  none")

    return "\n".join(lines).rstrip() + "\n"


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
        ]
    )
    lines.extend(render_next_work_markdown(context, 2).rstrip().splitlines())
    lines.extend(
        [
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
    ]
    lines.extend(render_next_work_markdown(context, 2).rstrip().splitlines())
    lines.extend(["", "## Roadmap Tree", ""])

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
        if node.get("capability_maturity"):
            parts.append(f"maturity: {status_label(node['capability_maturity'])}")

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
        parallelism = node.get("parallelism", {})
        for label, key in (
            ("Expected contract domains", "expected_contract_domains"),
            ("Expected code areas", "expected_code_areas"),
            ("Likely conflict domains", "likely_conflict_domains"),
            ("Contract dependencies", "contract_dependencies"),
        ):
            text = metadata_list_text(parallelism.get(key))
            if text:
                detail_lines.append(f"{label}: {text}")
        if parallelism.get("worktree_required") is True:
            detail_lines.append("Worktree required: true")
        if parallelism.get("conflict_note"):
            detail_lines.append(f"Conflict note: {parallelism['conflict_note']}")
        execution = node.get("execution", {})
        active_fields = []
        for label, key in (
            ("worktree", "active_worktree"),
            ("branch", "active_branch"),
            ("agent", "active_agent"),
            ("session", "active_session"),
        ):
            if execution.get(key):
                active_fields.append(f"{label}: `{execution[key]}`")
        if active_fields:
            detail_lines.append("Active assignment: " + "; ".join(active_fields))
        if execution.get("notes"):
            detail_lines.append(f"Execution notes: {execution['notes']}")
        for gate in roadmap_gates(node):
            requires = gate["requires"]
            detail_lines.append(
                f"Gate `{gate['id']}`: requires `{requires['node']}` maturity {requires['maturity']}; reason: {gate['reason']}"
            )
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

    active_assignments = active_slice_assignments(nodes)
    node_by_id = {node["id"]: node for node in nodes}
    candidates = implementation_candidate_nodes(nodes)
    selected_nodes = selected_next_nodes(nodes)
    ready_nodes = dependency_ready_nodes(nodes)
    ready_but_not_selected = [
        node
        for node in ready_nodes
        if node.get("execution", {}).get("assignment") != SELECTED_NEXT_ASSIGNMENT
    ]
    lines.extend(
        [
            "",
            "## Parallel Worktree Preflight",
            "",
            "Active assignments are derived from roadmap slice nodes with `status: active` or `execution.assignment: current`.",
            "",
        ]
    )
    if active_assignments:
        lines.extend(
            [
                "| Slice | Parallelism | Worktree | Branch | Agent/session | Conflict domains | Contract dependencies | Safety |",
                "| --- | --- | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for assignment in active_assignments:
            agent_session = assignment.active_agent or assignment.active_session or "None"
            lines.append(
                "| "
                f"{assignment.title} (`{assignment.node_id}`) | "
                f"{status_label(assignment.classification)} | "
                f"{assignment.active_worktree or 'None'} | "
                f"{assignment.active_branch or 'None'} | "
                f"{agent_session} | "
                f"{optional_metadata_text(tuple(sorted(assignment.likely_conflict_domains)))} | "
                f"{optional_metadata_text(tuple(sorted(assignment.contract_dependencies)))} | "
                f"{active_assignment_safety_text(assignment, len(active_assignments))} |"
            )
    else:
        lines.append("- Active implementation assignments: none selected.")

    lines.extend(["", "### Dependency-Ready Preflight", ""])
    if candidates:
        lines.extend(
            [
                "| Slice | Selection | Dependency status | Parallelism | Worktree required | Conflict domains | Contract dependencies | Expected contract domains | Expected code areas |",
                "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for node in candidates:
            parallelism = node.get("parallelism", {})
            readiness = dependency_readiness(node, node_by_id)
            lines.append(
                "| "
                f"{node['title']} (`{node['id']}`) | "
                f"{status_label(node.get('execution', {}).get('assignment'))} | "
                f"{readiness_status_text(readiness)} | "
                f"{status_label(parallelism.get('classification'))} | "
                f"{status_label(parallelism.get('worktree_required', False))} | "
                f"{optional_metadata_text(parallelism.get('likely_conflict_domains'))} | "
                f"{optional_metadata_text(parallelism.get('contract_dependencies'))} | "
                f"{optional_metadata_text(parallelism.get('expected_contract_domains'))} | "
                f"{optional_metadata_text(parallelism.get('expected_code_areas'))} |"
            )
    else:
        lines.append("None.")

    lines.extend(["", "## Dependency-Ready Work", ""])
    if ready_nodes:
        for node in ready_nodes:
            depends_on = reference_list_text(node.get("depends_on")) or "None"
            selection = status_label(node.get("execution", {}).get("assignment"))
            lines.append(f"- {node['title']} (`{node['id']}`) - selection: {selection}; depends on: {depends_on}")
    else:
        lines.append("None.")

    lines.extend(["", "## Selected Next Work", ""])
    if selected_nodes:
        for node in selected_nodes:
            depends_on = reference_list_text(node.get("depends_on")) or "None"
            readiness = dependency_readiness(node, node_by_id)
            lines.append(
                f"- {node['title']} (`{node['id']}`) - dependency status: {readiness_status_text(readiness)}; depends on: {depends_on}"
            )
    else:
        lines.append("None.")

    lines.extend(["", "## Dependency-Ready But Not Selected", ""])
    if ready_but_not_selected:
        for node in ready_but_not_selected:
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
    re.compile(r"\bstill out of scope until (?:a )?new slice is explicitly selected\b", re.IGNORECASE),
    re.compile(r"\b(?:ui work|bmux ui presentation)[^.\n]*remain(?:s)? planned(?: and gated)?\b", re.IGNORECASE),
    re.compile(r"\bCI enforcement is not implemented yet\b", re.IGNORECASE),
    re.compile(r"\blatest tag:\s*`?[^`\n]+`?", re.IGNORECASE),
    re.compile(r"\brelease status:\s*`?[^`\n]+`?", re.IGNORECASE),
)


AUTHORED_DOCS = (
    "docs/current-and-target-architecture.md",
    "docs/current-status.md",
    "docs/roadmap.md",
    "docs/session-work-model.md",
    "docs/handoffs/latest.md",
    "docs/execution-telemetry/implementation-status.md",
    "project/README.md",
)

AUTHORED_GENERATED_DOCS = (
    "docs/current-and-target-architecture.md",
)

ARCHITECTURE_NODE_SUMMARIES = (
    {
        "title": "Bmux provider acquisition and runtime observation",
        "status_node_ids": (
            "execution_telemetry_foundation",
            "claude_lifecycle_telemetry",
        ),
        "capability_ids": (),
        "owns": "Provider acquisition, PTY/process/runtime, live streaming state, immediate interaction, normalization, capture policy, and presentation/UI.",
        "inputs": "Provider runtime events, terminal/process state, user interaction, repository/worktree facts observed by bmux.",
        "outputs": "Normalized accepted evidence submitted through Provenance Engine public contracts, plus bmux-owned live display state.",
        "does_not_own": "Durable evidence semantics, deterministic Current State, semantic inference, milestone meaning, or Knowledge Compiler outputs.",
        "related_slice_ids": (
            "execution_telemetry_foundation",
            "claude_lifecycle_telemetry",
            "workspace_display_durable_context",
        ),
    },
    {
        "title": "Provenance Engine durable evidence",
        "status_node_ids": (
            "provenance_engine_v1",
            "richer_coding_agent_evidence_foundation",
        ),
        "capability_ids": (
            "public_in_process_sdk",
            "engine_owned_sqlite_store",
            "immutable_ledger",
            "schema_identity_validation",
            "producer_neutral_lifecycle_recording",
            "richer_coding_agent_evidence",
        ),
        "owns": "Accepted durable engineering evidence, validation, immutable ledger semantics, source/origin/scope metadata, and evidence relationships.",
        "inputs": "Explicitly accepted events from producers such as bmux; completed or meaningful coding-agent units when policy allows them.",
        "outputs": "Ledger events and rebuildable evidence relationships for lower projections and later inference.",
        "does_not_own": "Raw provider streams, hidden reasoning, unrestricted transcripts, live replay state, or capture policy.",
        "related_slice_ids": (
            "provenance_engine_v1",
            "richer_coding_agent_evidence_foundation",
        ),
    },
    {
        "title": "Deterministic Current State",
        "status_node_ids": (
            "workspace_display_durable_context",
            "factual_session_projection_foundation",
        ),
        "capability_ids": (
            "deterministic_current_state",
            "workspace_display_current_state",
            "workspace_display_projection_cursors",
            "workspace_display_ticket_link_facts",
            "workspace_display_ticket_title_facts",
            "workspace_display_project_link_facts",
            "workspace_display_durable_context",
        ),
        "owns": "Mechanical, rebuildable present-tense state derived only from accepted evidence.",
        "inputs": "Immutable ledger events and deterministic reducer rules.",
        "outputs": "Workspace display facts, current context, session/worktree/file views, and other factual public reads.",
        "does_not_own": "Intent, milestones, current activity, risk, architecture meaning, or model-derived conclusions.",
        "related_slice_ids": (
            "workspace_display_durable_context",
            "factual_session_projection_foundation",
        ),
    },
    {
        "title": "Factual session projection",
        "status_node_ids": (
            "factual_session_projection_foundation",
            "factual_projection_consumer_shape_followup",
            "factual_agent_session_view",
        ),
        "capability_ids": (
            "factual_session_projection",
        ),
        "owns": "Revisioned factual snapshots of observed coding-agent thread and turn evidence for one PE session.",
        "inputs": "Coding-agent thread, turn, prompt, plan, completed command, visible reasoning summary, and file-change attribution evidence.",
        "outputs": "Observed thread/turn grouping with latest prompt, plan, commands, summaries, file changes, and ledger revision.",
        "does_not_own": "Synthetic turns, inferred intent, milestone hierarchy, session phase, risks, or architecture projection.",
        "related_slice_ids": (
            "richer_coding_agent_evidence_foundation",
            "factual_session_projection_foundation",
            "factual_projection_consumer_shape_followup",
            "factual_agent_session_view",
        ),
    },
    {
        "title": "Semantic inference framework",
        "status_node_ids": (
            "semantic_inference_framework",
            "first_semantic_session_inferences",
        ),
        "capability_ids": (
            "semantic_inference_framework",
            "semantic_session_work_model_projection",
        ),
        "owns": "Evidence-backed inference records, producer versions, confidence, supersession, and semantic projection updates.",
        "inputs": "Factual projections, bounded evidence packets, plans, commands, reasoning summaries, file changes, and later validation evidence.",
        "outputs": "Thread intent, turn intent, session phase, current activity, blocker/approach-change facts, and SessionWorkModel fields.",
        "does_not_own": "Deterministic Current State or bmux rendering and interaction policy.",
        "related_slice_ids": (
            "semantic_inference_framework",
            "first_semantic_session_inferences",
            "blocker_approach_change_semantics",
        ),
    },
    {
        "title": "SessionWorkModel semantic projection",
        "status_node_ids": (
            "semantic_session_work_model_projection",
            "first_semantic_session_inferences",
        ),
        "capability_ids": (
            "semantic_session_work_model_projection",
        ),
        "owns": "A coherent semantic view of one live coding-agent session with provenance on every non-observed field.",
        "inputs": "Deterministic factual session projection plus active inference records.",
        "outputs": "Subject, thread, current turn, current activity, milestones, validation/risk state, scoped architecture, and provenance metadata.",
        "does_not_own": "Lower-level public APIs or durable compiled knowledge that outlives the live session.",
        "related_slice_ids": (
            "semantic_session_work_model_projection",
            "first_semantic_session_inferences",
            "human_readable_semantic_messaging",
        ),
    },
    {
        "title": "Milestone semantics",
        "status_node_ids": (
            "milestone_inference",
            "milestone_to_code_relationships",
        ),
        "capability_ids": (),
        "owns": "Evidence-backed milestone hierarchy, descriptions, current focus, completion criteria, and relationships to code evidence.",
        "inputs": "Plans, prompts, command/file-change evidence, validation facts, reasoning summaries, and later Git/GitHub evidence.",
        "outputs": "Nested live milestones and milestone-to-code relationships for SessionWorkModel and later knowledge compilation.",
        "does_not_own": "bmux todo rendering or the assumption that commits and PRs are milestone boundaries.",
        "related_slice_ids": (
            "milestone_inference",
            "milestone_to_code_relationships",
        ),
    },
    {
        "title": "Scoped architecture projection",
        "status_node_ids": (
            "scoped_architecture_projection",
            "milestone_to_architecture_relationships",
        ),
        "capability_ids": (
            "scoped_architecture_projection",
        ),
        "owns": "Thread-scoped and current-turn-scoped touched, affected, and contextual architecture subgraphs.",
        "inputs": "Evidence-backed file/symbol relationships, diffs, docs, plans, reasoning summaries, and inference records.",
        "outputs": "Small scoped architecture projections and milestone-to-architecture links.",
        "does_not_own": "Whole-repository diagrams or unsupported architectural claims.",
        "related_slice_ids": (
            "scoped_architecture_projection",
            "milestone_to_architecture_relationships",
        ),
    },
    {
        "title": "Knowledge Compiler, Knowledge Store, and Retrieval",
        "status_node_ids": (
            "knowledge_compiler_outcomes",
        ),
        "capability_ids": (),
        "owns": "Later durable knowledge artifacts, evidence-linked regeneration, scoped storage, retrieval, citation, ranking, and context budgeting.",
        "inputs": "Evidence, Current State, inference records, milestones, architecture relationships, Git/GitHub/review/document evidence, and accepted human decisions.",
        "outputs": "Compiled knowledge, knowledge indexes, and bounded context packages for agents, bmux, CLI, IDEs, and organization services.",
        "does_not_own": "The live session model's immediate interaction loop or consumer-specific UI presentation.",
        "related_slice_ids": (
            "knowledge_compiler_outcomes",
        ),
    },
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


def roadmap_node_map(shared: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {node["id"]: node for node in roadmap_nodes(shared)}


def roadmap_node_status_text(nodes: dict[str, dict[str, Any]], node_id: str) -> str:
    node = nodes.get(node_id)
    if not node:
        return f"`{node_id}`: missing"
    parts = [status_label(node["status"])]
    delivery = node.get("delivery_status")
    acceptance = node.get("acceptance_status")
    if delivery:
        parts.append(f"delivery {status_label(delivery)}")
    if acceptance:
        parts.append(f"acceptance {status_label(acceptance)}")
    return f"{node['title']} (`{node_id}`): " + ", ".join(parts)


def capability_status_text(repo_status: dict[str, Any], capability_id: str) -> str:
    capabilities = repo_status.get("local_capabilities", {})
    if capability_id not in capabilities:
        return f"{titleize(capability_id)}: not listed"
    return f"{titleize(capability_id)}: {status_label(capabilities[capability_id])}"


def architecture_node_status_text(
    shared: dict[str, Any],
    repo_status: dict[str, Any],
    entry: dict[str, Any],
) -> str:
    nodes = roadmap_node_map(shared)
    parts: list[str] = []
    for node_id in entry["status_node_ids"]:
        parts.append(roadmap_node_status_text(nodes, node_id))
    for capability_id in entry["capability_ids"]:
        parts.append(capability_status_text(repo_status, capability_id))
    return "; ".join(parts) if parts else "None recorded"


def related_slices_text(shared: dict[str, Any], slice_ids: tuple[str, ...]) -> str:
    nodes = roadmap_node_map(shared)
    parts: list[str] = []
    for slice_id in slice_ids:
        node = nodes.get(slice_id)
        if node:
            parts.append(f"{node['title']} (`{slice_id}`)")
        else:
            parts.append(f"`{slice_id}`")
    return ", ".join(parts) if parts else "None"


def render_current_target_architecture_status(context: dict[str, Any]) -> str:
    shared = context["shared"]
    repo_status = context["repo_status"]
    nodes = roadmap_node_map(shared)
    gate = shared["cross_repository"]["active_gate"]
    active_slice = repo_status["current_work"].get("active_slice")
    current_nodes = [
        node
        for node in roadmap_nodes(shared)
        if node.get("execution", {}).get("assignment") == "current"
    ]
    all_nodes = roadmap_nodes(shared)
    node_by_id = {node["id"]: node for node in all_nodes}
    next_summary = next_work_summary(shared)
    selected_nodes = selected_next_nodes(all_nodes)
    ready_nodes = dependency_ready_nodes(all_nodes)
    ready_but_not_selected = [
        node
        for node in ready_nodes
        if node.get("execution", {}).get("assignment") != SELECTED_NEXT_ASSIGNMENT
    ]
    open_caveats = [caveat for caveat in shared.get("caveats", []) if caveat["status"] in ("open", "monitoring")]

    lines = [
        "Generated from `project/project-state.yaml` and `project/repo-status.yaml`. "
        "For the full generated views, see "
        "[project status](generated/project-status.md), "
        "[repository status](generated/repository-status.md), and "
        "[nested roadmap](generated/nested-roadmap.md).",
        "",
        "### Current Active Work",
        "",
        f"- Active gate: {gate['title']} (`{gate['id']}`) - {status_label(gate['status'])}",
    ]
    if next_summary.primary_frontier:
        lines.append(
            f"- Primary capability frontier: {next_summary.primary_frontier['title']} (`{next_summary.primary_frontier['id']}`)"
        )
    else:
        lines.append("- Primary capability frontier: none")
    if isinstance(active_slice, dict) and active_slice.get("id"):
        lines.append(
            f"- Active implementation slice: {active_slice['title']} (`{active_slice['id']}`) - {status_label(active_slice['state'])}"
        )
    else:
        lines.append("- Active implementation slice: none selected")
    repo_label = repository_label_for_slug(shared, repo_status["repository"])
    lines.append(f"- {repo_label} repository state: {status_label(repo_status['current_work'].get('state'))}")

    lines.extend(["", "### Current Roadmap Lanes", ""])
    if current_nodes:
        for node in current_nodes:
            lines.append(
                f"- {node['title']} (`{node['id']}`) - {node['kind']}; "
                f"status: {status_label(node['status'])}; owner: {owner_label(node['owner'])}"
            )
    else:
        lines.append("- None.")

    lines.extend(["", "### Major Node Summaries", ""])
    for entry in ARCHITECTURE_NODE_SUMMARIES:
        lines.extend(
            [
                f"#### {entry['title']}",
                "",
                f"- Status: {architecture_node_status_text(shared, repo_status, entry)}",
                f"- Owns: {entry['owns']}",
                f"- Inputs: {entry['inputs']}",
                f"- Outputs: {entry['outputs']}",
                f"- Does not own: {entry['does_not_own']}",
                f"- Related slices: {related_slices_text(shared, entry['related_slice_ids'])}",
                "",
            ]
        )

    lines.extend(["### Dependency-Ready Work", ""])
    if ready_nodes:
        for node in ready_nodes:
            depends_on = reference_list_text(node.get("depends_on")) or "None"
            rationale = f" Rationale: {node['rationale']}" if node.get("rationale") else ""
            lines.append(
                f"- {node['title']} (`{node['id']}`) - selection: {status_label(node.get('execution', {}).get('assignment'))}; "
                f"owner: {owner_label(node['owner'])}; depends on: {depends_on}.{rationale}"
            )
    else:
        lines.append("- None.")

    lines.extend(["", "### Selected Next Work", ""])
    if selected_nodes:
        for node in selected_nodes:
            depends_on = reference_list_text(node.get("depends_on")) or "None"
            readiness = dependency_readiness(node, node_by_id)
            rationale = f" Rationale: {node['rationale']}" if node.get("rationale") else ""
            lines.append(
                f"- {node['title']} (`{node['id']}`) - dependency status: {readiness_status_text(readiness)}; "
                f"owner: {owner_label(node['owner'])}; depends on: {depends_on}.{rationale}"
            )
    else:
        lines.append("- None.")

    lines.extend(["", "### Dependency-Ready But Not Selected", ""])
    if ready_but_not_selected:
        for node in ready_but_not_selected:
            depends_on = reference_list_text(node.get("depends_on")) or "None"
            lines.append(
                f"- {node['title']} (`{node['id']}`) - owner: {owner_label(node['owner'])}; depends on: {depends_on}"
            )
    else:
        lines.append("- None.")

    lines.extend(["", "### Gated / Blocked Downstream Work", ""])
    gated_nodes = gated_or_blocked_nodes(all_nodes)
    if gated_nodes:
        for node in gated_nodes:
            lines.append(f"- {roadmap_node_work_text(node)}")
            for blocker in blocker_explanations(node, node_by_id):
                lines.append(f"  - {blocker}")
    else:
        lines.append("- None.")

    lines.extend(["", "### Open Caveats", ""])
    if open_caveats:
        for caveat in open_caveats:
            issue = caveat.get("issue")
            issue_text = f"; issue: {issue['repository']}#{issue['number']}" if issue else ""
            lines.append(
                f"- {caveat['title']} (`{caveat['id']}`) - owner: {owner_label(caveat['owner'])}; "
                f"status: {status_label(caveat['status'])}{issue_text}"
            )
    else:
        lines.append("- None.")

    return "\n".join(lines).rstrip() + "\n"


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


def render_authored_generated_blocks(context: dict[str, Any], relative: str, text: str) -> str:
    if relative == "docs/current-and-target-architecture.md":
        return replace_generated_block(
            text,
            "current-target-architecture-status",
            render_current_target_architecture_status(context),
        )
    raise ProjectDocsError(f"{relative}: no generated-block renderer is registered")


def write_authored_generated_blocks(context: dict[str, Any]) -> None:
    repo_root = context["repo_root"]
    for relative in AUTHORED_GENERATED_DOCS:
        path = repo_root / relative
        if not path.exists():
            raise ProjectDocsError(f"{relative}: authored generated-block document is missing")
        text = path.read_text(encoding="utf-8")
        updated = render_authored_generated_blocks(context, relative, text)
        if updated != text:
            path.write_text(updated, encoding="utf-8")


def authored_generated_block_drift_issues(context: dict[str, Any]) -> list[ValidationIssue]:
    repo_root = context["repo_root"]
    issues: list[ValidationIssue] = []
    for relative in AUTHORED_GENERATED_DOCS:
        path = repo_root / relative
        if not path.exists():
            issues.append(ValidationIssue("generation", "authored_generated_blocks_fresh", relative, "authored generated-block document is missing"))
            continue
        try:
            text = path.read_text(encoding="utf-8")
            updated = render_authored_generated_blocks(context, relative, text)
        except ProjectDocsError as exc:
            issues.append(ValidationIssue("generation", "authored_generated_blocks_fresh", relative, str(exc)))
            continue
        if updated != text:
            issues.append(ValidationIssue("generation", "authored_generated_blocks_fresh", relative, "generated block is stale; regenerate with ./scripts/project-docs generate"))
    return issues


def check_authored_generated_blocks(context: dict[str, Any]) -> None:
    repo_root = context["repo_root"]
    stale: list[str] = []
    for relative in AUTHORED_GENERATED_DOCS:
        path = repo_root / relative
        if not path.exists():
            stale.append(relative)
            continue
        text = path.read_text(encoding="utf-8")
        try:
            updated = render_authored_generated_blocks(context, relative, text)
        except ProjectDocsError as exc:
            raise ProjectDocsError(f"{relative}: {exc}") from exc
        if updated != text:
            stale.append(relative)
            diff = difflib.unified_diff(
                text.splitlines(),
                updated.splitlines(),
                fromfile=relative,
                tofile=f"generated-blocks/{relative}",
                lineterm="",
            )
            sys.stderr.write("\n".join(diff) + "\n")
    if stale:
        formatted = "\n".join(f"- {path}" for path in stale)
        raise ProjectDocsError(
            "[generation:authored_generated_blocks_fresh] Authored generated blocks are stale:\n"
            f"{formatted}\nRegenerate with: ./scripts/project-docs generate"
        )


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
    write_authored_generated_blocks(context)


def command_check(args: argparse.Namespace) -> None:
    context = load_inputs(Path(args.repo_root), args.shared_state)
    ensure_generated_warning(context["repo_root"])
    check_generated(context)
    check_authored_generated_blocks(context)


def command_next(args: argparse.Namespace) -> None:
    context = load_inputs(Path(args.repo_root), args.shared_state)
    sys.stdout.write(render_next_work_text(context))


def github_provider_from_environment() -> GitHubRestEvidenceProvider:
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    return GitHubRestEvidenceProvider(token=token, api_url=os.environ.get("GITHUB_API_URL"))


def command_reconcile(args: argparse.Namespace) -> None:
    if not args.reconcile_check and not args.reconcile_apply:
        raise ProjectDocsError("reconcile requires --check or --apply")
    try:
        context = load_inputs(Path(args.repo_root), args.shared_state)
    except ProjectDocsError as exc:
        raise ProjectDocsError(str(exc), exit_code=3) from exc
    repo_statuses = [context["repo_status"]]
    plan = reconciliation_plan(context["shared"], repo_statuses, github_provider_from_environment())
    sys.stdout.write(format_reconciliation_plan(plan, include_apply_hint=args.reconcile_check))

    exit_code = reconciliation_exit_code(plan)
    if args.reconcile_check:
        if exit_code != 0:
            raise ProjectDocsError("post-merge reconciliation is required", exit_code=exit_code)
        return

    if plan.issues:
        raise ProjectDocsError("cannot apply reconciliation while evidence or state failures remain", exit_code=exit_code)
    if not plan.changes:
        if plan.decisions:
            raise ProjectDocsError("no safe changes apply; explicit planning decisions remain", exit_code=exit_code)
        return
    write_reconciled_files_atomically(context, plan)
    if plan.decisions:
        raise ProjectDocsError("safe reconciliation changes were applied; explicit planning decisions remain", exit_code=exit_code)


def command_ci(args: argparse.Namespace) -> None:
    context = load_inputs(Path(args.repo_root), args.shared_state)
    repo_statuses = [context["repo_status"]]
    repo_status_paths = {context["repo_status"].get("repository", "<current>"): context["repo_status_path"]}

    issues: list[ValidationIssue] = []
    issues.extend(invariant_issues(context["shared"], repo_statuses, repo_status_paths))
    issues.extend(validate_shared_source_issues(context))
    ensure_generated_warning(context["repo_root"])
    issues.extend(generated_drift_issues(context))
    issues.extend(authored_generated_block_drift_issues(context))
    issues.extend(authored_doc_drift_issues(context["repo_root"]))

    if not args.skip_github:
        provider = github_provider_from_environment()
        plan = reconciliation_plan(context["shared"], repo_statuses, provider, discover_active_branches=False)
        github_issues = github_evidence_issues(context["shared"], repo_statuses, provider)
        if args.allow_reconciliation_decisions:
            github_issues = filter_allowed_reconciliation_decision_issues(github_issues, plan)
        issues.extend(github_issues)
        issues.extend(reconciliation_ci_issues(plan, allow_decisions=args.allow_reconciliation_decisions))

    raise_issues(issues)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and render project truth documentation.")
    parser.add_argument("command", choices=("validate", "generate", "check", "next", "ci", "reconcile"))
    parser.add_argument("--repo-root", default=os.getcwd())
    parser.add_argument("--shared-state", default=None)
    parser.add_argument("--require-generated", action="store_true")
    parser.add_argument("--skip-github", action="store_true", help="Skip live GitHub evidence verification. Do not use in CI.")
    parser.add_argument(
        "--allow-reconciliation-decisions",
        action="store_true",
        help="Allow explicit planning decisions while still failing on reconciliation issues and safe changes.",
    )
    reconcile_group = parser.add_mutually_exclusive_group()
    reconcile_group.add_argument("--check", dest="reconcile_check", action="store_true", help="Check post-merge reconciliation without writing files.")
    reconcile_group.add_argument("--apply", dest="reconcile_apply", action="store_true", help="Apply safe post-merge reconciliation changes and regenerate docs.")
    args = parser.parse_args(argv)

    try:
        if args.command == "validate":
            command_validate(args)
        elif args.command == "generate":
            command_generate(args)
        elif args.command == "check":
            command_check(args)
        elif args.command == "next":
            command_next(args)
        elif args.command == "ci":
            command_ci(args)
        elif args.command == "reconcile":
            command_reconcile(args)
        return 0
    except ProjectDocsError as exc:
        sys.stderr.write(f"project-docs: {exc}\n")
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
