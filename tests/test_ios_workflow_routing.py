#!/usr/bin/env python3
"""Behavioral guards for the iOS workflow routing shell step."""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "test-ios.yml"


def detect_ios_script() -> str:
    lines = WORKFLOW.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        if line == "      - name: Detect iOS changes":
            for run_index in range(index + 1, len(lines)):
                if lines[run_index] == "        run: |":
                    body: list[str] = []
                    for body_line in lines[run_index + 1 :]:
                        if body_line.startswith("          "):
                            body.append(body_line[10:])
                            continue
                        if not body_line.strip():
                            body.append("")
                            continue
                        break
                    return "\n".join(body)
    raise AssertionError("Detect iOS changes run block not found")


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()


def commit_paths(repo: Path, paths: list[str], message: str) -> str:
    for path in paths:
        full_path = repo / path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(f"{message}\n", encoding="utf-8")
    git(repo, "add", ".")
    git(repo, "commit", "-m", message)
    return git(repo, "rev-parse", "HEAD")


def route_for(paths: list[str]) -> dict[str, str]:
    script = detect_ios_script().replace('${{ github.event_name }}', "pull_request")
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        git(repo, "init")
        git(repo, "config", "user.email", "ci-routing@example.com")
        git(repo, "config", "user.name", "CI Routing")
        base_sha = commit_paths(repo, ["README.md"], "base")
        head_sha = commit_paths(repo, paths, "change")
        output_path = repo / "github-output.txt"
        env = {
            **os.environ,
            "BASE_SHA": base_sha,
            "HEAD_SHA": head_sha,
            "GITHUB_OUTPUT": str(output_path),
        }
        subprocess.run(["bash", "-c", script], cwd=repo, env=env, check=True)
        return dict(
            line.split("=", 1)
            for line in output_path.read_text(encoding="utf-8").splitlines()
            if "=" in line
        )


def test_sources_mobile_runs_package_without_simulator() -> None:
    outputs = route_for(["Sources/Mobile/MobileWorkspaceListObserver.swift"])
    assert outputs["should_run_mobile_package"] == "true"
    assert outputs["should_run_simulator"] == "false"
    assert outputs["should_lint"] == "true"


def test_ios_app_change_runs_package_and_simulator() -> None:
    outputs = route_for(["ios/bmux/ContentView.swift"])
    assert outputs["should_run_mobile_package"] == "true"
    assert outputs["should_run_simulator"] == "true"
    assert outputs["should_lint"] == "true"


def test_macos_package_change_only_runs_conventions_lint() -> None:
    outputs = route_for(["Packages/macOS/BmuxTerminal/Sources/Foo.swift"])
    assert outputs["should_run_mobile_package"] == "false"
    assert outputs["should_run_simulator"] == "false"
    assert outputs["should_lint"] == "true"


def test_docs_only_skips_ios_work() -> None:
    outputs = route_for(["docs/ci.md"])
    assert outputs["should_run_mobile_package"] == "false"
    assert outputs["should_run_simulator"] == "false"
    assert outputs["should_lint"] == "false"
