#!/usr/bin/env python3
"""Own the broad native test deadline inside the console user's session."""
import os
import signal
import subprocess
import sys
import time


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
        process.terminate()
        process.send_signal(signal.SIGCONT)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

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
    raise SystemExit(main())
