#!/usr/bin/env python3
"""Regression checks for the context-efficiency CLI."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import tempfile
from pathlib import Path

from claude_teams_test_utils import resolve_bmux_cli


def create_codex_state_database(path: Path, rollout_path: Path) -> None:
    with sqlite3.connect(path) as conn:
        conn.execute(
            """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                rollout_path TEXT,
                cwd TEXT,
                title TEXT,
                model_provider TEXT,
                model TEXT,
                reasoning_effort TEXT,
                approval_mode TEXT,
                sandbox_policy TEXT,
                git_branch TEXT,
                tokens_used INTEGER,
                source TEXT,
                created_at REAL,
                updated_at_ms REAL
            )
            """
        )
        conn.execute(
            """
            INSERT INTO threads (
                id, rollout_path, cwd, title, model_provider, model,
                reasoning_effort, approval_mode, sandbox_policy, git_branch,
                tokens_used, source, created_at, updated_at_ms
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "thread-cli",
                str(rollout_path),
                "/repo/bmux",
                "context efficiency fixture",
                "openai",
                "gpt-5",
                "high",
                "on-request",
                json.dumps({"type": "workspace-write"}),
                "context-efficiency",
                120_800,
                "codex",
                1_783_941_598.0,
                1_783_941_604_000.0,
            ),
        )


def write_rollout_fixture(path: Path) -> None:
    rows = [
        {
            "type": "session_meta",
            "timestamp": "2026-07-13T11:59:58Z",
            "payload": {
                "id": "thread-cli",
                "model": "gpt-5",
                "reasoning_effort": "high",
                "cwd": "/repo/bmux",
            },
        },
        {
            "type": "event_msg",
            "timestamp": "2026-07-13T12:00:00Z",
            "payload": {
                "type": "token_usage",
                "threadID": "thread-cli",
                "tokenUsage": {
                    "inputTokens": 120000,
                    "cachedInputTokens": 100000,
                    "outputTokens": 800,
                    "totalTokens": 120800,
                },
            },
        },
        {
            "type": "event_msg",
            "timestamp": "2026-07-13T12:00:01Z",
            "payload": {
                "type": "token_usage",
                "threadID": "thread-cli",
                "tokenUsage": {
                    "inputTokens": 120000,
                    "cachedInputTokens": 100000,
                    "outputTokens": 800,
                    "totalTokens": 120800,
                },
            },
        },
        {
            "type": "response_item",
            "timestamp": "2026-07-13T12:00:02Z",
            "payload": {
                "type": "function_call",
                "threadID": "thread-cli",
                "call_id": "call-1",
                "name": "exec_command",
                "arguments": json.dumps(
                    {
                        "cmd": "swift test --package-path Packages/macOS/BmuxContextEfficiency",
                        "workdir": "/repo/bmux",
                    }
                ),
            },
        },
        {
            "type": "response_item",
            "timestamp": "2026-07-13T12:00:03Z",
            "payload": {
                "type": "function_call_output",
                "threadID": "thread-cli",
                "call_id": "call-1",
                "output": (
                    "Original token count: 1800\n"
                    "Raw output: bmux agent-token-output show terminal-output:fixture\n"
                    "ok"
                ),
            },
        },
        {
            "type": "compacted",
            "timestamp": "2026-07-13T12:00:04Z",
            "payload": {"threadID": "thread-cli"},
        },
    ]
    content = "\n".join(json.dumps(row) for row in rows)
    path.write_text(content + "\n{not-json\n", encoding="utf-8")


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


def test_context_efficiency_cli_round_trip(cli_path: str, root: Path) -> None:
    context_database = root / "context-efficiency.sqlite"
    codex_home = root / "codex-home"
    codex_home.mkdir()
    rollout = root / "rollout-thread-cli.jsonl"
    write_rollout_fixture(rollout)
    create_codex_state_database(codex_home / "state_8.sqlite", rollout)

    import_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "import",
            str(rollout),
            "--database",
            str(context_database),
            "--codex-home",
            str(codex_home),
        ],
    )
    import_payload = json.loads(import_result.stdout)
    if import_payload["thread"]["normalized_thread_id"] != "codex:thread-cli":
        raise AssertionError(f"expected Codex metadata to resolve the thread: {import_payload!r}")
    import_summary = import_payload["import"]
    expected_counts = {
        "line_count": 7,
        "model_call_count": 1,
        "duplicate_token_telemetry_count": 1,
        "parser_error_count": 1,
        "tool_call_count": 1,
        "tool_output_count": 1,
        "compaction_count": 1,
    }
    for key, expected in expected_counts.items():
        if import_summary[key] != expected:
            raise AssertionError(f"expected {key}={expected}: {import_summary!r}")

    inspect_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "inspect-thread",
            "thread-cli",
            "--database",
            str(context_database),
        ],
    )
    if "Raw output: bmux" in inspect_result.stdout:
        raise AssertionError(f"inspect output leaked raw tool output:\n{inspect_result.stdout}")
    inspection = json.loads(inspect_result.stdout)
    thread = inspection["thread"]
    if thread["id"] != "codex:thread-cli":
        raise AssertionError(f"expected normalized thread id: {thread!r}")
    if thread["rollout_path"] != str(rollout):
        raise AssertionError(f"expected rollout path evidence reference: {thread!r}")
    source_reference = inspection["model_calls"][0]["source_reference"]
    for key in ["source_path", "byte_offset", "line_number", "parser_version"]:
        if key not in source_reference:
            raise AssertionError(f"missing source reference key {key}: {source_reference!r}")
    tool_output = inspection["tool_outputs"][0]
    if tool_output["estimated_original_tokens"] != 1800:
        raise AssertionError(f"expected original token estimate, not raw output: {tool_output!r}")
    if "output" in tool_output:
        raise AssertionError(f"tool output payload should not include raw output: {tool_output!r}")

    day_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "summarize-day",
            "2026-07-13",
            "--database",
            str(context_database),
        ],
    )
    summary = json.loads(day_result.stdout)["summary"]
    if summary["thread_count"] != 1 or summary["model_call_count"] != 1:
        raise AssertionError(f"expected one imported thread and model call: {summary!r}")
    if summary["total_tokens"] != 120800 or summary["cached_input_tokens"] != 100000:
        raise AssertionError(f"expected token totals from the rollout telemetry: {summary!r}")


def main() -> int:
    try:
        cli_path = resolve_bmux_cli()
    except Exception as exc:
        print(f"FAIL: {exc}")
        return 1

    with tempfile.TemporaryDirectory(prefix="bmux-context-efficiency-cli-", dir="/tmp") as td:
        root = Path(td)
        try:
            test_context_efficiency_cli_round_trip(cli_path, root)
        except Exception as exc:
            print(f"FAIL: {exc}")
            return 1

    print("PASS: Context efficiency CLI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
