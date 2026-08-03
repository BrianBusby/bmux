#!/usr/bin/env python3
"""Guards for the Project Truth CI workflow."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "project-truth.yml"


def workflow_text() -> str:
    return WORKFLOW.read_text(encoding="utf-8")


def test_project_truth_workflow_uses_canonical_provenance_tooling() -> None:
    text = workflow_text()
    assert "repository: BrianBusby/provenance-engine" in text
    assert "PROJECT_TRUTH_TOOL_ROOT: .project-truth/provenance-engine/tools/project-docs" in text
    assert "PROJECT_TRUTH_SHARED_STATE: .project-truth/provenance-engine/project/project-state.yaml" in text
    assert "./scripts/project-docs ci --peer-repo-root .project-truth/provenance-engine" in text


def test_project_truth_workflow_keeps_read_only_permissions() -> None:
    text = workflow_text()
    assert "contents: read" in text
    assert "issues: read" in text
    assert "pull-requests: read" in text
    assert "contents: write" not in text
    assert "issues: write" not in text
    assert "pull-requests: write" not in text


def test_project_truth_workflow_checks_matching_branch_when_present() -> None:
    text = workflow_text()
    assert "Use matching Provenance Engine branch when available" in text
    assert "git -C .project-truth/provenance-engine ls-remote" in text
    assert "git -C .project-truth/provenance-engine checkout --detach FETCH_HEAD" in text
