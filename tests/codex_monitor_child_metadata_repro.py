#!/usr/bin/env python3
"""Synthetic real-CLI child identity regression; not an automatic CI test.

Set BMUX_TEST_CLI to an isolated tagged app's CLI executable. The metadata
shape follows Codex rust-v0.168.0 SessionMeta: session_id is the root thread,
id is the current thread, and older metadata may omit session_id. A copied
source metadata record models a fork history; its following evidence is not
used to assert ownership. Everything written by this fixture is temporary.
"""

import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

from codex_monitor_source_identity_repro import PrivateFakeSocket
from test_codex_feed_hooks import FAKE_SURFACE_ID, FAKE_WORKSPACE_ID

ROOT_ID = "11111111-1111-4111-8111-111111111111"
CHILD_ID = "22222222-2222-4222-8222-222222222222"


class CodexMonitorChildMetadataRepro(unittest.TestCase):
    def read_threads(self, kind: str) -> tuple[list[tuple[str, str]], list[dict]]:
        cli = os.environ["BMUX_TEST_CLI"]
        with tempfile.TemporaryDirectory(prefix="bmux-child-", dir="/tmp") as temp:
            home = Path(temp)
            socket_path = home / "socket"
            transcript = home / "transcript.jsonl"
            metadata = {
                "id": ROOT_ID if kind == "root" else CHILD_ID,
                "timestamp": "2026-11-13T12:00:00Z",
                "cwd": "/tmp/synthetic-workspace",
                "originator": "codex_cli_rs",
                "source": "cli",
                "model_provider": "openai",
            }
            if kind == "root":
                metadata["session_id"] = ROOT_ID
            elif kind == "child":
                metadata.update(session_id=ROOT_ID, parent_thread_id=ROOT_ID, forked_from_id=ROOT_ID)
            records = [{"type": "session_meta", "payload": metadata}]
            if kind == "child":
                # A fork may retain source metadata after its own canonical record.
                records.append({"type": "session_meta", "payload": {"id": ROOT_ID, "session_id": ROOT_ID}})
            transcript.write_text("".join(json.dumps(record) + "\n" for record in records), encoding="utf-8")
            expected_id = ROOT_ID if kind == "root" else CHILD_ID
            env = {
                "HOME": temp,
                "CFFIXED_USER_HOME": temp,
                "BMUX_PROVENANCE_HOME": temp,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "BMUX_SOCKET_PATH": str(socket_path),
                "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID,
                "BMUX_SURFACE_ID": FAKE_SURFACE_ID,
                "BMUX_CLI_SENTRY_DISABLED": "1",
            }
            with PrivateFakeSocket(socket_path, None):
                try:
                    result = subprocess.run(
                        [cli, "--socket", str(socket_path), "hooks", "codex", "monitor",
                         "--workspace", FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID,
                         "--session", expected_id, "--transcript", str(transcript)],
                        env=env, capture_output=True, timeout=3, check=False,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                except subprocess.TimeoutExpired:
                    pass  # run() terminates and waits for its child.
            db_path = home / ".local/state/provenance-engine/provenance.sqlite"
            threads = []
            if db_path.exists():
                with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as db:
                    threads = db.execute(
                        "SELECT session_id, provider_thread_id FROM provenance_coding_agent_threads"
                    ).fetchall()
            statuses = [json.loads(path.read_text(encoding="utf-8")) for path in home.rglob("*.status.json")]
            return threads, statuses

    def test_root_and_legacy_id_controls(self) -> None:
        for kind, expected in (("root", ROOT_ID), ("legacy", CHILD_ID)):
            with self.subTest(kind=kind):
                threads, statuses = self.read_threads(kind)
                self.assertIn((expected, expected), threads)
                self.assertTrue(any(status.get("cursorOffset", 0) > 0 for status in statuses), statuses)

    def test_child_thread_identity_is_preserved(self) -> None:
        threads, statuses = self.read_threads("child")
        self.assertIn((CHILD_ID, CHILD_ID), threads, f"threads={threads!r}, status={statuses!r}")
        self.assertTrue(any(status.get("cursorOffset", 0) > 0 for status in statuses), statuses)


    def test_fork_history_does_not_reassign_existing_parent_turn(self) -> None:
        cli = os.environ["BMUX_TEST_CLI"]
        with tempfile.TemporaryDirectory(prefix="bmux-fork-", dir="/tmp") as temp:
            home = Path(temp)
            socket_path = home / "socket"
            env = {
                "HOME": temp, "CFFIXED_USER_HOME": temp, "BMUX_PROVENANCE_HOME": temp,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": str(socket_path),
                "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID,
                "BMUX_CLI_SENTRY_DISABLED": "1",
            }
            root_meta = {"type": "session_meta", "payload": {"id": ROOT_ID, "session_id": ROOT_ID}}
            child_meta = {"type": "session_meta", "payload": {
                "id": CHILD_ID, "session_id": ROOT_ID, "forked_from_id": ROOT_ID,
                "parent_thread_id": ROOT_ID,
            }}
            inherited_turn = {"type": "event_msg", "payload": {
                "type": "task_started", "turn_id": "33333333-3333-4333-8333-333333333333",
            }}
            root_path = home / "root.jsonl"
            child_path = home / "child.jsonl"
            root_path.write_text("".join(json.dumps(row) + "\n" for row in (root_meta, inherited_turn)))
            child_path.write_text("".join(json.dumps(row) + "\n" for row in
                                          (child_meta, root_meta, inherited_turn)))
            db_path = home / ".local/state/provenance-engine/provenance.sqlite"

            def run_monitor(path: Path, provider_id: str) -> None:
                try:
                    result = subprocess.run(
                        [cli, "--socket", str(socket_path), "hooks", "codex", "monitor",
                         "--workspace", FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID,
                         "--session", provider_id, "--transcript", str(path)],
                        env=env, capture_output=True, timeout=3, check=False,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                except subprocess.TimeoutExpired:
                    pass

            with PrivateFakeSocket(socket_path, None):
                run_monitor(root_path, ROOT_ID)
                with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as db:
                    before = db.execute("SELECT session_id, provider_turn_id FROM provenance_coding_agent_turns").fetchall()
                self.assertEqual(before, [(ROOT_ID, inherited_turn["payload"]["turn_id"])])
                run_monitor(child_path, CHILD_ID)
            with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as db:
                after = db.execute("SELECT session_id, provider_turn_id FROM provenance_coding_agent_turns").fetchall()
                threads = db.execute("SELECT session_id, provider_thread_id FROM provenance_coding_agent_threads").fetchall()
            self.assertEqual(after, before, "copied turn must not replace the parent's record")
            self.assertIn((CHILD_ID, CHILD_ID), threads,
                          "rejecting the child does not establish safe fork-history ingestion")


if __name__ == "__main__":
    unittest.main()
