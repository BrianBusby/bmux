from __future__ import annotations

import copy
import os
import shutil
import tempfile
import unittest
from pathlib import Path

import project_docs


ROOT = Path(__file__).resolve().parents[3]
SHARED = ROOT / "project" / "project-state.yaml"
LOCAL = ROOT / "project" / "repo-status.yaml"
PROJECT_TRUTH_WORKFLOW = ROOT / ".github" / "workflows" / "project-truth.yml"


class FakeGitHubProvider:
    def __init__(self):
        self.repositories: set[str] = set()
        self.commits: set[tuple[str, str]] = set()
        self.pull_requests: dict[tuple[str, int], project_docs.PullRequestEvidence] = {}
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

    def pull_request(self, repository: str, number: int):
        self._maybe_fail("pull_request", f"{repository}#{number}")
        return self.pull_requests.get((repository, number))

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
        nodes = shared["roadmap"]["nodes"]
        ready_ids = {node["id"] for node in project_docs.dependency_ready_nodes(nodes)}
        self.assertIn("milestone_inference", ready_ids)
        readiness = project_docs.dependency_readiness(
            self.roadmap_node(shared, "milestone_inference"),
            {node["id"]: node for node in nodes},
        )
        self.assertTrue(readiness.ready)

    def test_unsatisfied_dependency_remains_gated(self):
        shared, _local = self.load_valid()
        node = self.roadmap_node(shared, "milestone_to_code_relationships")
        readiness = project_docs.dependency_readiness(
            node,
            {item["id"]: item for item in shared["roadmap"]["nodes"]},
        )
        self.assertFalse(readiness.ready)
        self.assertTrue(any("milestone_inference" in blocker for blocker in readiness.blockers))
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
        node = self.roadmap_node(shared, "milestone_to_code_relationships")
        node["execution"]["assignment"] = "selected_next"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "capability_maturity gated cannot be selected_next"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_gated_slice_cannot_be_active_current(self):
        shared, local = self.load_valid()
        node = self.roadmap_node(shared, "milestone_to_code_relationships")
        node["status"] = "active"
        node["execution"]["assignment"] = "current"
        node["execution"]["active_worktree"] = "/worktrees/gated"
        node["execution"]["active_branch"] = "gated"
        node["execution"]["active_agent"] = "agent"
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "capability_maturity gated cannot be current or active"):
            project_docs.semantic_validate(shared, local, LOCAL)

    def test_ready_slice_can_be_selected_next(self):
        shared, local = self.load_valid()
        selected = self.roadmap_node(shared, "milestone_inference")
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
        self.assertIn("Richer Session Understanding (richer_session_understanding)", rendered)
        self.assertIn("Selected next:", rendered)
        self.assertIn("Milestone inference (`milestone_inference`)", rendered)
        self.assertIn("Evidence-aware knowledge retrieval", rendered)
        self.assertIn("requires validated for gate `compiled_knowledge_validated`", rendered)

    def test_primary_capability_frontier_renders_in_generated_docs(self):
        context = project_docs.load_inputs(ROOT)
        rendered = project_docs.render_project_status(context)
        self.assertIn("Primary Capability Frontier: Richer Session Understanding (`richer_session_understanding`)", rendered)
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
                    "Active implementation slice: Project Truth dependency and capability frontier governance",
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

        def pr_evidence_for_delivery(delivery_status: str, owner: dict):
            if delivery_status == "draft":
                return project_docs.PullRequestEvidence(
                    state="open",
                    draft=True,
                    merged=False,
                    owner_login=owner.get("login"),
                    owner_url=owner.get("profile_url"),
                )
            if delivery_status == "open":
                return project_docs.PullRequestEvidence(
                    state="open",
                    draft=False,
                    merged=False,
                    owner_login=owner.get("login"),
                    owner_url=owner.get("profile_url"),
                )
            if delivery_status == "closed":
                return project_docs.PullRequestEvidence(
                    state="closed",
                    draft=False,
                    merged=False,
                    owner_login=owner.get("login"),
                    owner_url=owner.get("profile_url"),
                )
            return project_docs.PullRequestEvidence(
                state="closed",
                draft=False,
                merged=delivery_status == "merged",
                owner_login=owner.get("login"),
                owner_url=owner.get("profile_url"),
            )

        for milestone in shared["milestones"]:
            for commit in milestone["evidence"]["commits"]:
                provider.commits.add((commit["repository"], commit["sha"]))
            for pr in milestone["evidence"]["pull_requests"]:
                owner = pr.get("owner", {})
                provider.pull_requests[(pr["repository"], pr["number"])] = pr_evidence_for_delivery(
                    milestone["delivery_status"], owner
                )
        for node in shared["roadmap"]["nodes"]:
            evidence = node.get("evidence", {})
            for commit in evidence.get("commits", []):
                provider.commits.add((commit["repository"], commit["sha"]))
            for pr in evidence.get("pull_requests", []):
                owner = pr.get("owner", {})
                provider.pull_requests[(pr["repository"], pr["number"])] = pr_evidence_for_delivery(
                    node.get("delivery_status"), owner
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


if __name__ == "__main__":
    unittest.main()
