#!/usr/bin/env python3
"""Opt-in synthetic candidate-ID characterization, not source identity proof.

Requires BMUX_TEST_CLI and BMUX_TEST_CLI_SHA256; uses private synthetic files.
The importer does not expose line ranges or emission slots. Known fixture ranges
and independently calculated IDs are correlated with stored events; this does
not prove the attempted event, source continuity, or provider behavior.
"""
import hashlib
import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

from codex_same_id_collision_repro import cursor, digest, status_covering, stop, wait_until
from test_codex_feed_hooks import FAKE_SURFACE_ID, FAKE_WORKSPACE_ID, FakeBmuxSocket

SESSION = "11111111-1111-4111-8111-111111111111"


def partial_status(directory, read_offset, cursor_offset):
    for path in directory.glob("*.status.json"):
        try:
            status = json.loads(path.read_text())
            if (type(status.get("readOffset")) is int
                    and status["readOffset"] >= read_offset
                    and status.get("cursorOffset") == cursor_offset
                    and type(status.get("appendFailures")) is int):
                return status
        except (OSError, ValueError, TypeError):
            pass
    return None


def candidate(ordinal, kind):
    value = f"codex-transcript\n{SESSION}\n{ordinal}\n{kind}".encode()
    return "event-" + hashlib.sha256(value).hexdigest()[:24]


def line(kind, payload, ordinal):
    return json.dumps({"timestamp": "2026-11-13T10:00:00Z", "type": kind,
                       "ordinal": ordinal, "payload": payload}, ensure_ascii=False).encode("utf-8")


def command(ordinal, item, message):
    return line("event_msg", {"type": "item_completed", "turn_id": "turn-one",
        "item": {"type": "CommandExecution", "id": item, "command": ["echo", message],
                 "status": "completed", "exit_code": 0}}, ordinal)


class SourceSlotCharacterization(unittest.TestCase):
    def test_chunk_partial_multi_emission_and_resume_candidates(self):
        cli = Path(os.environ["BMUX_TEST_CLI"]).resolve(strict=True)
        expected_hash = os.environ["BMUX_TEST_CLI_SHA256"].lower()
        self.assertEqual(digest(cli), expected_hash)
        self.addCleanup(lambda: self.assertEqual(digest(cli), expected_hash))
        with tempfile.TemporaryDirectory(prefix="bmux-source-slot-", dir="/tmp") as temp:
            root = Path(temp)
            home = root / "home"
            home.mkdir()
            socket = root / "socket"
            source = root / "source.jsonl"
            metadata = line("session_meta", {"id": SESSION, "session_id": SESSION}, 0) + b"\n"
            # CR and leading whitespace are part of the source record. This
            # deliberately crosses the 64 KiB live-read boundary.
            record = b" " * 65536 + command(7, "op-one", "café") + b"\r\n"
            later = command(7, "op-two", "other") + b"\n"
            split = len(record) - 2
            source.write_bytes(metadata + record[:split])
            database = home / ".local/state/provenance-engine/provenance.sqlite"
            cursors = home / ".local/state/bmux/codex-transcript-cursors"
            env = {"HOME": str(home), "CFFIXED_USER_HOME": str(home), "BMUX_PROVENANCE_HOME": str(home),
                "BMUX_SOCKET_PATH": str(socket), "BMUX_DEBUG_LOG": str(root / "debug.log"),
                "BMUX_CLI_SENTRY_DISABLED": "1", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TMPDIR": temp,
                "BMUX_WORKSPACE_ID": FAKE_WORKSPACE_ID, "BMUX_SURFACE_ID": FAKE_SURFACE_ID}
            argv = [str(cli), "--socket", str(socket), "hooks", "codex", "monitor", "--workspace",
                FAKE_WORKSPACE_ID, "--surface", FAKE_SURFACE_ID, "--session", SESSION, "--transcript", str(source)]
            def matching_events():
                with sqlite3.connect(database) as db:
                    return db.execute("SELECT id, payload_json FROM provenance_events WHERE id IN (?, ?, ?)",
                        (candidate(7, "turn-turn-one-observed"), candidate(7, "command-op-one"),
                         candidate(7, "command-op-two"))).fetchall()
            with FakeBmuxSocket(socket, None):
                process = subprocess.Popen(argv, env=env, cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    wait_until(lambda: partial_status(cursors, len(metadata) + split, len(metadata)), process)
                    self.assertEqual(cursor(cursors), len(metadata))
                    self.assertEqual(matching_events(), [])
                    with source.open("ab") as stream:
                        stream.write(record[split:] + later)
                        stream.flush()
                        os.fsync(stream.fileno())
                    final = len(metadata) + len(record) + len(later)
                    wait_until(lambda: status_covering(cursors, final), process)
                    self.assertEqual(cursor(cursors), final)
                    original = matching_events()
                    self.assertEqual({event_id for event_id, _ in original}, {
                        candidate(7, "turn-turn-one-observed"), candidate(7, "command-op-one"),
                        candidate(7, "command-op-two")})
                    payloads = {event_id: json.loads(payload) for event_id, payload in original}
                    self.assertEqual(payloads[candidate(7, "command-op-one")]["codingAgentCommand"]["command"], "echo 'café'")
                    self.assertEqual(payloads[candidate(7, "command-op-two")]["codingAgentCommand"]["command"], "echo other")
                    self.assertIn("codingAgentTurn", payloads[candidate(7, "turn-turn-one-observed")])
                    data = source.read_bytes()
                    self.assertEqual(data[len(metadata):len(metadata) + len(record)], record)
                    self.assertEqual(data[len(metadata) + len(record):final], later)
                    # Candidate identity is insensitive to changed bytes: this is
                    # why matching it cannot prove a replay or association.
                    changed = record.replace("café".encode(), b"cafe")
                    self.assertNotEqual(changed, record)
                    original_ordinal = json.loads(record)["ordinal"]
                    changed_ordinal = json.loads(changed)["ordinal"]
                    self.assertEqual(candidate(original_ordinal, "command-op-one"),
                                     candidate(changed_ordinal, "command-op-one"))
                    stop(process)
                    for status_path in cursors.glob("*.status.json"):
                        status_path.unlink()
                    process = subprocess.Popen(argv, env=env, cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    wait_until(lambda: status_covering(cursors, final), process)
                    self.assertCountEqual(matching_events(), original)
                    # Same ordinal and item ID, different source bytes: observe
                    # cursor and stored candidates without assuming the hidden
                    # append error or disposition.
                    collision = command(7, "op-one", "different") + b"\n"
                    with source.open("ab") as stream:
                        stream.write(collision)
                        stream.flush()
                        os.fsync(stream.fileno())
                    wait_until(lambda: status_covering(cursors, final + len(collision)), process)
                    self.assertEqual(cursor(cursors), final + len(collision))
                    self.assertCountEqual(matching_events(), original)
                    with sqlite3.connect(database) as db:
                        self.assertEqual(db.execute("SELECT count(*) FROM provenance_events WHERE payload_json LIKE '%different%'").fetchone()[0], 0)
                finally:
                    stop(process)


if __name__ == "__main__":
    unittest.main()
