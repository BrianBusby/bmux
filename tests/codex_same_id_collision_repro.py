#!/usr/bin/env python3
"""Private, opt-in synthetic characterization; not a provider-behavior claim.

Expected-red collision requires fail-closed behavior because today's public
contract cannot express a durably retained, explicitly unresolved conflict.
A future equivalent contract may safely permit cursor advancement. The tests
require an explicitly selected hash-checked CLI; binary/source is not attested.
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


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def row(kind, payload, ordinal):
    return json.dumps({"timestamp": "2026-11-13T10:00:00Z", "type": kind,
                       "ordinal": ordinal, "payload": payload}, sort_keys=True) + "\n"


def command(ordinal, operation, text):
    return row("event_msg", {"type": "item_completed", "thread_id": SESSION,
        "turn_id": "turn-one", "item": {"type": "CommandExecution", "id": operation,
        "command": ["echo", text], "status": "completed", "exit_code": 0}}, ordinal)


def cursor(directory):
    for path in directory.glob("*.json"):
        if not path.name.endswith(".status.json"):
            try:
                return json.loads(path.read_text())["byteOffset"]
            except (OSError, ValueError, KeyError):
                pass
    return 0


def append_failures(directory):
    for path in directory.glob("*.status.json"):
        try:
            return int(json.loads(path.read_text()).get("appendFailures", 0))
        except (OSError, ValueError, TypeError):
            pass
    return 0


def wait_until(predicate, process):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        if process.poll() is not None:
            raise AssertionError(f"monitor exited {process.returncode}")
        time.sleep(0.05)
    raise AssertionError("monitor did not produce a bounded observation")


def stop(process):
    if process.poll() is None:
        process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


class SyntheticSourceCollision(unittest.TestCase):
    def run_case(self, mode):
        cli = Path(os.environ["BMUX_TEST_CLI"]).resolve(strict=True)
        expected = os.environ["BMUX_TEST_CLI_SHA256"].lower()
        self.assertEqual(digest(cli), expected)
        self.addCleanup(lambda: self.assertEqual(digest(cli), expected))
        with tempfile.TemporaryDirectory(prefix="bmux-source-collision-", dir="/tmp") as temp:
            root = Path(temp)
            home = root / "home"
            home.mkdir()
            socket = root / "socket"
            source = root / "source.jsonl"
            initial = (row("session_meta", {"id": SESSION, "session_id": SESSION}, 0)
                + row("event_msg", {"type": "task_started", "turn_id": "turn-one"}, 1)
                + command(2, "operation-one", "fixture-first"))
            source.write_text(initial, encoding="utf-8")
            database = home / ".local/state/provenance-engine/provenance.sqlite"
            cursors = home / ".local/state/bmux/codex-transcript-cursors"
            env = {"HOME": str(home), "CFFIXED_USER_HOME": str(home), "BMUX_PROVENANCE_HOME": str(home),
                "BMUX_SOCKET_PATH": str(socket), "BMUX_DEBUG_LOG": str(root / "debug.log"),
                "BMUX_CLI_SENTRY_DISABLED": "1", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TMPDIR": temp,
                "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID}
            argv = [str(cli), "--socket", str(socket), "hooks", "codex", "monitor", "--workspace",
                FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID, "--session", SESSION, "--transcript", str(source)]
            with FakeBmuxSocket(socket, None):
                process = subprocess.Popen(argv, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    offset = wait_until(lambda: cursor(cursors) if cursor(cursors) == len(initial.encode()) else 0, process)
                    with sqlite3.connect(database) as db:
                        first = db.execute("SELECT id, command_text FROM provenance_coding_agent_commands WHERE session_id=?", (SESSION,)).fetchall()
                        self.assertEqual(len(first), 1)
                        self.assertIn("fixture-first", first[0][1])
                        event_rows = db.execute("SELECT id, payload_json FROM provenance_events WHERE payload_json LIKE '%fixture-first%'").fetchall()
                        self.assertEqual(len(event_rows), 1)
                    if mode == "replay":
                        stop(process)
                        for path in cursors.glob("*.json"):
                            path.unlink()
                        process = subprocess.Popen(argv, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        wait_until(lambda: cursor(cursors) == offset, process)
                    else:
                        ordinal = 3 if mode == "distinct-ordinal" else 2
                        operation = "operation-two" if mode == "distinct-item" else "operation-one"
                        later = command(ordinal, operation, "fixture-second")
                        failures = append_failures(cursors)
                        with source.open("a", encoding="utf-8") as stream:
                            stream.write(later)
                            stream.flush()
                            os.fsync(stream.fileno())
                        wait_until(lambda: cursor(cursors) > offset or append_failures(cursors) > failures, process)
                    with sqlite3.connect(database) as db:
                        commands = db.execute("SELECT id, command_text FROM provenance_coding_agent_commands WHERE session_id=? ORDER BY id", (SESSION,)).fetchall()
                        events = db.execute("SELECT id, payload_json FROM provenance_events WHERE payload_json LIKE '%fixture-first%' OR payload_json LIKE '%fixture-second%'").fetchall()
                    self.assertEqual(sum("fixture-first" in payload for _, payload in events), 1)
                    if mode == "replay":
                        self.assertEqual(len(commands), 1)
                        self.assertEqual(len(events), 1)
                    elif mode.startswith("distinct-"):
                        self.assertEqual(len(commands), 2)
                        self.assertEqual(len(events), 2)
                        self.assertEqual(len({event_id for event_id, _ in events}), 2)
                        self.assertTrue(any("fixture-second" in value for _, value in commands))
                    else:
                        second_present = any("fixture-second" in payload for _, payload in events)
                        print(f"synthetic collision cursor={offset}->{cursor(cursors)} "
                              f"second_event_present={int(second_present)} append_failures={append_failures(cursors)}")
                        # Proposed fail-closed fallback, not a demand that an
                        # explicit durable unresolved-conflict result stall.
                        self.assertEqual(cursor(cursors), offset,
                            "different source observation advanced without a visible conflict")
                        self.assertGreater(append_failures(cursors), failures)
                finally:
                    stop(process)

    def test_matching_source_restart_control(self):
        self.run_case("replay")

    def test_distinct_ordinal_control(self):
        self.run_case("distinct-ordinal")

    def test_distinct_item_control(self):
        self.run_case("distinct-item")

    def test_proposed_collision_must_not_be_clean_duplicate(self):
        self.run_case("collision")


if __name__ == "__main__":
    unittest.main()
