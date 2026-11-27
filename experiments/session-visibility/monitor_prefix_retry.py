#!/usr/bin/env python3
"""Manual isolated monitor probe; binary identity is hash-checked, source is not attested.

Usage: python3 experiments/session-visibility/monitor_prefix_retry.py CLI SHA256 [--control]
No application is launched. Synthetic transcript, PE store, socket, cursor and logs
are private temporary data. Retry is bounded; lack of recovery is not permanent failure.
"""
import hashlib
import json
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time


def main():
    if len(sys.argv) not in (3, 4) or (len(sys.argv) == 4 and sys.argv[3] != "--control"):
        raise SystemExit(__doc__)
    control = len(sys.argv) == 4
    cli = Path(sys.argv[1]).resolve(strict=True)
    digest = hashlib.sha256(cli.read_bytes()).hexdigest()
    if digest != sys.argv[2]:
        raise SystemExit("CLI SHA-256 mismatch")
    with tempfile.TemporaryDirectory(prefix="bmux-prefix-retry-") as temporary:
        root = Path(temporary)
        home = root / "home"
        home.mkdir(mode=0o700)
        transcript, lease, sockpath = root / "transcript", root / "lease", root / "socket"
        session, workspace, surface = "synthetic-session", "11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"
        def line(kind, payload):
            return json.dumps({"timestamp": "2026-11-13T10:00:00Z", "type": kind, "payload": payload}, separators=(",", ":")) + "\n"
        transcript.write_text(line("session_meta", {"id": session, "session_id": session, "cwd": str(root), "originator": "codex-tui", "source": "cli"}) + line("event_msg", {"type": "task_started", "turn_id": "initial"}))
        lease.write_text("{}")
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(sockpath))
        server.listen(2)
        server.settimeout(.2)
        stopped = threading.Event()
        def serve():
            while not stopped.is_set():
                try:
                    connection, _ = server.accept()
                except socket.timeout:
                    continue
                except OSError:
                    return
                with connection:
                    connection.settimeout(.2)
                    buf = b""
                    while not stopped.is_set():
                        try:
                            data = connection.recv(65536)
                        except socket.timeout:
                            continue
                        except OSError:
                            break
                        if not data:
                            break
                        buf += data
                        while b"\n" in buf:
                            row, buf = buf.split(b"\n", 1)
                            try:
                                request = json.loads(row)
                                if request.get("id") is not None:
                                    result = {"surfaces": [{"id": surface}]} if request.get("method") == "surface.list" else {}
                                    connection.sendall((json.dumps({"id": request["id"], "ok": True, "result": result}) + "\n").encode())
                            except (ValueError, AttributeError):
                                connection.sendall(b"OK\n")
        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        env = {"HOME": str(home), "CFFIXED_USER_HOME": str(home), "BMUX_PROVENANCE_HOME": str(home), "BMUX_SOCKET_PATH": str(sockpath), "BMUX_DEBUG_LOG": str(root / "debug.log"), "BMUX_CLI_SENTRY_DISABLED": "1", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TMPDIR": str(root)}
        process = subprocess.Popen([str(cli), "hooks", "codex", "monitor", "--workspace", workspace, "--surface", surface, "--session", session, "--transcript", str(transcript), "--lease", str(lease)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        db = home / ".local/state/provenance-engine/provenance.sqlite"
        cursors = home / ".local/state/bmux/codex-transcript-cursors"
        def wait(predicate, seconds, label):
            deadline = time.monotonic() + seconds
            while time.monotonic() < deadline:
                if predicate():
                    return True
                if process.poll() is not None:
                    raise RuntimeError("monitor exited during " + label)
                time.sleep(.1)
            return False
        try:
            if not wait(lambda: db.exists() and cursors.exists() and any(p.name.endswith(".json") and not p.name.endswith(".status.json") for p in cursors.iterdir()), 15, "initial import"):
                raise RuntimeError("initial import timed out")
            cursor = next(p for p in cursors.iterdir() if p.name.endswith(".json") and not p.name.endswith(".status.json"))
            status = next(p for p in cursors.iterdir() if p.name.endswith(".status.json"))
            before = json.loads(cursor.read_text())["byteOffset"]
            con = sqlite3.connect(db, timeout=5, isolation_level=None)
            try:
                baseline = con.execute("SELECT id, payload_json FROM provenance_events ORDER BY sequence").fetchall()
                if not control:
                    con.execute("CREATE TRIGGER synthetic_reject BEFORE INSERT ON provenance_events WHEN NEW.payload_json LIKE '%rejected-turn%' BEGIN SELECT RAISE(ABORT, 'constraint provenance_events synthetic reject'); END")
                with transcript.open("a") as stream:
                    stream.write(line("event_msg", {"type": "task_started", "turn_id": "prefix-turn"}) + line("event_msg", {"type": "task_started", "turn_id": "rejected-turn"}))
                    stream.flush()
                    os.fsync(stream.fileno())
                wait(lambda: json.loads(status.read_text()).get("appendFailures", 0) > 0 or json.loads(cursor.read_text())["byteOffset"] > before, 15, "import")
                failed = json.loads(status.read_text()).get("appendFailures", 0) > 0
                after_cursor = json.loads(cursor.read_text())["byteOffset"]
                failed_status = json.loads(status.read_text())
                failed_rows = con.execute("SELECT id, payload_json FROM provenance_events ORDER BY sequence").fetchall()
                prefix = [row for row in failed_rows if "prefix-turn" in row[1]]
                rejected = [row for row in failed_rows if "rejected-turn" in row[1]]
                print(json.dumps({"stage": "after_rejection", "failure_reported": failed, "cursor_before": before, "cursor_after": after_cursor, "retrying": failed_status["retrying"], "prefix_count": len(prefix), "rejected_count": len(rejected), "new_events": len(failed_rows) - len(baseline), "monitor_alive": process.poll() is None}), flush=True)
                if control:
                    assert not failed and after_cursor > before and len(prefix) == 1 and len(rejected) == 1
                    print("control passed: both event payloads retained", flush=True)
                    return
                assert len(prefix) == 1 and not rejected and failed_rows[:len(baseline)] == baseline
                # Independent rollback-only positive control: the installed trigger rejects
                # a fresh, nonduplicate event with the same matching payload shape.
                columns = [row[1] for row in con.execute("PRAGMA table_info(provenance_events)")]
                clone = list(con.execute("SELECT * FROM provenance_events WHERE id = ?", (prefix[0][0],)).fetchone())
                clone[columns.index("sequence")] = None
                clone[columns.index("id")] = "synthetic-unique-control"
                clone[columns.index("payload_json")] = clone[columns.index("payload_json")].replace("prefix-turn", "rejected-turn")
                con.execute("SAVEPOINT trigger_control")
                rejected_control = False
                try:
                    con.execute("INSERT INTO provenance_events VALUES (" + ",".join("?" for _ in columns) + ")", clone)
                except sqlite3.IntegrityError as error:
                    rejected_control = "synthetic reject" in str(error)
                finally:
                    con.execute("ROLLBACK TO trigger_control")
                    con.execute("RELEASE trigger_control")
                assert rejected_control, "nonduplicate trigger control did not reject"
                print("independent nonduplicate trigger control rejected", flush=True)
                con.execute("DROP TRIGGER synthetic_reject")
                with transcript.open("a") as stream:
                    stream.write("\n")
                    stream.flush()
                    os.fsync(stream.fileno())
                recovered = wait(lambda: any("rejected-turn" in row[0] for row in con.execute("SELECT payload_json FROM provenance_events")), 35 if failed else 3, "same-process retry")
                final_rows = con.execute("SELECT id, payload_json FROM provenance_events ORDER BY sequence").fetchall()
                prefix_after = [row for row in final_rows if "prefix-turn" in row[1]]
                rejected_after = [row for row in final_rows if "rejected-turn" in row[1]]
                final_status = json.loads(status.read_text())
                print(json.dumps({"sha256": digest, "recovery_observed": recovered, "schema": con.execute("PRAGMA user_version").fetchone()[0], "initial_events": len(baseline), "prefix_count": len(prefix), "cursor_before": before, "cursor_after_failure": after_cursor, "cursor_after_retry": json.loads(cursor.read_text())["byteOffset"], "retrying_after_failure": failed_status["retrying"], "retrying_after_recovery": final_status["retrying"], "same_process": process.poll() is None, "exact_prefix_unchanged": prefix_after == prefix, "rejected_count_after_retry": len(rejected_after)}), flush=True)
                # Proposed invariant: a nonduplicate failure cannot acknowledge the line.
                assert failed and after_cursor == before and failed_status["retrying"], "nonduplicate rejection falsely acknowledged or not reported"
                assert recovered, "same-process recovery not observed within 35 seconds"
                assert prefix_after == prefix and len(rejected_after) == 1
                assert len({row[0] for row in final_rows}) == len(final_rows)
                assert not final_status["retrying"]
            finally:
                con.close()
        finally:
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
            stopped.set()
            server.close()
            thread.join(timeout=2)
            if hashlib.sha256(cli.read_bytes()).hexdigest() != digest:
                raise RuntimeError("CLI SHA-256 changed during probe")


if __name__ == "__main__":
    main()
