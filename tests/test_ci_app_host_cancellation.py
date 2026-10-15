#!/usr/bin/env python3
"""Exercise real CI cancellation owners; Linux subreaping contains expected reds."""
from __future__ import annotations

import ctypes
import json
import os
from pathlib import Path
import select
import signal
import shlex
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/ci/xcodebuild_noninteractive.py"
WRAPPER = ROOT / "scripts/ci/run-app-host-xcodebuild.sh"


def stub_source() -> str:
    return '''import json, os, pathlib, signal, sys
root = pathlib.Path(os.environ["OWNED_ROOT"])
phase = os.environ["OWNED_PHASE"]
kind = sys.argv[1]
if kind == "xcodebuild":
    counter = root / "attempts"
    attempt = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(attempt))
    if phase == "retry" and attempt == 1:
        print("The test runner hung before establishing connection.", flush=True)
        raise SystemExit(65)
# HUP is not cancellation forwarding: a dying PTY owner must still join us.
signal.signal(signal.SIGHUP, signal.SIG_IGN)
def finish(signum, frame):
    raise SystemExit(0)
for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGUSR1):
    signal.signal(signum, finish)
if phase == "stubborn":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
grandchild = None
if phase == "pty-group":
    read_fd, write_fd = os.pipe()
    grandchild = os.fork()
    if grandchild == 0:
        os.close(read_fd)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        os.write(write_fd, b"ready")
        os.close(write_fd)
        while True:
            signal.pause()
    os.close(write_fd)
    assert os.read(read_fd, 5) == b"ready"
    os.close(read_fd)
with open(root / "ready", "w") as ready:
    ready.write(json.dumps({"pid": os.getpid(), "parent": os.getppid(), "kind": kind, "grandchild": grandchild}) + "\\n")
    ready.flush()
while True:
    signal.pause()
'''


def signal_owned(handle: int, signum: int) -> None:
    try:
        signal.pidfd_send_signal(handle, signum)
    except ProcessLookupError:
        pass  # pidfd identifies the original child even after PID reuse.


def reap_owned_children(proc: subprocess.Popen, owned: dict[int, int], release: set[int]) -> None:
    """Join even expected-red leftovers before the scenario removes its files."""
    for pid in release:
        signal_owned(owned[pid], signal.SIGUSR1)
    if proc.poll() is None:
        proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=2)
    # A released child lets the original helper reap normally. If it cannot,
    # only this dedicated subreaper's actual children receive fallback KILL.
    started = time.monotonic()
    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return
        if pid:
            continue
        elapsed = time.monotonic() - started
        if elapsed >= 3:
            children = Path(f"/proc/self/task/{os.getpid()}/children").read_text().split()
            for child in children:
                # No other waiter exists; an unreaped direct child's PID cannot
                # be reused between this ownership snapshot and the signal.
                try:
                    os.kill(int(child), signal.SIGKILL)
                except ProcessLookupError:
                    pass
        if elapsed >= 6:
            raise TimeoutError("owned cancellation descendants failed to join after KILL")
        select.select([], [], [], 0.01)  # Bounded reaping grace, not readiness.


def become_subreaper() -> None:
    # Only dedicated guard/scenario processes change their child ownership.
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
        raise OSError(ctypes.get_errno(), "cannot establish owned-child subreaper")


