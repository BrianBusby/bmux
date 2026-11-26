#!/usr/bin/env python3
"""Non-discovery real-CLI synthetic regression; source/binary not attested.

A trigger rejects a fresh ledger event with a constraint message mentioning
provenance_events. Such a failure must not be counted as an idempotent duplicate
or advance the cursor. Uses private fake socket, home, transcript and database.
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
    with path.open("rb") as f:
        for data in iter(lambda: f.read(1024 * 1024), b""):
            h.update(data)
    return h.hexdigest()


def row(kind, payload):
    return json.dumps({"timestamp": "2026-11-13T10:00:00Z", "type": kind, "payload": payload}) + "\n"


def cursor(directory):
    for path in directory.glob("*.json"):
        if not path.name.endswith(".status.json"):
            try:
                return json.loads(path.read_text())["byteOffset"]
            except (OSError, ValueError, KeyError):
                pass
    return 0


def status(directory):
    for path in directory.glob("*.status.json"):
        try:
            return json.loads(path.read_text())
        except (OSError, ValueError):
            pass
    return {}


def wait_until(predicate, process):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
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


class ConstraintDuplicateRepro(unittest.TestCase):
    def test_fresh_constraint_failure_must_not_advance_cursor(self):
        cli = Path(os.environ["BMUX_TEST_CLI"]).resolve(strict=True)
        expected = os.environ["BMUX_TEST_CLI_SHA256"].lower()
        self.assertEqual(digest(cli), expected)
        self.addCleanup(lambda: self.assertEqual(digest(cli), expected))
        with tempfile.TemporaryDirectory(prefix="bmux-constraint-repro-", dir="/tmp") as temp:
            root = Path(temp)
            home = root / "home"
            home.mkdir()
            socket = root / "socket"
            source = root / "source.jsonl"
            source.write_text(row("session_meta", {"id": SESSION, "session_id": SESSION}) +
                              row("event_msg", {"type": "task_started", "turn_id": "turn-one"}))
            database = home / ".local/state/provenance-engine/provenance.sqlite"
            cursors = home / ".local/state/bmux/codex-transcript-cursors"
            env = {"HOME": str(home), "CFFIXED_USER_HOME": str(home), "BMUX_PROVENANCE_HOME": str(home),
                   "BMUX_SOCKET_PATH": str(socket), "BMUX_DEBUG_LOG": str(root / "debug.log"),
                   "BMUX_CLI_SENTRY_DISABLED": "1", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TMPDIR": temp,
                   "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID}
            with FakeBmuxSocket(socket, None):
                process = subprocess.Popen([str(cli), "--socket", str(socket), "hooks", "codex", "monitor",
                    "--workspace", FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID,
                    "--session", SESSION, "--transcript", str(source)], env=env,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    initial = wait_until(lambda: cursor(cursors), process)
                    with sqlite3.connect(database) as db:
                        self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 31)
                        before = db.execute("SELECT COUNT(*) FROM provenance_events").fetchone()[0]
                        db.execute("""CREATE TRIGGER synthetic_refusal BEFORE INSERT ON provenance_events
                            BEGIN SELECT RAISE(ABORT, 'CHECK constraint failed: provenance_events.synthetic_refusal'); END""")
                    failures = status(cursors).get("appendFailures", 0)
                    with source.open("a", encoding="utf-8") as f:
                        f.write(row("event_msg", {"type": "task_started", "turn_id": "turn-two"}))
                        f.flush()
                        os.fsync(f.fileno())
                    observed = wait_until(lambda: cursor(cursors) > initial or
                                          status(cursors).get("appendFailures", 0) > failures, process)
                    self.assertTrue(observed)
                    with sqlite3.connect(database) as db:
                        self.assertEqual(db.execute("SELECT COUNT(*) FROM provenance_events").fetchone()[0], before)
                        self.assertEqual(db.execute("SELECT COUNT(*) FROM provenance_coding_agent_turns WHERE provider_turn_id='turn-two'").fetchone()[0], 0)
                    print(f"cursor={initial}->{cursor(cursors)} append_failures={status(cursors).get('appendFailures')} fresh_event_absent=1")
                    self.assertEqual(cursor(cursors), initial, "fresh rejected event was treated as a duplicate")
                    self.assertGreater(status(cursors).get("appendFailures", 0), failures)
                finally:
                    stop(process)
        self.assertEqual(digest(cli), expected)

    def test_fail_closed_duplicate_prefix_characterizes_replay_stall(self):
        self.run_duplicate_prefix(fail_closed=False)
        self.run_duplicate_prefix(fail_closed=True)

    def run_duplicate_prefix(self, *, fail_closed):
        cli = Path(os.environ["BMUX_TEST_CLI"]).resolve(strict=True)
        expected = os.environ["BMUX_TEST_CLI_SHA256"].lower()
        self.assertEqual(digest(cli), expected)
        self.addCleanup(lambda: self.assertEqual(digest(cli), expected))
        with tempfile.TemporaryDirectory(prefix="bmux-replay-duplicate-", dir="/tmp") as temp:
            root = Path(temp)
            home = root / "home"
            home.mkdir()
            socket = root / "socket"
            source = root / "source.jsonl"
            source.write_text(row("session_meta", {"id": SESSION, "session_id": SESSION}) +
                              row("event_msg", {"type": "task_started", "turn_id": "turn-one"}))
            database = home / ".local/state/provenance-engine/provenance.sqlite"
            cursors = home / ".local/state/bmux/codex-transcript-cursors"
            env = {"HOME": str(home), "CFFIXED_USER_HOME": str(home), "BMUX_PROVENANCE_HOME": str(home),
                   "BMUX_SOCKET_PATH": str(socket), "BMUX_DEBUG_LOG": str(root / "debug.log"),
                   "BMUX_CLI_SENTRY_DISABLED": "1", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TMPDIR": temp,
                   "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID}
            command = [str(cli), "--socket", str(socket), "hooks", "codex", "monitor",
                       "--workspace", FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID,
                       "--session", SESSION, "--transcript", str(source)]
            with FakeBmuxSocket(socket, None):
                first = subprocess.Popen(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    initial = wait_until(lambda: cursor(cursors), first)
                finally:
                    stop(first)
                # Simulate a restart without its operational cursor and a pending line.
                for path in cursors.glob("*.json"):
                    path.unlink()
                with source.open("a", encoding="utf-8") as f:
                    f.write(row("event_msg", {"type": "task_started", "turn_id": "turn-two"}))
                    f.flush()
                    os.fsync(f.fileno())
                with sqlite3.connect(database) as db:
                    before = db.execute("SELECT COUNT(*) FROM provenance_events").fetchone()[0]
                    # Model treating an existing ID without equality proof as failure.
                    # This trigger is synthetic and is not a proposed shipping fix.
                    if fail_closed:
                        db.execute("""CREATE TRIGGER synthetic_fail_closed BEFORE INSERT ON provenance_events
                            WHEN EXISTS (SELECT 1 FROM provenance_events WHERE id=NEW.id)
                            BEGIN SELECT RAISE(ABORT, 'unverified duplicate'); END""")
                second = subprocess.Popen(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    if not fail_closed:
                        recovered = wait_until(lambda: (offset if (offset := cursor(cursors)) > initial else 0), second)
                        with sqlite3.connect(database) as db:
                            self.assertEqual(db.execute("SELECT COUNT(*) FROM provenance_coding_agent_turns WHERE provider_turn_id='turn-two'").fetchone()[0], 1)
                        print(f"normal_duplicate_prefix_cursor={recovered} later_turn_present=1")
                    else:
                        wait_until(lambda: status(cursors).get("appendFailures", 0) > 0, second)
                        self.assertEqual(cursor(cursors), 0)
                        self.assertTrue(status(cursors).get("retrying"))
                        diagnostics = subprocess.run(
                            [str(cli), "--json", "provenance", "diagnostics", "codex-transcript", SESSION],
                            env=env, capture_output=True, text=True, timeout=10, check=True
                        )
                        diagnostic = json.loads(diagnostics.stdout)
                        self.assertTrue(diagnostic["needs_attention"])
                        self.assertTrue(diagnostic["retrying"])
                        with sqlite3.connect(database) as db:
                            self.assertEqual(db.execute("SELECT COUNT(*) FROM provenance_events").fetchone()[0], before)
                            self.assertEqual(db.execute("SELECT COUNT(*) FROM provenance_coding_agent_turns WHERE provider_turn_id='turn-two'").fetchone()[0], 0)
                        print(f"unverified_prefix_first_cursor={initial} replay_cursor=0 later_turn_absent=1 status_error={status(cursors).get('lastErrorKind')}")
                finally:
                    stop(second)


if __name__ == "__main__":
    unittest.main()
