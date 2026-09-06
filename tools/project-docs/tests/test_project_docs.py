from __future__ import annotations

import copy
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import project_docs


ROOT = Path(__file__).resolve().parents[3]
SHARED = ROOT / "project" / "project-state.yaml"
LOCAL = ROOT / "project" / "repo-status.yaml"
PROJECT_TRUTH_WORKFLOW = ROOT / ".github" / "workflows" / "project-truth.yml"
PROJECT_TRUTH_RECONCILE_WORKFLOW = ROOT / ".github" / "workflows" / "project-truth-reconcile.yml"


class FakeGitHubProvider:
    def __init__(self):
        self.repositories: set[str] = set()
        self.commits: set[tuple[str, str]] = set()
        self.reachable_commits: set[tuple[str, str]] = set()
        self.pull_requests: dict[tuple[str, int], project_docs.PullRequestEvidence] = {}
        self.pull_requests_by_head: dict[tuple[str, str, str], list[project_docs.PullRequestEvidence]] = {}
        self.issues: dict[tuple[str, int], project_docs.IssueEvidence] = {}
        self.tags: dict[tuple[str, str], project_docs.TagEvidence] = {}
        self.releases: set[tuple[str, str]] = set()
        self.failures: dict[tuple[str, str], project_docs.GitHubProviderError] = {}

    def _maybe_fail(self, kind: str, key: str) -> None:
        failure = self.failures.get((kind, key))
        if failure:
            raise failure

    def repository_exists(self, repository: str) -> bool:
        self._maybe_fail("repository", repository)
        return repository in self.repositories

    def commit_exists(self, repository: str, sha: str) -> bool:
        self._maybe_fail("commit", f"{repository}@{sha}")
        return (repository, sha) in self.commits

    def commit_reachable_from_default_branch(self, repository: str, sha: str) -> bool:
        self._maybe_fail("commit_reachable", f"{repository}@{sha}")
        return (repository, sha) in self.reachable_commits

    def pull_request(self, repository: str, number: int):
        self._maybe_fail("pull_request", f"{repository}#{number}")
        return self.pull_requests.get((repository, number))

    def pull_requests_for_head(self, repository: str, owner: str, branch: str):
        self._maybe_fail("pull_requests_for_head", f"{repository}:{owner}:{branch}")
        return self.pull_requests_by_head.get((repository, owner, branch), [])

    def issue(self, repository: str, number: int):
        self._maybe_fail("issue", f"{repository}#{number}")
        return self.issues.get((repository, number))

    def tag(self, repository: str, tag: str):
        self._maybe_fail("tag", f"{repository}@{tag}")
        return self.tags.get((repository, tag))

    def release_exists(self, repository: str, tag: str) -> bool:
        self._maybe_fail("release", f"{repository}@{tag}")
        return (repository, tag) in self.releases


