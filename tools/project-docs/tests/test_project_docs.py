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
    def load_valid(self):
        shared = project_docs.load_yaml(SHARED)
        local = project_docs.load_yaml(LOCAL)
        return shared, local

    def test_valid_shared_manifest(self):
        shared, local = self.load_valid()
        project_docs.semantic_validate(shared, local, LOCAL)

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

    def test_accepted_milestone_without_evidence_fails(self):
        shared, local = self.load_valid()
        shared["milestones"][0]["evidence"] = {"commits": [], "pull_requests": []}
        with self.assertRaisesRegex(project_docs.ProjectDocsError, "accepted milestone must have"):
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
        self.assertEqual(first, second)

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

    def test_bmux_missing_shared_manifest_fails_clearly(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            (repo / "project").mkdir(parents=True)
            (repo / "project/repo-status.yaml").write_text(
                "schema_version: 1\nrepository: BrianBusby/bmux\ncurrent_work:\n  state: observation\nrelease:\n  latest_tag: null\n  release_status: untagged\nlocal_caveats: []\n",
                encoding="utf-8",
            )
            (repo / "project/shared-project-source.yaml").write_text(
                "schema_version: 1\nrepository: BrianBusby/provenance-engine\npath: project/project-state.yaml\ndefault_ref: main\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(project_docs.ProjectDocsError, "cannot resolve canonical shared manifest"):
                project_docs.load_inputs(repo)

    def fake_provider_for_current_manifests(self) -> FakeGitHubProvider:
        shared, local = self.load_valid()
        provider = FakeGitHubProvider()
        provider.repositories.update(project_docs.collect_evidence_repositories(shared, [local]))
        for milestone in shared["milestones"]:
            for commit in milestone["evidence"]["commits"]:
                provider.commits.add((commit["repository"], commit["sha"]))
            for pr in milestone["evidence"]["pull_requests"]:
                owner = pr.get("owner", {})
                provider.pull_requests[(pr["repository"], pr["number"])] = project_docs.PullRequestEvidence(
                    state="closed",
                    draft=False,
                    merged=milestone["delivery_status"] == "merged",
                    owner_login=owner.get("login"),
                    owner_url=owner.get("profile_url"),
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
        provider.commits.add(("BrianBusby/bmux", first_commit["sha"]))
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "missing_commit" for issue in issues))

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
        tag = local["release"]["latest_tag"]
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
        tag = local["release"]["latest_tag"]
        local["release"]["release_status"] = "released"
        issues = project_docs.github_evidence_issues(shared, [local], provider)
        self.assertTrue(any(issue.name == "issue_state_mismatch" for issue in issues))
        self.assertTrue(any(issue.name == "missing_release" for issue in issues))

    def test_conflicting_active_slices_fail(self):
        shared, local = self.load_valid()
        peer = copy.deepcopy(local)
        local["repository"] = "BrianBusby/provenance-engine"
        peer["repository"] = "BrianBusby/bmux"
        for status in (local, peer):
            status["current_work"] = {
                "state": "active",
                "active_slice": {"id": "project_truth_ci", "title": "Project Truth CI", "state": "open", "owner": status["repository"]},
            }
        issues = project_docs.invariant_issues(shared, [local, peer], {local["repository"]: LOCAL, peer["repository"]: LOCAL})
        self.assertTrue(any(issue.name == "no_conflicting_active_slices" for issue in issues))

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

    def test_malformed_bmux_shared_source_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            (repo / "project/project-state.yaml").unlink()
            (repo / "project/shared-project-source.yaml").write_text(
                "schema_version: 1\nrepository: BrianBusby/not-provenance\npath: other.yaml\ndefault_ref: main\n",
                encoding="utf-8",
            )
            context = {
                "repo_root": repo,
                "repo_status": {"repository": "BrianBusby/bmux"},
                "pointer": project_docs.load_yaml(repo / "project/shared-project-source.yaml"),
                "shared": {"project": {"shared_state_owner": "BrianBusby/provenance-engine"}},
                "shared_path": repo / "missing.yaml",
            }
            issues = project_docs.validate_shared_source_issues(context)
            self.assertTrue(any(issue.name == "shared_source_repository" for issue in issues))
            self.assertTrue(any(issue.name == "shared_source_path" for issue in issues))

    def test_bmux_copied_shared_manifest_fails_shared_source_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            shutil.copytree(ROOT / "project", repo / "project")
            (repo / "project/shared-project-source.yaml").write_text(
                "schema_version: 1\nrepository: BrianBusby/provenance-engine\npath: project/project-state.yaml\ndefault_ref: main\n",
                encoding="utf-8",
            )
            context = {
                "repo_root": repo,
                "repo_status": {"repository": "BrianBusby/bmux"},
                "pointer": project_docs.load_yaml(repo / "project/shared-project-source.yaml"),
                "shared": {"project": {"shared_state_owner": "BrianBusby/provenance-engine"}},
                "shared_path": repo / "project/project-state.yaml",
            }
            issues = project_docs.validate_shared_source_issues(context)
            self.assertTrue(any(issue.name == "no_copied_shared_manifest" for issue in issues))

    def test_authored_doc_drift_detects_volatile_claim(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            (repo / "docs/handoffs").mkdir(parents=True)
            (repo / "docs/handoffs/latest.md").write_text(
                "See docs/generated/project-status.md. CI enforcement is not implemented yet.\n",
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
        self.assertIn("repository: BrianBusby/bmux", text)
        self.assertIn("contents: read", text)
        self.assertIn("issues: read", text)
        self.assertIn("pull-requests: read", text)
        self.assertNotIn("contents: write", text)
        self.assertIn("./scripts/project-docs validate", text)
        self.assertIn("./scripts/project-docs check", text)
        self.assertIn("./scripts/project-docs ci --peer-repo-root .project-truth/bmux", text)


if __name__ == "__main__":
    unittest.main()
