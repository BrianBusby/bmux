#!/usr/bin/env python3
"""Own the broad native test deadline inside the console user's session."""
import json
import os
import signal
import subprocess
import sys
import time


def record_lifecycle(phase, **numbers):
    # Existing GitHub step logs own these bounded numeric diagnostics; never log argv or environment.
    record = dict(event="native_test_deadline_lifecycle", phase=phase, owner_pid=os.getpid(), **numbers)
    try:
        os.write(2, (json.dumps(record, separators=(",", ":")) + "\n").encode())
    except OSError:
        pass  # A closed diagnostic channel must not replace the authoritative native result.


def main():
    if len(sys.argv) < 2:
        print('usage: run-unit-tests-with-timeout.py <command> [args...]', file=sys.stderr)
        return 2
    try:
        timeout = int(os.environ.get('BMUX_UNIT_TEST_TIMEOUT_SECONDS') or '900')
    except ValueError:
        print('BMUX_UNIT_TEST_TIMEOUT_SECONDS must be an integer', file=sys.stderr)
        return 2

    cancelled = 0

    def receive(signum, frame):
        nonlocal cancelled
        if not cancelled:
            cancelled = signum

    previous = {sig: signal.signal(sig, receive) for sig in (signal.SIGTERM, signal.SIGINT)}
    process = None

    def join_after_termination():
        # The app-host wrapper owns its subtree. Popen checks/reaps only this
        # direct child before signaling; no recycled PID or process scan is used.
        record_lifecycle("termination_requested", child_pid=process.pid)
        process.terminate()
        process.send_signal(signal.SIGCONT)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            record_lifecycle("termination_grace_expired", child_pid=process.pid)
            process.kill()
            record_lifecycle("kill_sent", child_pid=process.pid)
            process.wait()
        record_lifecycle("child_joined", child_pid=process.pid, exit_code=process.returncode)

    try:
        if cancelled:
            return 128 + cancelled
        process = subprocess.Popen(sys.argv[1:], stdin=subprocess.DEVNULL)
        deadline = time.monotonic() + timeout
        while process.poll() is None:
            if cancelled or time.monotonic() >= deadline:
                if not cancelled:
                    print(f'xcodebuild unit test timeout after {timeout}s; terminating', flush=True)
                join_after_termination()
                return 128 + cancelled if cancelled else 124
            try:
                process.wait(timeout=min(0.1, max(0, deadline - time.monotonic())))
            except subprocess.TimeoutExpired:
                pass  # Genuine deadline/cancellation observation, never a retry.
        if cancelled:
            return 128 + cancelled
        return process.returncode if process.returncode >= 0 else 128 - process.returncode
    finally:
        try:
            if process is not None and process.poll() is None:
                join_after_termination()
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)


if __name__ == '__main__':
    exit_code = None
    try:
        exit_code = main()
    finally:
        record_lifecycle("owner_exit", exit_code=exit_code)
    raise SystemExit(exit_code)
