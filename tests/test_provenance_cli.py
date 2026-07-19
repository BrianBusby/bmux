#!/usr/bin/env python3
"""Regression checks for the provenance CLI."""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import tempfile
from pathlib import Path

from claude_teams_test_utils import resolve_bmux_cli


def create_provenance_database(path: Path) -> None:
    if path.exists():
        path.unlink()
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE sessions (
                id TEXT PRIMARY KEY,
                agent_kind TEXT NOT NULL,
                workspace_id TEXT,
                surface_id TEXT,
                worktree_id TEXT,
                cwd TEXT,
                status TEXT NOT NULL,
                started_at REAL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE session_relationships (
                session_id TEXT PRIMARY KEY,
                parent_session_id TEXT NOT NULL,
                root_session_id TEXT NOT NULL,
                inbound_delegation_id TEXT,
                depth INTEGER NOT NULL,
                source TEXT NOT NULL,
                confidence TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE session_external_identities (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                system TEXT NOT NULL,
                kind TEXT NOT NULL,
                external_id TEXT NOT NULL,
                source TEXT NOT NULL,
                confidence TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """
        )
        conn.executemany(
            """
            INSERT INTO sessions (
                id, agent_kind, workspace_id, surface_id, worktree_id,
                cwd, status, started_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "codex-parent",
                    "codex",
                    "workspace-1",
                    "surface-1",
                    "worktree-1",
                    "/repo",
                    "active",
                    100.0,
                    100.0,
                ),
                (
                    "codex-child",
                    "codex",
                    "workspace-1",
                    "surface-2",
                    "worktree-1",
                    "/repo",
                    "completed",
                    120.0,
                    140.0,
                ),
                (
                    "codex-grandchild",
                    "codex",
                    "workspace-1",
                    "surface-3",
                    "worktree-1",
                    "/repo",
                    "active",
                    130.0,
                    130.0,
                ),
                (
                    "unrelated",
                    "claude",
                    "workspace-9",
                    "surface-9",
                    "worktree-9",
                    "/other",
                    "active",
                    200.0,
                    200.0,
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO session_relationships (
                session_id, parent_session_id, root_session_id,
                inbound_delegation_id, depth, source, confidence,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "codex-child",
                    "codex-parent",
                    "codex-parent",
                    None,
                    1,
                    "observed",
                    "high",
                    120.0,
                    140.0,
                ),
                (
                    "codex-grandchild",
                    "codex-child",
                    "codex-parent",
                    None,
                    2,
                    "observed",
                    "high",
                    130.0,
                    130.0,
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO session_external_identities (
                id, session_id, system, kind, external_id, source,
                confidence, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "identity-child",
                    "codex-child",
                    "codex",
                    "subsession",
                    "subagent-1",
                    "observed",
                    "high",
                    120.0,
                    140.0,
                ),
                (
                    "identity-grandchild",
                    "codex-grandchild",
                    "codex",
                    "subsession",
                    "subagent-2",
                    "observed",
                    "high",
                    130.0,
                    130.0,
                ),
                (
                    "identity-unrelated",
                    "unrelated",
                    "claude",
                    "thread",
                    "claude-thread",
                    "observed",
                    "high",
                    200.0,
                    200.0,
                ),
            ],
        )


def run_cli(cli_path: str, args: list[str]) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [cli_path, *args],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"bmux {' '.join(args)} failed with {result.returncode}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    return result


def check_provenance_session_tree_json(cli_path: str, root: Path) -> None:
    database = root / "work-provenance.sqlite"
    create_provenance_database(database)

    result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "sessions",
            "tree",
            "codex-parent",
            "--database",
            str(database),
        ],
    )
    payload = json.loads(result.stdout)
    if payload["root_session_id"] != "codex-parent" or not payload["found"]:
        raise AssertionError(f"expected a found parent session tree: {payload!r}")
    if payload["summary"] != {
        "external_identity_count": 2,
        "max_depth": 2,
        "relationship_count": 2,
        "session_count": 3,
    }:
        raise AssertionError(f"unexpected session tree summary: {payload!r}")
    session_ids = [row["id"] for row in payload["sessions"]]
    if session_ids != ["codex-parent", "codex-child", "codex-grandchild"]:
        raise AssertionError(f"expected depth-first session order: {payload!r}")
    if any(row["id"] == "unrelated" for row in payload["sessions"]):
        raise AssertionError(f"unrelated session leaked into tree: {payload!r}")
    relationships = payload["relationships"]
    if [row["parent_session_id"] for row in relationships] != ["codex-parent", "codex-child"]:
        raise AssertionError(f"expected bounded parent-child relationships: {payload!r}")
    identities = payload["external_identities"]
    if [row["external_id"] for row in identities] != ["subagent-1", "subagent-2"]:
        raise AssertionError(f"expected only tree external identities: {payload!r}")

    missing_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "sessions",
            "tree",
            "missing-session",
            "--database",
            str(database),
        ],
    )
    missing = json.loads(missing_result.stdout)
    if missing["found"] or missing["summary"]["session_count"] != 0:
        raise AssertionError(f"missing session should return bounded empty JSON: {missing!r}")


def check_provenance_session_tree_text(cli_path: str, root: Path) -> None:
    database = root / "work-provenance.sqlite"
    create_provenance_database(database)

    result = run_cli(
        cli_path,
        [
            "provenance",
            "sessions",
            "tree",
            "codex-parent",
            "--database",
            str(database),
        ],
    )
    output = result.stdout
    for expected in [
        "Session tree for codex-parent",
        "Sessions: 3",
        "codex-parent",
        "codex-child",
        "codex-grandchild",
    ]:
        if expected not in output:
            raise AssertionError(f"expected text output to include {expected!r}:\n{output}")


def main() -> int:
    try:
        bundled_cli = os.environ.get("BMUX_BUNDLED_CLI_PATH")
        if bundled_cli and os.path.exists(bundled_cli) and os.access(bundled_cli, os.X_OK):
            cli_path = bundled_cli
        else:
            cli_path = resolve_bmux_cli()
    except Exception as exc:
        print(f"FAIL: {exc}")
        return 1

    with tempfile.TemporaryDirectory(prefix="bmux-provenance-cli-", dir="/tmp") as td:
        root = Path(td)
        try:
            check_provenance_session_tree_json(cli_path, root)
            check_provenance_session_tree_text(cli_path, root)
        except Exception as exc:
            print(f"FAIL: {exc}")
            return 1

    print("PASS: Provenance CLI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
