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


def create_observability_database(path: Path) -> None:
    if path.exists():
        path.unlink()
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE pipeline_runs (
                pipeline_run_id TEXT PRIMARY KEY NOT NULL,
                pipeline_kind TEXT NOT NULL,
                trigger_source TEXT NOT NULL,
                parent_session_id TEXT,
                child_session_id TEXT,
                lifecycle_event_id TEXT,
                relationship_session_id TEXT,
                external_identity_id TEXT,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_ms REAL NOT NULL,
                input_count INTEGER NOT NULL,
                output_count INTEGER NOT NULL,
                error_count INTEGER NOT NULL,
                error_summary TEXT,
                implementation_version TEXT NOT NULL
            );
            CREATE TABLE pipeline_stage_executions (
                stage_execution_id TEXT PRIMARY KEY NOT NULL,
                pipeline_run_id TEXT NOT NULL,
                stage_name TEXT NOT NULL,
                stage_version TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_ms REAL NOT NULL,
                input_count INTEGER NOT NULL,
                output_count INTEGER NOT NULL,
                error_count INTEGER NOT NULL,
                error_summary TEXT
            );
            CREATE TABLE identity_resolution_attempts (
                identity_resolution_id TEXT PRIMARY KEY NOT NULL,
                pipeline_run_id TEXT NOT NULL,
                resolver_name TEXT NOT NULL,
                resolver_version TEXT NOT NULL,
                trigger_source TEXT NOT NULL,
                input_phase TEXT NOT NULL,
                input_agent_kind TEXT NOT NULL,
                input_parent_session_id TEXT NOT NULL,
                input_subsession_id_state TEXT NOT NULL,
                input_workspace_present INTEGER NOT NULL,
                input_surface_present INTEGER NOT NULL,
                input_working_directory_present INTEGER NOT NULL,
                input_display_name_present INTEGER NOT NULL,
                input_identity_kind TEXT NOT NULL,
                input_identity_value_hash TEXT NOT NULL,
                selected_identity_kind TEXT NOT NULL,
                selected_identity_value_category TEXT NOT NULL,
                candidate_count INTEGER NOT NULL,
                selected_child_session_id TEXT,
                selected_lifecycle_event_id TEXT,
                selected_relationship_session_id TEXT,
                selected_external_identity_id TEXT,
                confidence TEXT NOT NULL,
                outcome TEXT NOT NULL,
                fallback_state TEXT NOT NULL,
                unresolved_reason TEXT,
                conflict_reason TEXT,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_ms REAL NOT NULL
            );
            """
        )
        conn.executemany(
            """
            INSERT INTO pipeline_runs (
                pipeline_run_id, pipeline_kind, trigger_source,
                parent_session_id, child_session_id, lifecycle_event_id,
                relationship_session_id, external_identity_id, status,
                started_at, ended_at, duration_ms, input_count, output_count,
                error_count, error_summary, implementation_version
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "run-success",
                    "lifecycle_ingestion",
                    "AgentSubsessionLifecycleChange",
                    "codex-parent",
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "succeeded",
                    120.0,
                    121.0,
                    1000.0,
                    1,
                    1,
                    0,
                    None,
                    "o1",
                ),
                (
                    "run-failed",
                    "lifecycle_ingestion",
                    "AgentSubsessionLifecycleChange",
                    "codex-parent",
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "failed",
                    130.0,
                    131.0,
                    1000.0,
                    1,
                    0,
                    1,
                    "UNIQUE constraint failed: events.id",
                    "o1",
                ),
                (
                    "run-second-parent",
                    "lifecycle_ingestion",
                    "AgentSubsessionLifecycleChange",
                    "other-parent",
                    "other-child",
                    "event-other-start",
                    "other-child",
                    "identity-other",
                    "succeeded",
                    135.0,
                    136.0,
                    1000.0,
                    1,
                    1,
                    0,
                    None,
                    "o2",
                ),
                (
                    "run-other",
                    "retrieval",
                    "not-o1",
                    None,
                    None,
                    None,
                    None,
                    None,
                    "succeeded",
                    140.0,
                    141.0,
                    1000.0,
                    1,
                    1,
                    0,
                    None,
                    "future",
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO pipeline_stage_executions (
                stage_execution_id, pipeline_run_id, stage_name,
                stage_version, status, started_at, ended_at, duration_ms,
                input_count, output_count, error_count, error_summary
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "run-success:lifecycle_change_received",
                    "run-success",
                    "lifecycle_change_received",
                    "o1",
                    "succeeded",
                    120.0,
                    120.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-success:work_provenance_event_append",
                    "run-success",
                    "work_provenance_event_append",
                    "o1",
                    "succeeded",
                    121.0,
                    121.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-success:work_provenance_projection_update",
                    "run-success",
                    "work_provenance_projection_update",
                    "o1",
                    "succeeded",
                    122.0,
                    122.1,
                    100.0,
                    1,
                    3,
                    0,
                    None,
                ),
                (
                    "run-second-parent:lifecycle_change_received",
                    "run-second-parent",
                    "lifecycle_change_received",
                    "o1",
                    "succeeded",
                    135.0,
                    135.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-second-parent:work_provenance_event_append",
                    "run-second-parent",
                    "work_provenance_event_append",
                    "o1",
                    "succeeded",
                    136.0,
                    136.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-second-parent:work_provenance_projection_update",
                    "run-second-parent",
                    "work_provenance_projection_update",
                    "o1",
                    "succeeded",
                    137.0,
                    137.1,
                    100.0,
                    1,
                    3,
                    0,
                    None,
                ),
                (
                    "run-failed:lifecycle_change_received",
                    "run-failed",
                    "lifecycle_change_received",
                    "o1",
                    "succeeded",
                    130.0,
                    130.1,
                    100.0,
                    1,
                    1,
                    0,
                    None,
                ),
                (
                    "run-failed:work_provenance_event_append",
                    "run-failed",
                    "work_provenance_event_append",
                    "o1",
                    "failed",
                    131.0,
                    131.1,
                    100.0,
                    1,
                    0,
                    1,
                    "failed",
                ),
                (
                    "run-failed:work_provenance_projection_update",
                    "run-failed",
                    "work_provenance_projection_update",
                    "o1",
                    "failed",
                    132.0,
                    132.1,
                    100.0,
                    0,
                    0,
                    1,
                    "skipped",
                ),
            ],
        )
        conn.executemany(
            """
            INSERT INTO identity_resolution_attempts (
                identity_resolution_id, pipeline_run_id, resolver_name,
                resolver_version, trigger_source, input_phase, input_agent_kind,
                input_parent_session_id, input_subsession_id_state,
                input_workspace_present, input_surface_present,
                input_working_directory_present, input_display_name_present,
                input_identity_kind, input_identity_value_hash,
                selected_identity_kind, selected_identity_value_category,
                candidate_count, selected_child_session_id,
                selected_lifecycle_event_id, selected_relationship_session_id,
                selected_external_identity_id, confidence, outcome,
                fallback_state, unresolved_reason, conflict_reason,
                started_at, ended_at, duration_ms
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    "run-success:subsession_identity",
                    "run-success",
                    "subsession_lifecycle_identity",
                    "o2",
                    "AgentSubsessionLifecycleChange",
                    "started",
                    "codex",
                    "codex-parent",
                    "present",
                    1,
                    1,
                    1,
                    1,
                    "subsession",
                    "identity-input-native",
                    "subsession",
                    "native_subsession_id",
                    1,
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "high",
                    "resolved",
                    "native",
                    None,
                    None,
                    120.0,
                    120.1,
                    100.0,
                ),
                (
                    "run-second-parent:subsession_identity",
                    "run-second-parent",
                    "subsession_lifecycle_identity",
                    "o2",
                    "AgentSubsessionLifecycleChange",
                    "started",
                    "codex",
                    "other-parent",
                    "missing",
                    0,
                    0,
                    1,
                    0,
                    "unresolved_subsession",
                    "identity-input-fallback",
                    "unresolved_subsession",
                    "stable_parent_fallback",
                    0,
                    "other-child",
                    "event-other-start",
                    "other-child",
                    "identity-other",
                    "low",
                    "unresolved",
                    "fallback_unresolved",
                    "missing_native_subsession_identifier",
                    None,
                    135.0,
                    135.1,
                    100.0,
                ),
                (
                    "run-failed:subsession_identity",
                    "run-failed",
                    "subsession_lifecycle_identity",
                    "o2",
                    "AgentSubsessionLifecycleChange",
                    "started",
                    "codex",
                    "codex-parent",
                    "present",
                    1,
                    1,
                    1,
                    1,
                    "subsession",
                    "identity-input-native",
                    "subsession",
                    "native_subsession_id",
                    1,
                    "codex-child",
                    "event-child-start",
                    "codex-child",
                    "identity-child",
                    "high",
                    "resolved",
                    "native",
                    None,
                    "UNIQUE constraint failed: events.id",
                    130.0,
                    130.1,
                    100.0,
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


def check_provenance_lifecycle_trace_json(cli_path: str, root: Path) -> None:
    database = root / "ProvenanceObservability.sqlite"
    create_observability_database(database)

    result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--limit",
            "10",
        ],
    )
    payload = json.loads(result.stdout)
    if payload["summary"] != {
        "conflicted_identity_resolution_count": 1,
        "failed_run_count": 1,
        "identity_resolution_count": 3,
        "resolved_identity_resolution_count": 2,
        "run_count": 3,
        "stage_count": 9,
        "unresolved_identity_resolution_count": 1,
    }:
        raise AssertionError(f"unexpected trace summary: {payload!r}")
    run_ids = [row["pipeline_run_id"] for row in payload["runs"]]
    if run_ids != ["run-second-parent", "run-failed", "run-success"]:
        raise AssertionError(f"expected bounded lifecycle trace order: {payload!r}")
    if any(row["pipeline_run_id"] == "run-other" for row in payload["runs"]):
        raise AssertionError(f"non-lifecycle trace leaked into output: {payload!r}")
    stage_names = [row["stage_name"] for row in payload["stages"][:3]]
    if stage_names != [
        "lifecycle_change_received",
        "work_provenance_event_append",
        "work_provenance_projection_update",
    ]:
        raise AssertionError(f"expected O1 stage sequence: {payload!r}")
    identity_rows = payload["identity_resolutions"]
    if [row["pipeline_run_id"] for row in identity_rows] != [
        "run-second-parent",
        "run-failed",
        "run-success",
    ]:
        raise AssertionError(f"expected O2 identity rows to follow trace order: {payload!r}")
    failed_identity = identity_rows[1]
    if failed_identity["selected_child_session_id"] != "codex-child":
        raise AssertionError(f"expected selected child session id in identity row: {payload!r}")
    if failed_identity["input_identity_value_hash"] == "subagent-1":
        raise AssertionError(f"identity row should not expose raw subsession id: {payload!r}")
    if failed_identity.get("conflict_reason") is None:
        raise AssertionError(f"expected failed trace identity conflict reason: {payload!r}")

    failed_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--status",
            "failed",
        ],
    )
    failed_payload = json.loads(failed_result.stdout)
    if [row["pipeline_run_id"] for row in failed_payload["runs"]] != ["run-failed"]:
        raise AssertionError(f"expected status filter to return only failed trace: {failed_payload!r}")
    if failed_payload["summary"]["failed_run_count"] != 1:
        raise AssertionError(f"expected filtered failed summary: {failed_payload!r}")

    run_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--run",
            "run-success",
        ],
    )
    run_payload = json.loads(run_result.stdout)
    if [row["pipeline_run_id"] for row in run_payload["runs"]] != ["run-success"]:
        raise AssertionError(f"expected run filter to return exact trace: {run_payload!r}")
    if [row["pipeline_run_id"] for row in run_payload["stages"]] != [
        "run-success",
        "run-success",
        "run-success",
    ]:
        raise AssertionError(f"expected run filter to scope stages: {run_payload!r}")

    parent_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--parent-session",
            "codex-parent",
        ],
    )
    parent_payload = json.loads(parent_result.stdout)
    if [row["pipeline_run_id"] for row in parent_payload["runs"]] != ["run-failed", "run-success"]:
        raise AssertionError(f"expected parent filter to exclude other parent: {parent_payload!r}")

    child_result = run_cli(
        cli_path,
        [
            "--json",
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
            "--child-session",
            "other-child",
        ],
    )
    child_payload = json.loads(child_result.stdout)
    if [row["pipeline_run_id"] for row in child_payload["runs"]] != ["run-second-parent"]:
        raise AssertionError(f"expected child filter to return matching child trace: {child_payload!r}")


def check_provenance_lifecycle_trace_text(cli_path: str, root: Path) -> None:
    database = root / "ProvenanceObservability.sqlite"
    create_observability_database(database)

    result = run_cli(
        cli_path,
        [
            "provenance",
            "traces",
            "lifecycle-ingestion",
            "--observability-database",
            str(database),
        ],
    )
    output = result.stdout
    for expected in [
        "Lifecycle ingestion traces: 3",
        "run-second-parent",
        "run-failed",
        "run-success",
        "stages: 3",
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
            check_provenance_lifecycle_trace_json(cli_path, root)
            check_provenance_lifecycle_trace_text(cli_path, root)
        except Exception as exc:
            print(f"FAIL: {exc}")
            return 1

    print("PASS: Provenance CLI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