class ProjectDocsTests(unittest.TestCase):
    def mark_dependency_unimplemented(self, shared, node_id: str):
        node = self.roadmap_node(shared, node_id)
        node["status"] = "planned"
        node["execution"]["assignment"] = "planned"
        node["delivery_status"] = "proposed"
        node["acceptance_status"] = "proposed"
        node.pop("capability_maturity", None)
        node.pop("completed_at", None)
        node.pop("accepted_at", None)
        node.pop("acceptance_reason", None)
        return node

    def load_valid(self):
        shared = project_docs.load_yaml(SHARED)
        local = project_docs.load_yaml(LOCAL)
        return shared, local

    def workflow_step(self, workflow_path: Path, job_name: str, step_name: str):
        workflow = project_docs.load_yaml(workflow_path)
        for step in workflow["jobs"][job_name]["steps"]:
            if step.get("name") == step_name:
                return workflow, step
        self.fail(f"{workflow_path}: missing {job_name!r} step {step_name!r}")

    def run_reconcile_writer_workflow_step(self, *, existing_pr: bool) -> list[str]:
        workflow, step = self.workflow_step(
            PROJECT_TRUTH_RECONCILE_WORKFLOW,
            "reconcile",
            "Open or update reconciliation PR",
        )
        self.assertEqual("write", workflow["permissions"]["actions"])

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            scripts_dir = root / "scripts"
            scripts_dir.mkdir()
            command_log = root / "commands.log"

            project_docs_stub = scripts_dir / "project-docs"
            project_docs_stub.write_text(
                """#!/usr/bin/env bash
set -euo pipefail
printf './scripts/project-docs %s\\n' "$*" >> "$COMMAND_LOG"
if [[ "${1:-}" == "reconcile" && "${2:-}" == "--apply" ]]; then
  echo "safe reconciliation changes"
  exit 1
fi
exit 0
""",
                encoding="utf-8",
            )
            project_docs_stub.chmod(0o755)

            git_stub = bin_dir / "git"
            git_stub.write_text(
                """#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\\n' "$*" >> "$COMMAND_LOG"
case "${1:-}" in
  rev-parse)
    if [[ "${2:-}" == "HEAD" || "${2:-}" == "origin/main" ]]; then
      echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      exit 0
    fi
    ;;
  diff)
    if [[ "${2:-}" == "--quiet" ]]; then
      exit 1
    fi
    exit 0
    ;;
  ls-remote)
    if [[ "${FAKE_EXISTING_RECONCILIATION_BRANCH:-}" == "1" ]]; then
      printf 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/heads/project-truth/post-merge-reconciliation\n'
    fi
    exit 0
    ;;
  fetch|config|checkout|add|commit|push)
    exit 0
    ;;
esac
echo "unexpected git invocation: $*" >&2
exit 2
""",
                encoding="utf-8",
            )
            git_stub.chmod(0o755)

            gh_stub = bin_dir / "gh"
            gh_stub.write_text(
                """#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\\n' "$*" >> "$COMMAND_LOG"
case "${1:-}:${2:-}" in
  pr:list)
    if [[ "${FAKE_EXISTING_PR:-}" == "1" ]]; then
      echo "123"
    fi
    ;;
  pr:create|pr:edit|workflow:run)
    ;;
  *)
    echo "unexpected gh invocation: $*" >&2
    exit 2
    ;;
esac
""",
                encoding="utf-8",
            )
            gh_stub.chmod(0o755)

            env = os.environ.copy()
            env["COMMAND_LOG"] = str(command_log)
            env["FAKE_EXISTING_PR"] = "1" if existing_pr else "0"
            env["FAKE_EXISTING_RECONCILIATION_BRANCH"] = "1" if existing_pr else "0"
            env["GITHUB_TOKEN"] = "fake-token"
            env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
            env["RECONCILIATION_BRANCH"] = "project-truth/post-merge-reconciliation"

            subprocess.run(
                ["bash"],
                input=step["run"],
                cwd=root,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
            )
            return command_log.read_text(encoding="utf-8").splitlines()

    def roadmap_node(self, shared, node_id: str):
        return next(node for node in shared["roadmap"]["nodes"] if node["id"] == node_id)

    def activate_slice(
        self,
        shared,
        node_id: str,
        *,
        classification: str = "safe",
        worktree: str = "/worktrees/one",
        branch: str = "slice-one",
        agent: str = "agent-one",
        conflict_domains: list[str] | None = None,
        contract_dependencies: list[str] | None = None,
    ):
        node = self.roadmap_node(shared, node_id)
        node["status"] = "active"
        node["capability_maturity"] = "active"
        node["parallelism"]["classification"] = classification
        node["parallelism"]["worktree_required"] = True
        if conflict_domains is not None:
            node["parallelism"]["likely_conflict_domains"] = conflict_domains
        if contract_dependencies is not None:
            node["parallelism"]["contract_dependencies"] = contract_dependencies
        node["parallelism"].pop("conflict_note", None)
        node["execution"]["assignment"] = "current"
        node["execution"]["active_worktree"] = worktree
        node["execution"]["active_branch"] = branch
        node["execution"]["active_agent"] = agent
        return node

    def clear_current_work(self, shared, local, node_id: str = "post_merge_project_truth_reconciliation"):
        node = self.roadmap_node(shared, node_id)
        node["status"] = "implemented"
        node["capability_maturity"] = "validated"
        node["execution"]["assignment"] = "complete"
        node["delivery_status"] = "merged"
        node["acceptance_status"] = "implemented"
        node["evidence"] = {"commits": [{"repository": "BrianBusby/bmux", "sha": "b" * 40}], "pull_requests": []}
        for key in ("active_worktree", "active_branch", "active_agent", "active_session"):
            node["execution"].pop(key, None)
        local["current_work"]["active_slice"] = {"id": None, "title": None, "state": "none_selected"}
        local["current_work"]["state"] = "none_selected"
        return node

    def make_runtime_slice_stale(self, shared, local):
        self.clear_current_work(shared, local)
        node = self.roadmap_node(shared, "deterministic_app_runtime_composition")
        node["status"] = "active"
        node["capability_maturity"] = "active"
        node["execution"]["assignment"] = "current"
        node["execution"]["active_worktree"] = "/Users/brianbusby/repos/.bmux-worktrees/process-integrity-runtime-composition"
        node["execution"]["active_branch"] = "process-integrity-runtime-composition"
        node["execution"]["active_agent"] = "codex"
        node["delivery_status"] = "open"
        node["acceptance_status"] = "proposed"
        node.pop("evidence", None)
        node.pop("completed_at", None)
        local["current_work"]["active_slice"] = {
            "id": "deterministic_app_runtime_composition",
            "title": "Deterministic App Runtime Composition and App-Host Test Isolation",
            "state": "open",
            "owner": "bmux",
            "active_worktree": "/Users/brianbusby/repos/.bmux-worktrees/process-integrity-runtime-composition",
            "active_branch": "process-integrity-runtime-composition",
            "active_agent": "codex",
        }
        local["current_work"]["state"] = "active"
        candidate = self.roadmap_node(shared, "app_runtime_service_lifecycle_migration")
        candidate["capability_maturity"] = "gated"
        return node

    def test_valid_shared_manifest(self):
        shared, local = self.load_valid()
        project_docs.semantic_validate(shared, local, LOCAL)

    def test_nested_roadmap_schema_accepts_fixture(self):
        shared, _ = self.load_valid()
        project_docs.validate_schema(shared, ROOT / "project/schema/project-state.schema.json", SHARED)

    def test_invalid_status_enum_fails_schema(self):
        shared, _ = self.load_valid()
        shared["milestones"][0]["delivery_status"] = "landed"
        with self.assertRaises(project_docs.ProjectDocsError):
            project_docs.validate_schema(shared, ROOT / "project/schema/project-state.schema.json", SHARED)

    def test_duplicate_milestone_id_fails(self):
        shared, local = self.load_valid()
        shared["milestones"].append(copy.deepcopy(shared["milestones"][0]))
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "duplicate milestone id"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_duplicate_roadmap_node_id_fails(self):
        shared, local = self.load_valid()
        shared["roadmap"]["nodes"].append(copy.deepcopy(shared["roadmap"]["nodes"][0]))
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "duplicate roadmap node id"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_roadmap_dependency_id_validation_fails(self):
        shared, local = self.load_valid()
        self.roadmap_node(shared, "factual_projection_consumer_shape_followup")["depends_on"] = ["missing_slice"]
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "reference 'missing_slice' does not exist"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_roadmap_parent_validation_fails(self):
        shared, local = self.load_valid()
        self.roadmap_node(shared, "semantic_understanding")["parent"] = "missing_program"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "parent 'missing_program' does not exist"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_roadmap_parent_kind_validation_fails(self):
        shared, local = self.load_valid()
        non_slice = self.roadmap_node(shared, "semantic_session_work_model_projection")
        non_slice["execution"]["assignment"] = "selected_next"
        self.assertNotIn(non_slice, project_docs.implementation_candidate_nodes(shared["roadmap"]["nodes"]))
        self.roadmap_node(shared, "semantic_inference_framework")["parent"] = "richer_session_understanding"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "slice parent must be milestone"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_roadmap_dependency_cycle_fails(self):
        shared, local = self.load_valid()
        self.roadmap_node(shared, "factual_projection_consumer_shape_followup")["depends_on"] = ["semantic_inference_framework"]
        self.assertTrue(project_docs.is_dependency_satisfied(self.roadmap_node(shared, "semantic_inference_framework")))
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "roadmap dependency/sequence cycle"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_dependency_satisfied_slice_becomes_ready(self):
        shared, _local = self.load_valid()
        dependency = self.roadmap_node(shared, "deterministic_app_runtime_composition")
        dependency["status"] = "implemented"
        dependency["capability_maturity"] = "validated"
        dependency["execution"]["assignment"] = "complete"
        dependency["delivery_status"] = "merged"
        dependency["acceptance_status"] = "implemented"
        dependency["evidence"] = {
            "commits": [{"repository": "BrianBusby/bmux", "sha": "a" * 40}],
            "pull_requests": [],
        }
        candidate = self.roadmap_node(shared, "app_runtime_service_lifecycle_migration")
        candidate["capability_maturity"] = "ready"
        nodes = shared["roadmap"]["nodes"]
        ready_ids = {node["id"] for node in project_docs.dependency_ready_nodes(nodes)}
        self.assertIn("app_runtime_service_lifecycle_migration", ready_ids)
        readiness = project_docs.dependency_readiness(
            candidate,
            {node["id"]: node for node in nodes},
        )
        self.assertTrue(readiness.ready)

    def test_unsatisfied_dependency_remains_gated(self):
        shared, _local = self.load_valid()
        node = self.roadmap_node(shared, "scoped_architecture_projection")
        readiness = project_docs.dependency_readiness(
            node,
            {item["id"]: item for item in shared["roadmap"]["nodes"]},
        )
        self.assertFalse(readiness.ready)
        self.assertTrue(any("milestone_to_code_relationships" in blocker for blocker in readiness.blockers))
        self.assertNotIn(node, project_docs.dependency_ready_nodes(shared["roadmap"]["nodes"]))

    def test_gate_requiring_validated_does_not_pass_when_dependency_is_merely_implemented(self):
        shared, _local = self.load_valid()
        milestone = self.roadmap_node(shared, "milestone_inference")
        milestone["status"] = "implemented"
        milestone["delivery_status"] = "merged"
        milestone["acceptance_status"] = "implemented"
        milestone["capability_maturity"] = "active"
        milestone["execution"]["assignment"] = "complete"
        milestone["evidence"] = {"commits": [{"repository": "BrianBusby/bmux", "sha": "a" * 40}], "pull_requests": []}
        node = self.roadmap_node(shared, "milestone_to_code_relationships")
        readiness = project_docs.dependency_readiness(
            node,
            {item["id"]: item for item in shared["roadmap"]["nodes"]},
        )
        self.assertFalse(readiness.ready)
        self.assertTrue(any("requires validated" in blocker for blocker in readiness.blockers))

    def test_gate_passes_once_required_maturity_is_reached(self):
        shared, _local = self.load_valid()
        milestone = self.roadmap_node(shared, "milestone_inference")
        milestone["status"] = "implemented"
        milestone["delivery_status"] = "merged"
        milestone["acceptance_status"] = "implemented"
        milestone["capability_maturity"] = "validated"
        milestone["execution"]["assignment"] = "complete"
        milestone["evidence"] = {"commits": [{"repository": "BrianBusby/bmux", "sha": "a" * 40}], "pull_requests": []}
        node = self.roadmap_node(shared, "milestone_to_code_relationships")
        readiness = project_docs.dependency_readiness(
            node,
            {item["id"]: item for item in shared["roadmap"]["nodes"]},
        )
        self.assertTrue(readiness.ready)

    def test_gated_slice_cannot_be_selected_next(self):
        shared, local = self.load_valid()
        self.clear_current_work(shared, local)
        node = self.roadmap_node(shared, "milestone_to_code_relationships")
        node["capability_maturity"] = "gated"
        node["execution"]["assignment"] = "selected_next"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "capability_maturity gated cannot be selected_next"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_gated_slice_cannot_be_active_current(self):
        shared, local = self.load_valid()
        self.clear_current_work(shared, local)
        node = self.roadmap_node(shared, "milestone_to_code_relationships")
        node["capability_maturity"] = "gated"
        node["status"] = "active"
        node["execution"]["assignment"] = "current"
        node["execution"]["active_worktree"] = "/worktrees/gated"
        node["execution"]["active_branch"] = "gated"
        node["execution"]["active_agent"] = "agent"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "capability_maturity gated cannot be current or active"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_ready_slice_can_be_selected_next(self):
        shared, local = self.load_valid()
        self.clear_current_work(shared, local)
        selected = self.roadmap_node(shared, "app_runtime_service_lifecycle_migration")
        selected["capability_maturity"] = "ready"
        selected["execution"]["assignment"] = "selected_next"
        self.assertEqual("ready", selected["capability_maturity"])
        self.assertEqual("selected_next", selected["execution"]["assignment"])
        project_docs.semantic_validate(shared, local, LOCAL)

    def test_missing_gate_reference_fails_clearly(self):
        shared, local = self.load_valid()
        self.roadmap_node(shared, "milestone_to_code_relationships")["gates"][0]["requires"]["node"] = "missing_gate_node"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "gate 'milestone_semantics_validated' reference 'missing_gate_node' does not exist"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_generated_next_output_explains_blockers_and_frontier(self):
        context = project_docs.load_inputs(ROOT)
        rendered = project_docs.render_next_work_text(context)
        self.assertIn("Primary frontier:", rendered)
        self.assertIn("Process Integrity (process_integrity)", rendered)
        self.assertIn("Selected next:", rendered)
        self.assertIn("Post-Merge Project Truth Reconciliation and Capability-Frontier Advancement", rendered)
        self.assertIn("Background Service Lifecycle Migration", rendered)
        self.assertIn("Ready:", rendered)

    def test_primary_capability_frontier_renders_in_generated_docs(self):
        context = project_docs.load_inputs(ROOT)
        rendered = project_docs.render_project_status(context)
        self.assertIn("Primary Capability Frontier: Process Integrity (`process_integrity`)", rendered)
        self.assertIn("## What Can Be Worked On Next", rendered)

    def test_historical_accepted_and_observation_nodes_satisfy_dependencies(self):
        shared, local = self.load_valid()
        self.assertTrue(project_docs.is_dependency_satisfied(self.roadmap_node(shared, "bmux_slice_e_adoption")))
        observation = self.roadmap_node(shared, "react_smart_session_initial_work_model_consumer")
        self.assertEqual("under_observation", observation["acceptance_status"])
        self.assertTrue(project_docs.is_dependency_satisfied(observation))
        project_docs.semantic_validate(shared, local, LOCAL)

    def test_accepted_milestone_without_evidence_fails(self):
        shared, local = self.load_valid()
        shared["milestones"][0]["evidence"] = {"commits": [], "pull_requests": []}
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "accepted milestone must have"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_accepted_roadmap_slice_without_evidence_fails(self):
        shared, local = self.load_valid()
        self.roadmap_node(shared, "provenance_engine_v1")["evidence"] = {"commits": [], "pull_requests": []}
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "implemented or accepted roadmap slice must have"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_implemented_roadmap_slice_without_evidence_fails(self):
        shared, local = self.load_valid()
        self.roadmap_node(shared, "factual_session_projection_foundation")["evidence"] = {"commits": [], "pull_requests": []}
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "implemented or accepted roadmap slice must have"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_planned_roadmap_slice_cannot_claim_implemented_acceptance(self):
        shared, local = self.load_valid()
        self.mark_dependency_unimplemented(shared, "human_readable_semantic_messaging")
        selected = self.roadmap_node(shared, "clickable_semantic_explanation_ui")
        selected["execution"]["assignment"] = "selected_next"
        self.assertIn(selected, project_docs.selected_next_nodes(shared["roadmap"]["nodes"]))
        self.assertNotIn(selected, project_docs.dependency_ready_nodes(shared["roadmap"]["nodes"]))
        self.roadmap_node(shared, "clickable_semantic_explanation_ui")["acceptance_status"] = "implemented"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "planned roadmap slice cannot declare"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_active_gate_must_be_active(self):
        shared, local = self.load_valid()
        shared["cross_repository"]["active_gate"]["status"] = "planned"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "active_gate"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_invalid_repository_slug_fails_schema(self):
        shared, _ = self.load_valid()
        shared["project"]["shared_state_owner"] = "not a slug"
        with self.assertRaises(project_docs.ProjectDocsError):
            project_docs.validate_schema(shared, ROOT / "project/schema/project-state.schema.json", SHARED)

    def test_invalid_pr_or_issue_number_fails_schema(self):
        shared, _ = self.load_valid()
        shared["milestones"][2]["evidence"]["pull_requests"][0]["number"] = 0
        with self.assertRaises(project_docs.ProjectDocsError):
            project_docs.validate_schema(shared, ROOT / "project/schema/project-state.schema.json", SHARED)

    def test_invalid_pr_owner_profile_url_fails_schema(self):
        shared, _ = self.load_valid()
        shared["milestones"][2]["evidence"]["pull_requests"][0]["owner"]["profile_url"] = "https://example.com/octocat"
        with self.assertRaises(project_docs.ProjectDocsError):
            project_docs.validate_schema(shared, ROOT / "project/schema/project-state.schema.json", SHARED)

    def test_bot_pr_owner_profile_url_passes_schema(self):
        shared, _ = self.load_valid()
        shared["milestones"][2]["evidence"]["pull_requests"][0]["owner"] = {
            "login": "dependabot[bot]",
            "profile_url": "https://github.com/apps/dependabot",
        }
        project_docs.validate_schema(shared, ROOT / "project/schema/project-state.schema.json", SHARED)

    def test_invalid_commit_sha_fails_schema(self):
        shared, _ = self.load_valid()
        shared["milestones"][0]["evidence"]["commits"][0]["sha"] = "abc123"
        with self.assertRaises(project_docs.ProjectDocsError):
            project_docs.validate_schema(shared, ROOT / "project/schema/project-state.schema.json", SHARED)

    def test_local_manifest_cannot_override_ownership(self):
        shared, local = self.load_valid()
        local["ownership"] = {"durable_evidence": "bmux"}
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "cannot redefine shared ownership"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_deterministic_ordering(self):
        context = project_docs.load_inputs(ROOT)
        first = project_docs.render_all(context)
        second = project_docs.render_all(context)
        shared, _ = self.load_valid()
        ready_first = [item["id"] for item in project_docs.dependency_ready_nodes(shared["roadmap"]["nodes"])]
        ready_second = [item["id"] for item in project_docs.dependency_ready_nodes(shared["roadmap"]["nodes"])]
        self.assertEqual(ready_first, ready_second)
        self.assertEqual(first, second)

    def test_nested_roadmap_rendering_includes_hierarchy_and_next_work(self):
        context = project_docs.load_inputs(ROOT)
        rendered = project_docs.render_nested_roadmap(context)
        self.assertIn("# Nested Roadmap", rendered)
        self.assertIn("Richer Session Understanding", rendered)
        self.assertIn("Semantic SessionWorkModel Projection", rendered)
        self.assertIn("Local Knowledge Compiler", rendered)
        self.assertIn("## What Can Be Worked On Next", rendered)
        self.assertIn(
            "**Semantic inference framework** (`semantic_inference_framework`)",
            rendered,
        )
        self.assertIn("Depends on: `factual_projection_consumer_shape_followup`", rendered)
        self.assertIn("## Dependency-Ready Work", rendered)
        self.assertIn("## Selected Next Work", rendered)
        self.assertNotIn("## Next Eligible Work", rendered)

    def test_nested_roadmap_rendering_is_deterministic(self):
        context = project_docs.load_inputs(ROOT)
        self.assertEqual(project_docs.render_nested_roadmap(context), project_docs.render_nested_roadmap(context))

    def test_identical_output_across_two_generations(self):
        context = project_docs.load_inputs(ROOT)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            project_docs.write_generated(context, out)
            first = {path.name: path.read_text(encoding="utf-8") for path in sorted(out.iterdir())}
            shutil.rmtree(out)
            out.mkdir()
            project_docs.write_generated(context, out)
            second = {path.name: path.read_text(encoding="utf-8") for path in sorted(out.iterdir())}
        self.assertEqual(first, second)

    def test_check_fails_when_generated_file_is_stale(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            (repo / "docs/generated").mkdir(parents=True)
            context = project_docs.load_inputs(repo)
            project_docs.write_generated(context)
            stale = repo / "docs/generated/project-status.md"
            stale.write_text(stale.read_text(encoding="utf-8") + "\nstale\n", encoding="utf-8")
            with self.assertRaisesRegex(project_docs.ProjectDocsError, "stale"):
                project_docs.check_generated(context)

    def test_generated_block_replacement_preserves_authored_prose(self):
        source = "before\n<!-- BEGIN GENERATED: project-summary -->\nold\n<!-- END GENERATED: project-summary -->\nafter\n"
        result = project_docs.replace_generated_block(source, "project-summary", "new")
        self.assertEqual(
            result,
            "before\n<!-- BEGIN GENERATED: project-summary -->\nnew\n<!-- END GENERATED: project-summary -->\nafter\n",
        )

    def test_current_target_architecture_status_block_rendering(self):
        context = project_docs.load_inputs(ROOT)
        rendered = project_docs.render_current_target_architecture_status(context)
        self.assertIn("Active implementation slice:", rendered)
        self.assertIn("Bmux repository state:", rendered)
        self.assertIn("Factual projection consumer shape follow-up", rendered)
        self.assertIn("SessionWorkModel semantic projection", rendered)
        self.assertIn("Knowledge Compiler, Knowledge Store, and Retrieval", rendered)
        self.assertIn("### Dependency-Ready Work", rendered)
        self.assertIn("### Selected Next Work", rendered)
        self.assertIn("### Gated / Blocked Downstream Work", rendered)
        bmux_context = dict(context)
        bmux_context["repo_status"] = dict(context["repo_status"], repository="BrianBusby/bmux")
        self.assertIn("Bmux repository state:", project_docs.render_current_target_architecture_status(bmux_context))

    def test_repository_label_prefers_canonical_repo_for_duplicate_component_slug(self):
        shared, _local = self.load_valid()
        shared["repositories"]["provenance_engine"]["slug"] = "BrianBusby/bmux"
        self.assertEqual("Bmux", project_docs.repository_label_for_slug(shared, "BrianBusby/bmux"))

    def test_authored_generated_block_drift_detects_stale_architecture_doc(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            (repo / "docs").mkdir(parents=True)
            shutil.copy(
                ROOT / "docs/current-and-target-architecture.md",
                repo / "docs/current-and-target-architecture.md",
            )
            context = project_docs.load_inputs(repo)

            project_docs.write_authored_generated_blocks(context)
            self.assertEqual([], project_docs.authored_generated_block_drift_issues(context))

            doc = repo / "docs/current-and-target-architecture.md"
            doc.write_text(
                doc.read_text(encoding="utf-8").replace(
                    "Active implementation slice: Post-Merge Project Truth Reconciliation and Capability-Frontier Advancement",
                    "Active implementation slice: stale",
                    1,
                ),
                encoding="utf-8",
            )
            issues = project_docs.authored_generated_block_drift_issues(context)
            self.assertTrue(any(issue.name == "authored_generated_blocks_fresh" for issue in issues))
            with self.assertRaisesRegex(project_docs.ProjectDocsError, "Authored generated blocks are stale"):
                project_docs.check_authored_generated_blocks(context)

    def test_missing_canonical_monorepo_manifest_fails_clearly(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            (repo / "project").mkdir(parents=True)
            (repo / "project/repo-status.yaml").write_text(
                "schema_version: 1\nrepository: BrianBusby/bmux\ncurrent_work:\n  state: observation\nrelease:\n  latest_tag: null\n  release_status: untagged\nlocal_caveats: []\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(project_docs.ProjectDocsError, "Expected project/project-state.yaml"):
                project_docs.load_inputs(repo)

    def fake_provider_for_current_manifests(self) -> FakeGitHubProvider:
        shared, local = self.load_valid()
        provider = FakeGitHubProvider()
        provider.repositories.update(project_docs.collect_evidence_repositories(shared, [local]))

        def pr_evidence_for_delivery(delivery_status: str, owner: dict, pr: dict):
            if delivery_status == "draft":
                return project_docs.PullRequestEvidence(
                    state="open",
                    draft=True,
                    merged=False,
                    owner_login=owner.get("login"),
                    owner_url=owner.get("profile_url"),
                    number=pr.get("number"),
                    merged_at=pr.get("merged_at"),
                    merge_commit_sha=pr.get("merge_commit_sha"),
                )
            if delivery_status == "open":
                return project_docs.PullRequestEvidence(
                    state="open",
                    draft=False,
                    merged=False,
                    owner_login=owner.get("login"),
                    owner_url=owner.get("profile_url"),
                    number=pr.get("number"),
                    merged_at=pr.get("merged_at"),
                    merge_commit_sha=pr.get("merge_commit_sha"),
                )
            if delivery_status == "closed":
                return project_docs.PullRequestEvidence(
                    state="closed",
                    draft=False,
                    merged=False,
                    owner_login=owner.get("login"),
                    owner_url=owner.get("profile_url"),
                    number=pr.get("number"),
                    merged_at=pr.get("merged_at"),
                    merge_commit_sha=pr.get("merge_commit_sha"),
                )
            return project_docs.PullRequestEvidence(
                state="closed",
                draft=False,
                merged=delivery_status == "merged",
                owner_login=owner.get("login"),
                owner_url=owner.get("profile_url"),
                number=pr.get("number"),
                merged_at=pr.get("merged_at"),
                merge_commit_sha=pr.get("merge_commit_sha"),
            )

        for milestone in shared["milestones"]:
            for commit in milestone["evidence"]["commits"]:
                provider.commits.add((commit["repository"], commit["sha"]))
                provider.reachable_commits.add((commit["repository"], commit["sha"]))
            for pr in milestone["evidence"]["pull_requests"]:
                owner = pr.get("owner", {})
                provider.pull_requests[(pr["repository"], pr["number"])] = pr_evidence_for_delivery(
                    milestone["delivery_status"], owner, pr
                )
        for node in shared["roadmap"]["nodes"]:
            evidence = node.get("evidence", {})
            for commit in evidence.get("commits", []):
                provider.commits.add((commit["repository"], commit["sha"]))
                provider.reachable_commits.add((commit["repository"], commit["sha"]))
            for pr in evidence.get("pull_requests", []):
                owner = pr.get("owner", {})
                provider.pull_requests[(pr["repository"], pr["number"])] = pr_evidence_for_delivery(
                    node.get("delivery_status"), owner, pr
                )
        for caveat in shared["caveats"]:
            issue = caveat.get("issue")
            if issue:
                provider.issues[(issue["repository"], issue["number"])] = project_docs.IssueEvidence(
                    state="open" if caveat["status"] in ("open", "monitoring") else "closed"
                )
        tag = local["release"]["latest_tag"]
        if tag:
            provider.tags[(local["repository"], tag)] = project_docs.TagEvidence(target_sha="a" * 40)
        return provider

    def test_github_evidence_valid_fixture_passes(self):
        shared, local = self.load_valid()
        issues = project_docs.github_evidence_issues(shared, [local], self.fake_provider_for_current_manifests())
        self.assertEqual([], issues)

    def test_missing_commit_fails_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        first_commit = shared["milestones"][0]["evidence"]["commits"][0]
        provider.commits.remove((first_commit["repository"], first_commit["sha"]))
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "missing_commit" for issue in issues))

    def test_commit_in_wrong_repository_fails_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        first_commit = shared["milestones"][0]["evidence"]["commits"][0]
        provider.commits.remove((first_commit["repository"], first_commit["sha"]))
        provider.commits.add(("BrianBusby/not-bmux", first_commit["sha"]))
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "missing_commit" for issue in issues))

    def test_roadmap_evidence_participates_in_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        commit = self.roadmap_node(shared, "canonical_project_truth_manifest")["evidence"]["commits"][0]
        provider.commits.remove((commit["repository"], commit["sha"]))
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "missing_commit" and "roadmap.nodes" in issue.path for issue in issues))

    def test_missing_pr_fails_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        pr = shared["milestones"][2]["evidence"]["pull_requests"][0]
        provider.pull_requests.pop((pr["repository"], pr["number"]))
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "missing_pr" for issue in issues))

    def test_merged_pr_state_mismatch_fails_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        pr = shared["milestones"][2]["evidence"]["pull_requests"][0]
        provider.pull_requests[(pr["repository"], pr["number"])] = project_docs.PullRequestEvidence(
            state="open", draft=False, merged=False
        )
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "pr_merged_state_mismatch" for issue in issues))

    def test_pr_owner_mismatch_fails_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        pr = shared["milestones"][2]["evidence"]["pull_requests"][0]
        provider.pull_requests[(pr["repository"], pr["number"])] = project_docs.PullRequestEvidence(
            state="closed",
            draft=False,
            merged=True,
            owner_login="octocat",
            owner_url="https://github.com/octocat",
        )
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "pr_owner_login_mismatch" for issue in issues))
        self.assertTrue(any(issue.name == "pr_owner_url_mismatch" for issue in issues))

    def test_pr_merge_metadata_mismatch_fails_github_verification(self):
        shared, local = self.load_valid()
        node = self.roadmap_node(shared, "workspace_coding_agent_session_linkage_hardening")
        pr = node["evidence"]["pull_requests"][0]
        pr["merged_at"] = "2026-09-03T20:46:18Z"
        pr["merge_commit_sha"] = "8a0163fe1b72c3f714f5c3a3719a8dfc9114000e"
        provider = self.fake_provider_for_current_manifests()
        provider.pull_requests[(pr["repository"], pr["number"])] = project_docs.PullRequestEvidence(
            state="closed",
            draft=False,
            merged=True,
            owner_login="BrianBusby",
            owner_url="https://github.com/BrianBusby",
            number=pr["number"],
            merged_at="2026-09-03T20:46:19Z",
            merge_commit_sha="c" * 40,
        )

        issues = project_docs.github_evidence_issues(shared, [local], provider)

        self.assertTrue(any(issue.name == "pr_merged_at_mismatch" for issue in issues))
        self.assertTrue(any(issue.name == "pr_merge_commit_mismatch" for issue in issues))

    def test_draft_open_and_closed_pr_mismatches_are_distinct(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        milestone = shared["milestones"][2]
        pr = milestone["evidence"]["pull_requests"][0]

        milestone["delivery_status"] = "draft"
        provider.pull_requests[(pr["repository"], pr["number"])] = project_docs.PullRequestEvidence("open", False, False)
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "pr_draft_state_mismatch" for issue in issues))

        milestone["delivery_status"] = "open"
        provider.pull_requests[(pr["repository"], pr["number"])] = project_docs.PullRequestEvidence("open", True, False)
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "pr_open_state_mismatch" for issue in issues))

        milestone["delivery_status"] = "closed"
        provider.pull_requests[(pr["repository"], pr["number"])] = project_docs.PullRequestEvidence("closed", False, True)
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "pr_closed_state_mismatch" for issue in issues))

    def test_missing_issue_and_tag_fail_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        caveat_issue = next(caveat["issue"] for caveat in shared["caveats"] if "issue" in caveat)
        provider.issues.pop((caveat_issue["repository"], caveat_issue["number"]))
        tag = "v-test-missing"
        local["release"]["latest_tag"] = tag
        provider.tags[(local["repository"], tag)] = project_docs.TagEvidence(target_sha="a" * 40)
        provider.tags.pop((local["repository"], tag))
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "missing_issue" for issue in issues))
        self.assertTrue(any(issue.name == "missing_tag" for issue in issues))

    def test_github_api_failures_are_distinguishable(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        provider.failures[("repository", "BrianBusby/bmux")] = project_docs.GitHubProviderError("rate_limit", "rate limited")
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "rate_limit" for issue in issues))

        provider = self.fake_provider_for_current_manifests()
        provider.failures[("repository", "BrianBusby/bmux")] = project_docs.GitHubProviderError("network", "connection failed")
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "network" for issue in issues))

        provider = self.fake_provider_for_current_manifests()
        provider.failures[("repository", "BrianBusby/bmux")] = project_docs.GitHubProviderError("auth", "denied")
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "auth" for issue in issues))

    def test_issue_state_and_release_mismatches_fail_github_verification(self):
        shared, local = self.load_valid()
        provider = self.fake_provider_for_current_manifests()
        caveat_issue = next(caveat["issue"] for caveat in shared["caveats"] if "issue" in caveat)
        provider.issues[(caveat_issue["repository"], caveat_issue["number"])] = project_docs.IssueEvidence(state="closed")
        tag = "v-test-release"
        local["release"]["latest_tag"] = tag
        local["release"]["release_status"] = "released"
        provider.tags[(local["repository"], tag)] = project_docs.TagEvidence(target_sha="a" * 40)
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "issue_state_mismatch" for issue in issues))
        self.assertTrue(any(issue.name == "missing_release" for issue in issues))

    def test_inactive_slice_cannot_have_active_assignment_metadata(self):
        shared, local = self.load_valid()
        node = self.roadmap_node(shared, "factual_projection_consumer_shape_followup")
        node["execution"]["active_worktree"] = "/worktrees/factual-shape"
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "inactive_slice_has_active_assignment" for issue in issues))

    def test_active_worktree_slice_requires_execution_identity(self):
        shared, local = self.load_valid()
        node = self.activate_slice(shared, "human_readable_semantic_messaging")
        node["execution"].pop("active_worktree")
        node["execution"].pop("active_branch")
        node["execution"].pop("active_agent")
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "active_worktree_required" for issue in issues))
        self.assertTrue(any(issue.name == "active_branch_required" for issue in issues))
        self.assertTrue(any(issue.name == "active_agent_or_session_required" for issue in issues))

    def test_duplicate_active_worktree_fails(self):
        shared, local = self.load_valid()
        self.activate_slice(
            shared,
            "human_readable_semantic_messaging",
            worktree="/worktrees/shared",
            branch="slice-one",
            conflict_domains=["semantic-message-contract"],
            contract_dependencies=["semantic-message-read"],
        )
        self.activate_slice(
            shared,
            "presentation_language_calibration_corpus",
            worktree="/worktrees/shared",
            branch="slice-two",
            agent="agent-two",
            conflict_domains=["presentation-language-corpus"],
            contract_dependencies=["presentation-corpus-write"],
        )
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "unique_active_worktree" for issue in issues))

    def test_duplicate_active_branch_fails(self):
        shared, local = self.load_valid()
        self.activate_slice(
            shared,
            "human_readable_semantic_messaging",
            worktree="/worktrees/one",
            branch="shared-branch",
            conflict_domains=["semantic-message-contract"],
            contract_dependencies=["semantic-message-read"],
        )
        self.activate_slice(
            shared,
            "presentation_language_calibration_corpus",
            worktree="/worktrees/two",
            branch="shared-branch",
            agent="agent-two",
            conflict_domains=["presentation-language-corpus"],
            contract_dependencies=["presentation-corpus-write"],
        )
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "unique_active_branch" for issue in issues))

    def test_safe_active_slices_with_overlapping_conflict_domains_fail(self):
        shared, local = self.load_valid()
        self.activate_slice(
            shared,
            "human_readable_semantic_messaging",
            worktree="/worktrees/one",
            branch="slice-one",
            conflict_domains=["docs/generated"],
            contract_dependencies=["semantic-message-read"],
        )
        self.activate_slice(
            shared,
            "presentation_language_calibration_corpus",
            worktree="/worktrees/two",
            branch="slice-two",
            agent="agent-two",
            conflict_domains=["docs/generated"],
            contract_dependencies=["presentation-corpus-write"],
        )
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "active_safe_conflict_domain_overlap" for issue in issues))

    def test_unknown_parallelism_is_not_safe_for_parallel_active_work(self):
        shared, local = self.load_valid()
        self.activate_slice(
            shared,
            "human_readable_semantic_messaging",
            classification="unknown",
            worktree="/worktrees/one",
            branch="slice-one",
            conflict_domains=["semantic-message-contract"],
            contract_dependencies=["semantic-message-read"],
        )
        self.activate_slice(
            shared,
            "presentation_language_calibration_corpus",
            worktree="/worktrees/two",
            branch="slice-two",
            agent="agent-two",
            conflict_domains=["presentation-language-corpus"],
            contract_dependencies=["presentation-corpus-write"],
        )
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "active_parallelism_unknown" for issue in issues))

    def test_serial_slice_is_not_parallelizable(self):
        shared, local = self.load_valid()
        self.activate_slice(
            shared,
            "milestone_inference",
            classification="serial",
            worktree="/worktrees/one",
            branch="slice-one",
            conflict_domains=["milestone-semantics"],
            contract_dependencies=["semantic-session-inference"],
        )
        self.activate_slice(
            shared,
            "blocker_approach_change_semantics",
            worktree="/worktrees/two",
            branch="slice-two",
            agent="agent-two",
            conflict_domains=["blocker-semantics"],
            contract_dependencies=["approach-change-inference"],
        )
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "active_parallelism_serial" for issue in issues))

    def test_valid_parallel_active_assignments_pass(self):
        shared, local = self.load_valid()
        self.clear_current_work(shared, local)
        self.activate_slice(
            shared,
            "human_readable_semantic_messaging",
            worktree="/worktrees/one",
            branch="slice-one",
            conflict_domains=["semantic-message-contract"],
            contract_dependencies=["semantic-message-read"],
        )
        self.activate_slice(
            shared,
            "presentation_language_calibration_corpus",
            worktree="/worktrees/two",
            branch="slice-two",
            agent="agent-two",
            conflict_domains=["presentation-language-corpus"],
            contract_dependencies=["presentation-corpus-write"],
        )
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertFalse(any(issue.name.startswith("active_") or issue.name.startswith("unique_active_") for issue in issues))

    def test_delivery_acceptance_confusion_fails(self):
        shared, local = self.load_valid()
        shared["milestones"][0]["acceptance_status"] = "accepted"
        shared["milestones"][0].pop("accepted_at", None)
        shared["milestones"][0].pop("acceptance_reason", None)
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "accepted_requires_acceptance_evidence" for issue in issues))

    def test_ownership_contradiction_fails(self):
        shared, local = self.load_valid()
        local["repository"] = "BrianBusby/bmux"
        local["local_capabilities"]["durable_evidence"] = "implemented"
        issues = project_docs.invariant_issues(shared, [local], {local["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "bmux_no_durable_ownership" for issue in issues))

    def test_obsolete_shared_source_pointer_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            (repo / "project/shared-project-source.yaml").write_text(
                "schema_version: 1\nrepository: BrianBusby/not-provenance\npath: other.yaml\ndefault_ref: main\n",
                encoding="utf-8",
            )
            context = {
                "repo_root": repo,
                "repo_status": {"repository": "BrianBusby/bmux"},
                "pointer": project_docs.load_yaml(repo / "project/shared-project-source.yaml"),
                "shared": {"project": {"shared_state_owner": "BrianBusby/bmux"}},
                "shared_path": repo / "project/project-state.yaml",
            }
            issues = project_docs.validate_shared_source_issues(context)
            self.assertTrue(any(issue.name == "obsolete_shared_source_pointer" for issue in issues))

    def test_non_monorepo_shared_owner_fails_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            context = {
                "repo_root": repo,
                "repo_status": {"repository": "BrianBusby/bmux"},
                "pointer": None,
                "shared": {"project": {"shared_state_owner": "BrianBusby/provenance-engine"}},
                "shared_path": repo / "project/project-state.yaml",
            }
            issues = project_docs.validate_shared_source_issues(context)
            self.assertTrue(any(issue.name == "shared_state_owner_matches_monorepo" for issue in issues))

    def test_authored_doc_drift_detects_volatile_claim(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            (repo / "docs/handoffs").mkdir(parents=True)
            (repo / "docs/handoffs/latest.md").write_text(
                "See docs/generated/project-status.md. CI enforcement is not implemented yet. "
                "Still out of scope until a new slice is explicitly selected.\n",
                encoding="utf-8",
            )
            issues = project_docs.authored_doc_drift_issues(repo)
            self.assertTrue(any(issue.name == "volatile_status_claim" for issue in issues))

    def test_ci_mode_does_not_mutate_files_when_checking_generation(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            shutil.copytree(ROOT / "docs/generated", repo / "docs/generated")
            before = {path.relative_to(repo).as_posix(): path.read_bytes() for path in repo.rglob("*") if path.is_file()}
            context = project_docs.load_inputs(repo)
            project_docs.generated_drift_issues(context)
            after = {path.relative_to(repo).as_posix(): path.read_bytes() for path in repo.rglob("*") if path.is_file()}
            self.assertEqual(before, after)

    def test_issue_ordering_is_deterministic(self):
        issues = [
            project_docs.ValidationIssue("github", "missing_pr", "b", "two"),
            project_docs.ValidationIssue("schema", "repo", "a", "one"),
            project_docs.ValidationIssue("github", "missing_commit", "a", "three"),
        ]
        first = [issue.format() for issue in sorted(issues, key=lambda item: item.sort_key())]
        second = [issue.format() for issue in sorted(reversed(issues), key=lambda item: item.sort_key())]
        self.assertEqual(first, second)

    def runtime_merge_provider(self) -> FakeGitHubProvider:
        provider = self.fake_provider_for_current_manifests()
        merge_sha = "2a08fa2ce32495c2e637629bee8691b23bbe91c0"
        merged = project_docs.PullRequestEvidence(
            state="closed",
            draft=False,
            merged=True,
            owner_login="BrianBusby",
            owner_url="https://github.com/BrianBusby",
            number=97,
            merged_at="2026-09-05T17:38:46Z",
            merge_commit_sha=merge_sha,
            head_ref="process-integrity-runtime-composition",
            head_owner_login="BrianBusby",
        )
        provider.pull_requests[("BrianBusby/bmux", 97)] = merged
        provider.pull_requests_by_head[("BrianBusby/bmux", "BrianBusby", "process-integrity-runtime-composition")] = [merged]
        provider.commits.add(("BrianBusby/bmux", merge_sha))
        provider.reachable_commits.add(("BrianBusby/bmux", merge_sha))
        return provider

    def test_reconcile_detects_current_merged_branch_without_recorded_pr(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        plan = project_docs.reconciliation_plan(shared, [local], self.runtime_merge_provider())

        self.assertTrue(plan.changes)
        self.assertTrue(any(change.node_id == "deterministic_app_runtime_composition" for change in plan.changes))
        self.assertEqual([], plan.decisions)

    def test_reconcile_apply_reconciles_current_runtime_slice_and_is_idempotent(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        provider = self.runtime_merge_provider()

        plan = project_docs.reconciliation_plan(shared, [local], provider)
        reconciled_shared, reconciled_repo_statuses = project_docs.apply_reconciliation_plan(shared, [local], plan)

        node = self.roadmap_node(reconciled_shared, "deterministic_app_runtime_composition")
        self.assertEqual("implemented", node["status"])
        self.assertEqual("validated", node["capability_maturity"])
        self.assertEqual("complete", node["execution"]["assignment"])
        self.assertEqual("merged", node["delivery_status"])
        self.assertEqual("implemented", node["acceptance_status"])
        self.assertEqual("2026-09-05", node["completed_at"])
        self.assertNotIn("active_worktree", node["execution"])
        self.assertTrue(any(commit["sha"] == "2a08fa2ce32495c2e637629bee8691b23bbe91c0" for commit in node["evidence"]["commits"]))
        self.assertTrue(any(pr["number"] == 97 and pr["merge_commit_sha"] == "2a08fa2ce32495c2e637629bee8691b23bbe91c0" for pr in node["evidence"]["pull_requests"]))
        self.assertIsNone(reconciled_repo_statuses[0]["current_work"]["active_slice"]["id"])

        second = project_docs.reconciliation_plan(reconciled_shared, reconciled_repo_statuses, provider)
        self.assertEqual([], second.changes)

    def test_reconcile_advances_gated_ready_candidate_without_selecting_it(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        plan = project_docs.reconciliation_plan(shared, [local], self.runtime_merge_provider())
        reconciled_shared, _ = project_docs.apply_reconciliation_plan(shared, [local], plan)
        candidate = self.roadmap_node(reconciled_shared, "app_runtime_service_lifecycle_migration")

        self.assertEqual("ready", candidate["capability_maturity"])
        self.assertEqual("planned", candidate["execution"]["assignment"])
        ready_ids = {node["id"] for node in project_docs.dependency_ready_nodes(reconciled_shared["roadmap"]["nodes"])}
        self.assertIn("app_runtime_service_lifecycle_migration", ready_ids)

    def test_reconcile_preserves_observation_gate_for_merged_delivery(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        self.roadmap_node(shared, "deterministic_app_runtime_composition")["acceptance_status"] = "under_observation"

        plan = project_docs.reconciliation_plan(shared, [local], self.runtime_merge_provider())
        reconciled_shared, _ = project_docs.apply_reconciliation_plan(shared, [local], plan)

        self.assertEqual("under_observation", self.roadmap_node(reconciled_shared, "deterministic_app_runtime_composition")["acceptance_status"])

    def test_reconcile_open_pr_records_evidence_without_completing_delivery(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        provider = self.fake_provider_for_current_manifests()
        open_pr = project_docs.PullRequestEvidence(
            state="open",
            draft=False,
            merged=False,
            owner_login="BrianBusby",
            owner_url="https://github.com/BrianBusby",
            number=97,
            merge_commit_sha="d" * 40,
            head_ref="process-integrity-runtime-composition",
            head_owner_login="BrianBusby",
        )
        provider.pull_requests_by_head[("BrianBusby/bmux", "BrianBusby", "process-integrity-runtime-composition")] = [open_pr]

        plan = project_docs.reconciliation_plan(shared, [local], provider)
        reconciled_shared, reconciled_repo_statuses = project_docs.apply_reconciliation_plan(shared, [local], plan)
        node = self.roadmap_node(reconciled_shared, "deterministic_app_runtime_composition")

        self.assertEqual("active", node["status"])
        self.assertEqual("open", node["delivery_status"])
        self.assertEqual("current", node["execution"]["assignment"])
        self.assertEqual("deterministic_app_runtime_composition", reconciled_repo_statuses[0]["current_work"]["active_slice"]["id"])
        recorded_pr = next(pr for pr in node["evidence"]["pull_requests"] if pr["number"] == 97)
        self.assertNotIn("merge_commit_sha", recorded_pr)

    def test_reconcile_merged_pr_advances_proposed_delivery_to_merged(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        self.roadmap_node(shared, "deterministic_app_runtime_composition")["delivery_status"] = "proposed"

        plan = project_docs.reconciliation_plan(shared, [local], self.runtime_merge_provider())
        reconciled_shared, reconciled_repo_statuses = project_docs.apply_reconciliation_plan(shared, [local], plan)
        node = self.roadmap_node(reconciled_shared, "deterministic_app_runtime_composition")

        self.assertEqual("implemented", node["status"])
        self.assertEqual("merged", node["delivery_status"])
        project_docs.semantic_validate(reconciled_shared, reconciled_repo_statuses[0], LOCAL)

    def test_reconcile_open_pr_advances_proposed_delivery_to_open_or_draft(self):
        for draft, expected_status in ((False, "open"), (True, "draft")):
            with self.subTest(draft=draft):
                shared, local = self.load_valid()
                self.make_runtime_slice_stale(shared, local)
                self.roadmap_node(shared, "deterministic_app_runtime_composition")["delivery_status"] = "proposed"
                provider = self.fake_provider_for_current_manifests()
                open_pr = project_docs.PullRequestEvidence(
                    state="open",
                    draft=draft,
                    merged=False,
                    owner_login="BrianBusby",
                    owner_url="https://github.com/BrianBusby",
                    number=97,
                    merge_commit_sha="d" * 40,
                    head_ref="process-integrity-runtime-composition",
                    head_owner_login="BrianBusby",
                )
                provider.pull_requests_by_head[("BrianBusby/bmux", "BrianBusby", "process-integrity-runtime-composition")] = [open_pr]

                plan = project_docs.reconciliation_plan(shared, [local], provider)
                reconciled_shared, _ = project_docs.apply_reconciliation_plan(shared, [local], plan)
                node = self.roadmap_node(reconciled_shared, "deterministic_app_runtime_composition")

                self.assertEqual(expected_status, node["delivery_status"])
                self.assertEqual("active", node["status"])
                self.assertEqual("current", node["execution"]["assignment"])
                recorded_pr = next(pr for pr in node["evidence"]["pull_requests"] if pr["number"] == 97)
                self.assertNotIn("merge_commit_sha", recorded_pr)

    def test_reconcile_reports_closed_unmerged_pr_as_decision(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        provider = self.fake_provider_for_current_manifests()
        closed = project_docs.PullRequestEvidence(
            state="closed",
            draft=False,
            merged=False,
            owner_login="BrianBusby",
            owner_url="https://github.com/BrianBusby",
            number=97,
            merged_at=None,
            merge_commit_sha=None,
        )
        provider.pull_requests_by_head[("BrianBusby/bmux", "BrianBusby", "process-integrity-runtime-composition")] = [closed]

        plan = project_docs.reconciliation_plan(shared, [local], provider)

        target_changes = [change for change in plan.changes if change.node_id == "deterministic_app_runtime_composition"]
        self.assertEqual([], target_changes)
        self.assertTrue(any(decision.name == "closed_unmerged_pr" for decision in plan.decisions))

    def test_reconcile_respects_explicit_closed_unmerged_decision(self):
        shared, local = self.load_valid()
        self.clear_current_work(shared, local)
        node = self.roadmap_node(shared, "deterministic_app_runtime_composition")
        node["status"] = "deferred"
        node["capability_maturity"] = "gated"
        node["execution"]["assignment"] = "deferred"
        node["delivery_status"] = "closed"
        node["acceptance_status"] = "rejected"
        node["evidence"] = {
            "commits": [],
            "pull_requests": [
                {
                    "repository": "BrianBusby/bmux",
                    "number": 97,
                    "owner": {
                        "login": "BrianBusby",
                        "profile_url": "https://github.com/BrianBusby",
                    },
                }
            ],
        }
        provider = self.fake_provider_for_current_manifests()
        provider.pull_requests[("BrianBusby/bmux", 97)] = project_docs.PullRequestEvidence(
            state="closed",
            draft=False,
            merged=False,
            owner_login="BrianBusby",
            owner_url="https://github.com/BrianBusby",
            number=97,
            merged_at=None,
            merge_commit_sha=None,
        )

        plan = project_docs.reconciliation_plan(shared, [local], provider)

        target_decisions = [
            decision
            for decision in plan.decisions
            if decision.node_id == "deterministic_app_runtime_composition" and decision.name == "closed_unmerged_pr"
        ]
        self.assertEqual([], target_decisions)

    def test_reconcile_distinguishes_github_rate_limit(self):
        shared, local = self.load_valid()
        self.make_runtime_slice_stale(shared, local)
        provider = self.fake_provider_for_current_manifests()
        provider.failures[("pull_requests_for_head", "BrianBusby/bmux:BrianBusby:process-integrity-runtime-composition")] = (
            project_docs.GitHubProviderError("rate_limit", "rate limited")
        )

        plan = project_docs.reconciliation_plan(shared, [local], provider)

        self.assertTrue(any(issue.name == "rate_limit" for issue in plan.issues))

    def test_reconcile_check_distinguishes_malformed_state_exit_code(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            shared_path = repo / "project/project-state.yaml"
            shared = project_docs.load_yaml(shared_path)
            shared["roadmap"]["nodes"][0]["status"] = "not-a-status"
            shared_path.write_text(project_docs.yaml.safe_dump(shared, sort_keys=False), encoding="utf-8")

            self.assertEqual(
                3,
                project_docs.main(["reconcile", "--check", "--repo-root", str(repo)]),
            )

    def test_reconciliation_ci_issues_can_allow_explicit_decisions_after_apply(self):
        decision = project_docs.ReconciliationDecision(
            name="closed_unmerged_pr",
            path="project/project-state.yaml:roadmap.nodes[0](slice)",
            message="requires explicit planning decision",
            node_id="slice",
        )
        change = project_docs.ReconciliationChange(
            name="mark_delivery_merged",
            path="project/project-state.yaml:roadmap.nodes[1](other).delivery_status",
            message="mark delivery merged",
            node_id="other",
        )

        decision_only = project_docs.ReconciliationPlan([], [decision], [], {}, {})
        self.assertTrue(project_docs.reconciliation_ci_issues(decision_only))
        self.assertEqual([], project_docs.reconciliation_ci_issues(decision_only, allow_decisions=True))

        mixed = project_docs.ReconciliationPlan([change], [decision], [], {}, {})
        allowed_issues = project_docs.reconciliation_ci_issues(mixed, allow_decisions=True)
        self.assertEqual(["mark_delivery_merged"], [issue.name for issue in allowed_issues])

    def test_allow_reconciliation_decisions_filters_only_related_pr_state_mismatches(self):
        shared, local = self.load_valid()
        self.clear_current_work(shared, local)
        node = self.roadmap_node(shared, "deterministic_app_runtime_composition")
        node["status"] = "active"
        node["capability_maturity"] = "active"
        node["execution"]["assignment"] = "current"
        node["delivery_status"] = "open"
        node["acceptance_status"] = "proposed"
        node["evidence"] = {
            "commits": [],
            "pull_requests": [
                {
                    "repository": "BrianBusby/bmux",
                    "number": 97,
                    "owner": {
                        "login": "BrianBusby",
                        "profile_url": "https://github.com/BrianBusby",
                    },
                }
            ],
        }
        provider = self.fake_provider_for_current_manifests()
        provider.pull_requests[("BrianBusby/bmux", 97)] = project_docs.PullRequestEvidence(
            state="closed",
            draft=False,
            merged=False,
            owner_login="BrianBusby",
            owner_url="https://github.com/BrianBusby",
            number=97,
            merged_at=None,
            merge_commit_sha=None,
        )

        plan = project_docs.reconciliation_plan(shared, [local], provider, discover_active_branches=False)
        github_issues = project_docs.github_evidence_issues(shared, [local], provider)
        unrelated_missing = project_docs.ValidationIssue(
            "github",
            "missing_pr",
            "project/project-state.yaml:roadmap.nodes[0](other).evidence.pull_requests[BrianBusby/bmux#1]",
            "missing",
        )

        filtered = project_docs.filter_allowed_reconciliation_decision_issues(github_issues + [unrelated_missing], plan)

        self.assertTrue(any(decision.name == "closed_unmerged_pr" for decision in plan.decisions))
        self.assertTrue(any(issue.name == "pr_open_state_mismatch" for issue in github_issues))
        self.assertFalse(any(issue.name == "pr_open_state_mismatch" for issue in filtered))
        self.assertIn(unrelated_missing, filtered)

    def test_project_truth_workflow_runs_canonical_ci_gate(self):
        text = PROJECT_TRUTH_WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("contents: read", text)
        self.assertIn("issues: read", text)
        self.assertIn("pull-requests: read", text)
        self.assertNotIn("contents: write", text)
        self.assertNotIn("PEER_REPOSITORY", text)
        self.assertNotIn("peer-repo-root", text)
        self.assertNotIn("Use dependency bmux branch when declared", text)
        self.assertIn("./scripts/project-docs validate", text)
        self.assertIn("./scripts/project-docs check", text)
        self.assertIn("./scripts/project-docs ci", text)

    def test_project_truth_reconcile_workflow_dispatches_required_checks_after_bot_pr_write(self):
        branch = "project-truth/post-merge-reconciliation"
        expected_dispatches = [
            f"gh workflow run ci.yml --ref {branch}",
            f"gh workflow run project-truth.yml --ref {branch}",
            f"gh workflow run perf-activation.yml --ref {branch} -f ref={branch}",
        ]
        cases = (
            (
                False,
                f"gh pr create --base main --head {branch} --title Reconcile Project Truth delivery state --body-file /tmp/project-truth-reconcile-pr.md",
                f"git push --force-with-lease=refs/heads/{branch}: origin HEAD:{branch}",
            ),
            (
                True,
                "gh pr edit 123 --title Reconcile Project Truth delivery state --body-file /tmp/project-truth-reconcile-pr.md",
                f"git push --force-with-lease=refs/heads/{branch}:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb origin HEAD:{branch}",
            ),
        )

        for existing_pr, expected_pr_command, expected_push_command in cases:
            with self.subTest(existing_pr=existing_pr):
                commands = self.run_reconcile_writer_workflow_step(existing_pr=existing_pr)
                self.assertIn(f"git ls-remote --heads origin {branch}", commands)
                self.assertIn(expected_push_command, commands)
                self.assertIn(expected_pr_command, commands)
                self.assertIn("./scripts/project-docs ci --allow-reconciliation-decisions", commands)
                dispatches = [command for command in commands if command.startswith("gh workflow run ")]
                self.assertEqual(expected_dispatches, dispatches)
                self.assertLess(commands.index(expected_pr_command), commands.index(expected_dispatches[0]))


if __name__ == "__main__":
    unittest.main()