def run_scenario(phase: str, signum: int, directory: str) -> None:
    become_subreaper()
    root = Path(directory)
    binary = root / "bin"
    binary.mkdir()
    stub = root / "stub.py"
    stub.write_text(stub_source())
    for name, body in {
        "xcodebuild": f'exec {shlex.quote(sys.executable)} "{stub}" xcodebuild "$@"',
        # Never run the production stale-host broad match in this test.
        "pkill": "exit 0",
        "python3": f'exec {shlex.quote(sys.executable)} "$@"',
    }.items():
        path = binary / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o700)
    os.mkfifo(root / "ready")
    ready = os.open(root / "ready", os.O_RDWR | os.O_NONBLOCK)
    env = {
        "PATH": str(binary) + ":/usr/bin:/bin",
        "HOME": str(root), "TMPDIR": str(root), "RUNNER_TEMP": str(root),
        "OWNED_ROOT": str(root), "OWNED_PHASE": phase,
        "BMUX_APP_HOST_TEST_LOCK_FILE": str(root / "lock"),
        "BMUX_APP_HOST_TEST_LOCK_WAIT_SECONDS": "2",
        "BMUX_APP_HOST_XCODEBUILD_ATTEMPTS": "3",
        "BMUX_XCODEBUILD_NONINTERACTIVE_IDLE_TIMEOUT_SECONDS": "30",
    }
    command = ([sys.executable, str(HELPER), str(binary / "xcodebuild")]
               if phase.startswith("pty") else ["/bin/bash", str(WRAPPER), "owned-test"])
    if phase == "sampler":
        env["BMUX_APP_HOST_PROCESS_DIAGNOSTICS"] = "1"
    if phase == "sampler":
        command += ["-derivedDataPath", str(root / "DerivedData")]
    if phase == "diagnostics-fallback":
        command = [sys.executable, str(ROOT / "scripts/ci/app_host_process_diagnostics.py"),
                   "--root", str(root / "DerivedData"), "--log", str(root / "native.log"),
                   "--output", str(root), "--", str(HELPER), str(binary / "xcodebuild")]
    try:
        proc = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, start_new_session=True)
    except BaseException:
        os.close(ready)
        raise
    owned: dict[int, int] = {}
    release: set[int] = set()
    failure = None
    try:
        deadline = time.monotonic() + 5
        data = b""
        while b"\n" not in data:
            remaining = deadline - time.monotonic()
            assert remaining > 0 and select.select([ready], [], [], remaining)[0], "owned child never ready"
            data += os.read(ready, 4096)
        record = json.loads(data.splitlines()[0])
        owned[record["pid"]] = os.pidfd_open(record["pid"])
        release.add(record["pid"])
        if record["grandchild"]:
            owned[record["grandchild"]] = os.pidfd_open(record["grandchild"])
            release.add(record["grandchild"])
        # PTY helper is the ready stub's parent.
        owned[record["parent"]] = os.pidfd_open(record["parent"])
        proc.send_signal(signum)
        status = proc.wait(timeout=5 if phase == "stubborn" else 8)
        # Stubborn cancellation must finish before the existing outer KILL at 5s.
        leftovers = [pid for pid, handle in owned.items() if not select.select([handle], [], [], 0)[0]]
        assert not leftovers, f"{phase}: cancellation returned with owned descendants alive: {leftovers}"
        # An exited leader adopted by this supervisor was NOT waitpid-joined
        # by its owner. Grandchildren are different: we reap those below.
        try:
            adopted = os.waitid(os.P_PIDFD, owned[record["pid"]],
                                os.WEXITED | os.WNOHANG | os.WNOWAIT)
        except ChildProcessError:
            adopted = None
        assert adopted is None, "PTY leader exited but was not joined by its helper"
        assert status == 128 + signum, f"{phase}: expected cancellation {128 + signum}, got {status}"
        output = proc.communicate(timeout=1)[0]
        assert b"Retrying" not in output or phase == "retry", "cancellation retried native execution"
        expected_attempts = 2 if phase == "retry" else 1
        assert int((root / "attempts").read_text()) == expected_attempts
    except (AssertionError, subprocess.TimeoutExpired) as error:
        failure = error
    finally:
        os.close(ready)
        reap_owned_children(proc, owned, release)
        try:
            output = proc.communicate(timeout=2)[0]  # EOF after descendants reaped.
            if failure:
                print(output.decode(errors="replace"))
        finally:
            for handle in owned.values():
                os.close(handle)
    if failure:
        raise failure


def main() -> int:
    if sys.platform != "linux":
        print("SKIP: cancellation guard requires Linux owned-child subreaping")
        return 0
    if len(sys.argv) == 5 and sys.argv[1] == "--scenario":
        run_scenario(sys.argv[2], int(sys.argv[3]), sys.argv[4])
        return 0
    become_subreaper()
    failures = []
    scenarios = [(phase, signum) for phase in ("pty", "pty-group", "wrapper", "retry")
                 for signum in (signal.SIGTERM, signal.SIGINT)]
    scenarios += [("sampler", signal.SIGTERM), ("stubborn", signal.SIGTERM),
                  ("diagnostics-fallback", signal.SIGTERM)]
    for phase, signum in scenarios:
        # Parent owns the directory even if the scenario itself must be killed.
        with tempfile.TemporaryDirectory(prefix="bmux-cancel-guard-") as directory:
            proc = subprocess.Popen([sys.executable, __file__, "--scenario", phase, str(int(signum)), directory],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            failure = None
            try:
                output, _ = proc.communicate(timeout=25)
                children = Path(f"/proc/self/task/{os.getpid()}/children").read_text().split()
                if children:
                    failure = "scenario returned with adopted descendants"
            except subprocess.TimeoutExpired:
                failure = "scenario exceeded its outer guard deadline"
            finally:
                reap_owned_children(proc, {}, set())
                output, _ = proc.communicate(timeout=2)
            status = proc.returncode
        assert not Path(directory).exists()
        print("owned_cleanup: joined=true root_removed=true", flush=True)
        print(f"{phase}/{signal.Signals(signum).name}: {'PASS' if status == 0 and not failure else 'FAIL'}", flush=True)
        if status or failure:
            failures.append(phase)
            print(f"{failure}\n{output}" if failure else output, flush=True)
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
