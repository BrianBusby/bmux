#!/usr/bin/env python3
"""Regression checks for the context-efficiency CLI."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import tempfile
from pathlib import Path

from claude_teams_test_utils import resolve_bmux_cli


RAW_MARKER = "SECRET_RAW_PAYLOAD_SHOULD_NOT_LEAK"


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
            "type": "event_msg",
            "payload": {
                "type": "token_usage",
                "threadID": "thread-cli",
                "tokenUsage": {
                    "inputTokens": 121000,
                    "cachedInputTokens": 100000,
                    "outputTokens": 1000,
                    "totalTokens": 122000,
                },
                "raw_payload_marker": RAW_MARKER,
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
                    + RAW_MARKER +
                    "\nok"
                ),
            },
        },
        {
            "type": "event_msg",
            "timestamp": "2026-07-13T12:00:03Z",
            "payload": {
                "type": "user_message",
                "threadID": "thread-cli",
                "message": "Continue STE-1964 on https://github.com/manaflow-ai/bmux/pull/4536",
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


def write_replacement_rollout(path: Path) -> None:
    row = {
        "type": "event_msg",
        "timestamp": "2026-07-14T12:00:00Z",
        "payload": {
            "type": "token_usage",
            "threadID": "thread-cli-replacement",
            "tokenUsage": {"inputTokens": 42, "totalTokens": 42},
        },
    }
    path.write_text(json.dumps(row) + "\n", encoding="utf-8")


def append_rollout_event(path: Path, timestamp: str, total_tokens: int) -> None:
    row = {
        "type": "event_msg",
        "timestamp": timestamp,
        "payload": {
            "type": "token_usage",
            "threadID": "append-thread",
            "tokenUsage": {
                "inputTokens": total_tokens,
                "totalTokens": total_tokens,
            },
        },
    }
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row) + "\n")


def write_invalid_utf8_rollout(path: Path) -> None:
    before = {
        "type": "event_msg",
        "timestamp": "2026-07-16T12:00:00Z",
        "payload": {
            "type": "token_usage",
            "threadID": "utf8-thread",
            "tokenUsage": {"inputTokens": 10, "totalTokens": 10},
        },
    }
    after = {
        "type": "event_msg",
        "timestamp": "2026-07-16T12:01:00Z",
        "payload": {
            "type": "token_usage",
            "threadID": "utf8-thread",
            "tokenUsage": {"inputTokens": 15, "totalTokens": 15},
        },
    }
    data = bytearray()
    data.extend((json.dumps(before) + "\n").encode("utf-8"))
    data.extend(b"\xff\xfe\n")
    data.extend((json.dumps(after) + "\n").encode("utf-8"))
    path.write_bytes(bytes(data))


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
    if RAW_MARKER in import_result.stdout:
        raise AssertionError(f"import output leaked raw fixture marker:\n{import_result.stdout}")
    import_payload = json.loads(import_result.stdout)
    if import_payload["thread"]["normalized_thread_id"] != "codex:thread-cli":
        raise AssertionError(f"expected Codex metadata to resolve the thread: {import_payload!r}")
    metadata = import_payload["thread"]
    expected_metadata = {
        "cwd": "/repo/bmux",
        "title": "context efficiency fixture",
        "model_provider": "openai",
        "model": "gpt-5",
        "reasoning_effort": "high",
        "approval_mode": "on-request",
        "sandbox_policy_type": "workspace-write",
        "git_branch": "context-efficiency",
        "tokens_used": 120800,
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise AssertionError(f"expected Codex metadata {key}={expected!r}: {metadata!r}")
    import_summary = import_payload["import"]
    expected_counts = {
        "line_count": 9,
        "model_call_count": 2,
        "duplicate_token_telemetry_count": 1,
        "parser_error_count": 2,
        "tool_call_count": 1,
        "tool_output_count": 1,
        "compaction_count": 1,
    }
    for key, expected in expected_counts.items():
        if import_summary[key] != expected:
            raise AssertionError(f"expected {key}={expected}: {import_summary!r}")

    repeat_result = run_cli(
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
    repeat_import = json.loads(repeat_result.stdout)["import"]
    repeat_zero_counts = [
        "line_count",
        "model_call_count",
        "parser_error_count",
        "tool_call_count",
        "tool_output_count",
        "compaction_count",
    ]
    for key in repeat_zero_counts:
        if repeat_import[key] != 0:
            raise AssertionError(f"unchanged rollout re-import should report no new {key}: {repeat_import!r}")

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
    for forbidden in [RAW_MARKER, "Raw output: bmux", "Original token count: 1800"]:
        if forbidden in inspect_result.stdout:
            raise AssertionError(f"inspect output leaked raw tool output:\n{inspect_result.stdout}")
    inspection = json.loads(inspect_result.stdout)
    thread = inspection["thread"]
    if thread["id"] != "codex:thread-cli":
        raise AssertionError(f"expected normalized thread id: {thread!r}")
    if thread["rollout_path"] != str(rollout):
        raise AssertionError(f"expected rollout path evidence reference: {thread!r}")
    if thread["cumulative_total_tokens"] != 122000:
        raise AssertionError(f"expected missing-timestamp telemetry to update thread totals: {thread!r}")
    if len(inspection["model_calls"]) != 2:
        raise AssertionError(f"expected duplicate suppression plus missing-timestamp model call: {inspection!r}")
    missing_timestamp_calls = [
        row for row in inspection["model_calls"] if row["source_reference"]["line_number"] == 4
    ]
    if len(missing_timestamp_calls) != 1 or "timestamp" in missing_timestamp_calls[0]:
        raise AssertionError(f"missing-timestamp model call should remain timestampless: {inspection!r}")
    if len(inspection["parser_errors"]) != 2:
        raise AssertionError(f"expected missing-timestamp and invalid-JSON diagnostics: {inspection!r}")
    if inspection["parser_errors"][0]["message"] != "missing rollout event timestamp":
        raise AssertionError(f"expected bounded missing-timestamp diagnostic: {inspection!r}")
    source_reference = inspection["model_calls"][0]["source_reference"]
    for key in ["source_path", "byte_offset", "line_number", "parser_version"]:
        if key not in source_reference:
            raise AssertionError(f"missing source reference key {key}: {source_reference!r}")
    tool_output = inspection["tool_outputs"][0]
    if tool_output["estimated_original_tokens"] != 1800:
        raise AssertionError(f"expected original token estimate, not raw output: {tool_output!r}")
    if "output" in tool_output:
        raise AssertionError(f"tool output payload should not include raw output: {tool_output!r}")
    command_execution = inspection["command_executions"][0]
    if command_execution["category"] != "tests":
        raise AssertionError(f"expected command category in inspection: {command_execution!r}")
    if command_execution["normalized_executable"] != "swift":
        raise AssertionError(f"expected normalized executable in inspection: {command_execution!r}")
    if command_execution["output_attribution_confidence"] != "exact_tool_call_link":
        raise AssertionError(f"expected exact tool output linkage: {command_execution!r}")
    if command_execution["raw_output_reference_count"] != 1:
        raise AssertionError(f"expected raw output reference count: {command_execution!r}")
    if "raw_output" in command_execution:
        raise AssertionError(f"command execution should not include raw output: {command_execution!r}")

    work_item_references = inspection["work_item_references"]
    references_by_value = {row["reference"]: row for row in work_item_references}
    for expected_reference in [
        "github:manaflow-ai/bmux#4536",
        "ticket:STE-1964",
        "branch:context-efficiency",
    ]:
        if expected_reference not in references_by_value:
            raise AssertionError(f"missing work item reference {expected_reference}: {work_item_references!r}")
    pull_request = references_by_value["github:manaflow-ai/bmux#4536"]
    if pull_request["kind"] != "pull_request" or pull_request["number"] != 4536:
        raise AssertionError(f"expected explicit PR reference fact: {pull_request!r}")
    if pull_request["source_kind"] != "message" or pull_request["confidence"] != "explicit_reference":
        raise AssertionError(f"expected PR reference evidence labels: {pull_request!r}")
    branch_reference = references_by_value["branch:context-efficiency"]
    if branch_reference["source_kind"] != "codex_state_metadata":
        raise AssertionError(f"expected branch reference from Codex state metadata: {branch_reference!r}")

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
    if RAW_MARKER in day_result.stdout:
        raise AssertionError(f"day summary leaked raw fixture marker:\n{day_result.stdout}")
    summary = json.loads(day_result.stdout)["summary"]
    if summary["thread_count"] != 1 or summary["model_call_count"] != 1:
        raise AssertionError(f"expected one imported thread and model call: {summary!r}")
    if summary["total_tokens"] != 120800 or summary["cached_input_tokens"] != 100000:
        raise AssertionError(f"expected token totals from the rollout telemetry: {summary!r}")
    if summary["parser_error_count"] != 2:
        raise AssertionError(f"expected bounded parser diagnostics in day summary: {summary!r}")

    write_replacement_rollout(rollout)
    reset_result = run_cli(
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
    reset_payload = json.loads(reset_result.stdout)
    reset_import = reset_payload["import"]
    if reset_import["reset_cursor"] is not True:
        raise AssertionError(f"expected source shrink to reset cursor: {reset_payload!r}")
    if reset_import["line_count"] != 1 or reset_import["model_call_count"] != 1:
        raise AssertionError(f"expected replacement rollout to import one model call: {reset_payload!r}")
    if reset_import["parser_error_count"] != 0:
        raise AssertionError(f"replacement rollout should clear old parser errors: {reset_payload!r}")

    replacement_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "inspect-thread",
            "thread-cli-replacement",
            "--database",
            str(context_database),
        ],
    )
    replacement = json.loads(replacement_result.stdout)
    if replacement["thread"]["cumulative_total_tokens"] != 42:
        raise AssertionError(f"expected replacement thread totals after reset: {replacement!r}")

    stale_day_result = run_cli(
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
    stale_summary = json.loads(stale_day_result.stdout)["summary"]
    if stale_summary["thread_count"] != 0 or stale_summary["parser_error_count"] != 0:
        raise AssertionError(f"reset cursor should remove stale source facts: {stale_summary!r}")


def test_context_efficiency_append_import_reports_only_new_lines(cli_path: str, root: Path) -> None:
    append_root = root / "append"
    append_root.mkdir()
    database = append_root / "context-efficiency.sqlite"
    rollout = append_root / "rollout-append-thread.jsonl"
    rollout.write_text("", encoding="utf-8")
    append_rollout_event(rollout, "2026-07-15T12:00:00Z", 10)

    first_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "import",
            str(rollout),
            "--database",
            str(database),
        ],
    )
    first_import = json.loads(first_result.stdout)["import"]
    if first_import["line_count"] != 1 or first_import["model_call_count"] != 1:
        raise AssertionError(f"expected first append fixture import to read one row: {first_import!r}")

    append_rollout_event(rollout, "2026-07-15T12:01:00Z", 15)
    second_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "import",
            str(rollout),
            "--database",
            str(database),
        ],
    )
    second_import = json.loads(second_result.stdout)["import"]
    if second_import["line_count"] != 1 or second_import["model_call_count"] != 1:
        raise AssertionError(f"append import should report only the new row: {second_import!r}")
    if second_import["reset_cursor"] is not False:
        raise AssertionError(f"append import should not reset the cursor: {second_import!r}")

    inspection_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "inspect-thread",
            "append-thread",
            "--database",
            str(database),
        ],
    )
    inspection = json.loads(inspection_result.stdout)
    if inspection["thread"]["cumulative_total_tokens"] != 15:
        raise AssertionError(f"expected appended telemetry to update latest thread total: {inspection!r}")
    if len(inspection["model_calls"]) != 2:
        raise AssertionError(f"expected both appended model calls to be retained: {inspection!r}")

    summary_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "summarize-day",
            "2026-07-15",
            "--database",
            str(database),
        ],
    )
    summary = json.loads(summary_result.stdout)["summary"]
    if summary["model_call_count"] != 2 or summary["total_tokens"] != 25:
        raise AssertionError(f"expected appended rows in day summary: {summary!r}")


def test_context_efficiency_invalid_utf8_import_continues(cli_path: str, root: Path) -> None:
    utf8_root = root / "invalid-utf8"
    utf8_root.mkdir()
    database = utf8_root / "context-efficiency.sqlite"
    rollout = utf8_root / "rollout-utf8-thread.jsonl"
    write_invalid_utf8_rollout(rollout)

    import_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "import",
            str(rollout),
            "--database",
            str(database),
        ],
    )
    imported = json.loads(import_result.stdout)["import"]
    if imported["line_count"] != 3 or imported["model_call_count"] != 2:
        raise AssertionError(f"invalid UTF-8 import should continue around bad line: {imported!r}")
    if imported["parser_error_count"] != 1:
        raise AssertionError(f"invalid UTF-8 import should report one parser diagnostic: {imported!r}")

    inspection_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "inspect-thread",
            "utf8-thread",
            "--database",
            str(database),
        ],
    )
    inspection = json.loads(inspection_result.stdout)
    if inspection["thread"]["cumulative_total_tokens"] != 15:
        raise AssertionError(f"valid rows around invalid UTF-8 should update thread totals: {inspection!r}")
    if len(inspection["parser_errors"]) != 1:
        raise AssertionError(f"expected one invalid UTF-8 parser diagnostic: {inspection!r}")
    parser_error = inspection["parser_errors"][0]
    if parser_error["message"] != "line is not UTF-8":
        raise AssertionError(f"expected invalid UTF-8 diagnostic: {inspection!r}")
    if parser_error["source_reference"]["line_number"] != 2:
        raise AssertionError(f"expected diagnostic to point at invalid byte line: {inspection!r}")

    summary_result = run_cli(
        cli_path,
        [
            "--json",
            "context-efficiency",
            "summarize-day",
            "2026-07-16",
            "--database",
            str(database),
        ],
    )
    summary = json.loads(summary_result.stdout)["summary"]
    if summary["model_call_count"] != 2 or summary["total_tokens"] != 25:
        raise AssertionError(f"expected valid UTF-8 rows in day summary: {summary!r}")
    if summary["parser_error_count"] != 1:
        raise AssertionError(f"expected invalid UTF-8 diagnostic in day summary: {summary!r}")


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
            test_context_efficiency_append_import_reports_only_new_lines(cli_path, root)
            test_context_efficiency_invalid_utf8_import_continues(cli_path, root)
        except Exception as exc:
            print(f"FAIL: {exc}")
            return 1

    print("PASS: Context efficiency CLI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
