#!/usr/bin/env python3
"""Regression tests for the Codex token-audit CLI report."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import tempfile
from pathlib import Path

from claude_teams_test_utils import resolve_bmux_cli


def create_codex_state_database(path: Path, rows: list[tuple]) -> None:
    with sqlite3.connect(path) as conn:
        conn.execute(
            """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                tokens_used INTEGER,
                created_at REAL,
                updated_at REAL,
                source TEXT,
                model_provider TEXT,
                model TEXT,
                cwd TEXT,
                git_branch TEXT,
                git_origin_url TEXT,
                cli_version TEXT,
                rollout_path TEXT,
                title TEXT,
                preview TEXT
            )
            """
        )
        conn.executemany(
            """
            INSERT INTO threads (
                id, tokens_used, created_at, updated_at, source, model_provider,
                model, cwd, git_branch, git_origin_url, cli_version, rollout_path, title, preview
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            rows,
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


def write_rollout_fixture(path: Path, repeated_calls: int) -> None:
    events = [
        {"type": "session_meta", "payload": {"id": "fixture"}},
        {"type": "turn_context", "payload": {"cwd": "/repo/large"}},
        {"type": "event_msg", "payload": {"type": "user_message", "message": "run the search"}},
    ]
    for index in range(repeated_calls):
        call_id = f"call-{index}"
        command = "rg noisy-token-pattern Packages CLI tests"
        events.append(
            {
                "type": "response_item",
                "payload": {
                    "type": "function_call",
                    "name": "exec_command",
                    "call_id": call_id,
                    "arguments": json.dumps({"cmd": command, "workdir": "/repo/large"}),
                },
            }
        )
        events.append(
            {
                "type": "response_item",
                "payload": {
                    "type": "function_call_output",
                    "call_id": call_id,
                    "output": (
                        "Original token count: 9000\n"
                        "Optimized token count: 250\n"
                        "Raw output: bmux agent-token-output show terminal-output:fixture\n"
                    ),
                },
            }
        )
    path.write_text("\n".join(json.dumps(event) for event in events) + "\n", encoding="utf-8")


def test_codex_token_audit_reports_sessions(cli_path: str, root: Path) -> None:
    database = root / "state_5.sqlite"
    large_rollout = root / "large-rollout.jsonl"
    write_rollout_fixture(large_rollout, repeated_calls=12)
    rows = [
        (
            "thread-small",
            100,
            1_780_000_000.0,
            1_780_000_100.0,
            "codex",
            "openai",
            "gpt-5.5",
            "/repo/small",
            "main",
            "git@example.com:small.git",
            "1.2.3",
            None,
            "small task",
            "preview small",
        ),
        (
            "thread-large",
            500,
            1_780_086_400.0,
            1_780_086_500.0,
            "codex",
            "openai",
            "gpt-5.4-mini",
            "/repo/large",
            "feature",
            "git@example.com:large.git",
            "1.2.3",
            str(large_rollout),
            "large task",
            "preview large",
        ),
        (
            "thread-medium",
            200,
            1_780_086_410.0,
            1_780_086_600.0,
            "codex",
            "openai",
            "gpt-5.5",
            "/repo/medium",
            "feature",
            "git@example.com:medium.git",
            "1.2.3",
            str(root / "missing-rollout.jsonl"),
            "medium task",
            "preview medium",
        ),
    ]
    create_codex_state_database(database, rows)

    text_result = run_cli(
        cli_path,
        ["codex-token-audit", "--database", str(database), "--limit", "2"],
    )
    stdout = text_result.stdout
    for expected in [
        "Codex token audit",
        "Sessions: 3",
        "Total tokens: 800",
        "Highest-token sessions:",
        "thread-large",
        "large task",
        "CWD totals:",
        "signals:",
        "likely drivers:",
        "repeated: rg noisy-token-pattern Packages CLI tests x12",
        "1 session omitted",
        "Updated-day totals group each session's lifetime tokens",
        "Rollout analysis uses local session JSONL files",
    ]:
        if expected not in stdout:
            raise AssertionError(f"expected {expected!r} in text report:\n{stdout}")

    global_json = run_cli(
        cli_path,
        ["--json", "codex-token-audit", "--database", str(database)],
    )
    payload = json.loads(global_json.stdout)
    if payload["session_count"] != 3:
        raise AssertionError(f"expected 3 sessions in JSON payload: {payload!r}")
    if payload["total_tokens"] != 800:
        raise AssertionError(f"expected 800 tokens in JSON payload: {payload!r}")
    if [session["id"] for session in payload["sessions"]] != [
        "thread-large",
        "thread-medium",
        "thread-small",
    ]:
        raise AssertionError(f"sessions should be sorted by token count: {payload['sessions']!r}")
    large_session = payload["sessions"][0]
    large_analysis = large_session["analysis"]
    if large_session["rollout_path"] != str(large_rollout):
        raise AssertionError(f"expected rollout path in JSON payload: {large_session!r}")
    if "session_span_seconds" not in large_session or "duration_seconds" in large_session:
        raise AssertionError(f"expected session_span_seconds JSON field: {large_session!r}")
    if large_analysis["tool_call_count"] != 12:
        raise AssertionError(f"expected tool calls from rollout analysis: {large_analysis!r}")
    if large_analysis["estimated_tool_output_tokens"] != 108000:
        raise AssertionError(f"expected original token estimates from optimized output: {large_analysis!r}")
    if large_analysis["raw_output_ref_count"] != 12:
        raise AssertionError(f"expected raw-output reference count: {large_analysis!r}")
    if large_analysis["repeated_command_count"] != 11:
        raise AssertionError(f"expected repeated command count: {large_analysis!r}")
    if large_analysis["top_repeated_commands"][0]["count"] != 12:
        raise AssertionError(f"expected repeated command summary: {large_analysis!r}")
    for expected_driver in ["large_tool_output", "repeated_commands", "many_recoverable_outputs"]:
        if expected_driver not in large_analysis["driver_ids"]:
            raise AssertionError(f"expected {expected_driver!r} driver: {large_analysis!r}")
    if payload["sessions"][1]["analysis"]["rollout_exists"] is not False:
        raise AssertionError(f"missing rollout files should be reported, not fail: {payload['sessions'][1]!r}")
    if payload["cwd_totals"][0]["cwd"] != "/repo/large":
        raise AssertionError(f"expected cwd totals sorted by token count: {payload['cwd_totals']!r}")
    if payload["cwd_totals"][0]["tool_output_bytes"] <= 0:
        raise AssertionError(f"expected cwd totals to include tool output bytes: {payload['cwd_totals']!r}")
    if payload["model_totals"][0]["tokens"] != 500:
        raise AssertionError(f"expected largest model bucket first: {payload['model_totals']!r}")

    local_json = run_cli(
        cli_path,
        ["codex", "token-audit", "--database", str(database), "--json"],
    )
    alias_payload = json.loads(local_json.stdout)
    if alias_payload["total_tokens"] != 800:
        raise AssertionError(f"codex token-audit alias returned wrong payload: {alias_payload!r}")


def test_codex_token_audit_uses_highest_state_database(cli_path: str, root: Path) -> None:
    codex_home = root / "codex-home"
    codex_home.mkdir()
    create_codex_state_database(
        codex_home / "state_5.sqlite",
        [
            (
                "old-thread",
                10,
                1_780_000_000.0,
                1_780_000_000.0,
                "codex",
                "openai",
                "gpt-5.4",
                "/repo/old",
                "main",
                None,
                None,
                None,
                "old",
                "old",
            )
        ],
    )
    create_codex_state_database(
        codex_home / "state_7.sqlite",
        [
            (
                "new-thread",
                900,
                1_780_000_000.0,
                1_780_000_000.0,
                "codex",
                "openai",
                "gpt-5.5",
                "/repo/new",
                "main",
                None,
                None,
                None,
                "new",
                "new",
            )
        ],
    )

    result = run_cli(
        cli_path,
        ["codex-token-audit", "--codex-home", str(codex_home), "--json"],
    )
    payload = json.loads(result.stdout)
    expected_database_path = str((codex_home / "state_7.sqlite").resolve())
    if payload["database_path"] != expected_database_path:
        raise AssertionError(f"expected state_7.sqlite to be selected: {payload!r}")
    if payload["total_tokens"] != 900:
        raise AssertionError(f"expected state_7.sqlite contents: {payload!r}")


def main() -> int:
    try:
        cli_path = resolve_bmux_cli()
    except Exception as exc:
        print(f"FAIL: {exc}")
        return 1

    with tempfile.TemporaryDirectory(prefix="bmux-codex-token-audit-", dir="/tmp") as td:
        root = Path(td)
        try:
            test_codex_token_audit_reports_sessions(cli_path, root)
            test_codex_token_audit_uses_highest_state_database(cli_path, root)
        except Exception as exc:
            print(f"FAIL: {exc}")
            return 1

    print("PASS: Codex token audit report")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
