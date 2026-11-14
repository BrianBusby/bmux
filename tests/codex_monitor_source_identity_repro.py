#!/usr/bin/env python3
"""Synthetic real-CLI regression for cross-session monitor publication.

Set BMUX_TEST_CLI to the executable in an isolated tagged app bundle. The
fixtures, socket, home, and PE database are private temporary data.
"""
import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

from test_codex_feed_hooks import FAKE_SURFACE_ID, FAKE_WORKSPACE_ID, FakeBmuxSocket


class PrivateFakeSocket(FakeBmuxSocket):
    def _handle_conn(self, conn: object) -> None:
        try:
            super()._handle_conn(conn)
        except BrokenPipeError:
            pass  # The CLI intentionally closes its one-way telemetry connection.


class CodexMonitorSourceIdentityRepro(unittest.TestCase):
    def run_monitor(self, metadata: str, signal: str) -> tuple[list[str], list[dict], list[str]]:
        cli = os.environ["BMUX_TEST_CLI"]
        with tempfile.TemporaryDirectory(prefix="bmux-monitor-source-", dir="/tmp") as temp:
            root = Path(temp)
            socket_path = root / "socket"
            transcript = root / "transcript.jsonl"
            lines = []
            if metadata in {"matching", "foreign"}:
                provider_id = "session-a" if metadata == "matching" else "session-b"
                lines.append({"type": "session_meta", "payload": {"id": provider_id, "cwd": str(root)}})
            lines.append({"type": "event_msg", "payload": {"type": "task_started", "turn_id": "turn-a"}})
            if signal == "input":
                lines.append({"type": "event_msg", "payload": {"type": "request_user_input", "turn_id": "turn-a",
                              "call_id": "call-a", "questions": [{"question": "Choose an option"}]}})
            else:
                lines.append({"type": "event_msg", "payload": {"type": "error", "turn_id": "turn-a",
                              "message": "Synthetic stream failure", "codex_error_info": "response_stream_disconnected"}})
                lines.append({"type": "event_msg", "payload": {"type": "turn_complete", "turn_id": "turn-a"}})
            # Simulate an interrupted, incomplete metadata line followed by later bytes.
            partial = '{"type":"session_meta","payload":{"id":"session-a"' if metadata == "partial" else ""
            transcript.write_text(partial + "\n".join(json.dumps(line) for line in lines) + "\n", encoding="utf-8")
            env = {"HOME": temp, "CFFIXED_USER_HOME": temp, "BMUX_PROVENANCE_HOME": temp,
                   "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": str(socket_path),
                   "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID,
                   "BMUX_CLI_SENTRY_DISABLED": "1"}
            with PrivateFakeSocket(socket_path, None) as fake:
                try:
                    subprocess.run([cli, "--socket", str(socket_path), "hooks", "codex", "monitor",
                                    "--workspace", FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID,
                                    "--session", "session-a", "--turn", "turn-a", "--transcript", str(transcript)],
                                   env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2, check=False)
                except subprocess.TimeoutExpired:
                    pass  # Input remains pending; subprocess.run terminates and waits for its child.
                commands = [frame.get("raw", "") for frame in fake.frames]
                statuses = [json.loads(path.read_text(encoding="utf-8")) for path in root.rglob("*.status.json")]
                databases = list(root.rglob("provenance.sqlite"))
                sessions = []
                if databases:
                    with sqlite3.connect(databases[0]) as db:
                        tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                        if "provenance_sessions" in tables:
                            sessions = [row[0] for row in db.execute("SELECT id FROM provenance_sessions")]
                return commands, statuses, sessions

    def run_stop(self, metadata: str, explicit_session: bool) -> list[str]:
        cli = os.environ["BMUX_TEST_CLI"]
        with tempfile.TemporaryDirectory(prefix="bmux-stop-source-", dir="/tmp") as temp:
            root = Path(temp)
            socket_path = root / "socket"
            transcript = root / "transcript.jsonl"
            provider_id = "session-a" if metadata == "matching" else "session-b"
            lines = [
                {"type": "session_meta", "payload": {"id": provider_id}},
                {"type": "event_msg", "payload": {"type": "task_started", "turn_id": "turn-a"}},
                {"type": "event_msg", "payload": {"type": "error", "turn_id": "turn-a",
                 "message": "Synthetic stream failure", "codex_error_info": "response_stream_disconnected"}},
            ]
            transcript.write_text("\n".join(json.dumps(line) for line in lines) + "\n", encoding="utf-8")
            env = {"HOME": temp, "CFFIXED_USER_HOME": temp, "BMUX_PROVENANCE_HOME": temp,
                   "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": str(socket_path),
                   "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID,
                   "BMUX_AGENT_HOOK_STATE_DIR": temp, "BMUX_CLI_SENTRY_DISABLED": "1"}
            payload = {"turn_id": "turn-a", "transcript_path": str(transcript)}
            if explicit_session:
                payload["session_id"] = "session-a"
            with PrivateFakeSocket(socket_path, None) as fake:
                result = subprocess.run([cli, "--socket", str(socket_path), "hooks", "codex", "stop"],
                                        input=json.dumps(payload), text=True, capture_output=True,
                                        env=env, timeout=8, check=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                return [frame.get("raw", "") for frame in fake.frames]

    def test_matching_metadata_positive_controls(self) -> None:
        for signal in ("input", "failure"):
            with self.subTest(signal=signal):
                commands, statuses, sessions = self.run_monitor("matching", signal)
                self.assertTrue(any(command.startswith("set_status codex ") for command in commands), commands)
                self.assertIn("session-a", sessions)
                self.assertTrue(any(status.get("cursorOffset", 0) > 0 for status in statuses), statuses)

    def test_foreign_or_missing_metadata_must_not_publish(self) -> None:
        for metadata in ("foreign", "missing", "partial"):
            for signal in ("input", "failure"):
                with self.subTest(metadata=metadata, signal=signal):
                    commands, statuses, sessions = self.run_monitor(metadata, signal)
                    if metadata == "foreign":
                        self.assertTrue(any(status.get("appendFailures", 0) > 0
                                            and status.get("lastErrorKind") == "LiveImportError"
                                            and status.get("cursorOffset") == 0 for status in statuses), statuses)
                        self.assertNotIn("session-b", sessions)
                    forbidden = ("set_status codex ", "set_agent_lifecycle codex needsInput ", "notify_target ")
                    self.assertFalse(any(command.startswith(forbidden) for command in commands), commands)


    def test_stop_transcript_failure_requires_matching_session(self) -> None:
        control = self.run_stop("matching", explicit_session=True)
        self.assertTrue(any(command.startswith("set_status codex Codex network error") for command in control), control)
        for explicit_session in (True, False):
            with self.subTest(explicit_session=explicit_session):
                commands = self.run_stop("foreign", explicit_session=explicit_session)
                self.assertFalse(any(command.startswith("set_status codex Codex network error")
                                     for command in commands), commands)


if __name__ == "__main__":
    unittest.main()
