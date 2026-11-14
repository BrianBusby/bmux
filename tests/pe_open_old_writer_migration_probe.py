#!/usr/bin/env python3
"""Characterize an already-open old PE CLI across an experimental migration.

Run explicitly, outside automatic test discovery, with BMUX_OLD_CLI and
BMUX_NEW_CLI pointing at existing isolated CLI executables. Expected schemas
are 31 and 34 respectively; this fixture verifies the new claims table and
must not be read as proof of the executables' source revisions. Synthetic
transcripts, logs, socket, cursors and database live in a temporary directory.
"""

import hashlib
import json
import os
import sqlite3
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

from test_codex_feed_hooks import FAKE_SURFACE_ID, FAKE_WORKSPACE_ID, FakeBmuxSocket

SESSION = "11111111-1111-4111-8111-111111111111"


class PrivateFakeSocket(FakeBmuxSocket):
    def _handle_conn(self, conn: object) -> None:
        try:
            super()._handle_conn(conn)
        except BrokenPipeError:
            pass


def transcript_line(kind: str, payload: dict) -> str:
    return json.dumps({"timestamp": "2026-11-13T10:00:00Z", "type": kind, "payload": payload}) + "\n"


def cursor_offset(directory: Path) -> int:
    if not directory.exists():
        return 0
    for path in directory.glob("*.json"):
        if path.name.endswith(".status.json"):
            continue
        try:
            return int(json.loads(path.read_text(encoding="utf-8"))["byteOffset"])
        except (OSError, ValueError, KeyError, json.JSONDecodeError):
            continue
    return 0


def wait_for_cursor(directory: Path, greater_than: int, process: subprocess.Popen) -> int:
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        offset = cursor_offset(directory)
        if offset > greater_than:
            return offset
        if process.poll() is not None:
            raise AssertionError(f"old monitor exited before cursor advanced: {process.returncode}")
        time.sleep(0.05)
    raise AssertionError(f"old monitor cursor did not advance beyond {greater_than}")


def stop_process(process: subprocess.Popen) -> None:
    if process.poll() is None:
        process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


class OpenOldWriterMigrationProbe(unittest.TestCase):
    def test_old_open_writer_bypasses_schema_open_check(self) -> None:
        old_cli = Path(os.environ["BMUX_OLD_CLI"]).resolve(strict=True)
        new_cli = Path(os.environ["BMUX_NEW_CLI"]).resolve(strict=True)
        with tempfile.TemporaryDirectory(prefix="bmux-writer-", dir="/tmp") as temp:
            root = Path(temp)
            home = root / "home"
            home.mkdir()
            socket_path = root / "socket"
            transcript = root / "transcript.jsonl"
            migration_source = root / "migration.jsonl"
            transcript.write_text(
                transcript_line("session_meta", {"id": SESSION, "session_id": SESSION}) +
                transcript_line("event_msg", {"type": "task_started", "turn_id": "turn-one"}),
                encoding="utf-8",
            )
            migration_source.write_text(transcript_line("session_meta", {"id": "migration-control"}), encoding="utf-8")
            database = home / ".local/state/provenance-engine/provenance.sqlite"
            cursors = home / ".local/state/bmux/codex-transcript-cursors"
            env = {
                "HOME": str(home), "CFFIXED_USER_HOME": str(home), "BMUX_PROVENANCE_HOME": str(home),
                "BMUX_SOCKET_PATH": str(socket_path), "BMUX_DEBUG_LOG": str(root / "debug.log"),
                "BMUX_CLI_SENTRY_DISABLED": "1", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TMPDIR": temp,
                "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID,
            }
            with PrivateFakeSocket(socket_path, None):
                monitor = subprocess.Popen(
                    [str(old_cli), "--socket", str(socket_path), "hooks", "codex", "monitor",
                     "--workspace", FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID,
                     "--session", SESSION, "--transcript", str(transcript)],
                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                )
                try:
                    initial_offset = wait_for_cursor(cursors, 0, monitor)
                    with sqlite3.connect(database) as db:
                        self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 31)
                        self.assertEqual(db.execute(
                            "SELECT session_id, provider_turn_id FROM provenance_coding_agent_turns"
                        ).fetchall(), [(SESSION, "turn-one")])
                    migration = subprocess.run(
                        [str(new_cli), "--json", "provenance", "import", "codex-transcripts",
                         "--path", str(migration_source), "--database", str(database)],
                        env=env, text=True, capture_output=True, timeout=20, check=False,
                    )
                    self.assertEqual(migration.returncode, 0, migration.stderr)
                    with sqlite3.connect(database) as db:
                        self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 34)
                        self.assertIsNotNone(db.execute(
                            "SELECT 1 FROM sqlite_master WHERE type='table' "
                            "AND name='provenance_coding_agent_turn_identity_claims'"
                        ).fetchone())
                        self.assertGreater(db.execute(
                            "SELECT count(*) FROM provenance_coding_agent_turn_identity_claims"
                        ).fetchone()[0], 0, "migration did not backfill the existing turn claim")
                    reopened = subprocess.run(
                        [str(old_cli), "--json", "provenance", "import", "codex-transcripts",
                         "--path", str(transcript), "--database", str(database)],
                        env=env, text=True, capture_output=True, timeout=10, check=False,
                    )
                    self.assertNotEqual(reopened.returncode, 0)
                    self.assertIn("unsupportedSchema(found: 34, supported: 31)", reopened.stdout + reopened.stderr)
                    with transcript.open("a", encoding="utf-8") as handle:
                        handle.write(transcript_line("event_msg", {"type": "task_started", "turn_id": "turn-two"}))
                        handle.flush()
                        os.fsync(handle.fileno())
                    final_offset = wait_for_cursor(cursors, initial_offset, monitor)
                    self.assertIsNone(monitor.poll(), "old process was replaced or exited")
                    with sqlite3.connect(database) as db:
                        turn = db.execute(
                            "SELECT id, session_id FROM provenance_coding_agent_turns WHERE provider_turn_id=?",
                            ("turn-two",),
                        ).fetchone()
                        self.assertIsNotNone(turn)
                        self.assertEqual(turn[1], SESSION)
                        claims = db.execute(
                            "SELECT count(*) FROM provenance_coding_agent_turn_identity_claims WHERE turn_id=?",
                            (turn[0],),
                        ).fetchone()[0]
                    self.assertEqual(claims, 0, "fixture characterizes this experimental binary, not a safe rollout")
                    print(f"schemas=31->34 cursor={initial_offset}->{final_offset} "
                          f"old_sha256={hashlib.sha256(old_cli.read_bytes()).hexdigest()} "
                          f"new_sha256={hashlib.sha256(new_cli.read_bytes()).hexdigest()}")
                finally:
                    stop_process(monitor)


if __name__ == "__main__":
    unittest.main()
