from __future__ import annotations

import copy
import shutil
import tempfile
import unittest
from pathlib import Path

import project_docs


ROOT = Path(__file__).resolve().parents[3]
SHARED = ROOT / "project" / "project-state.yaml"
LOCAL = ROOT / "project" / "repo-status.yaml"


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


if __name__ == "__main__":
    unittest.main()
