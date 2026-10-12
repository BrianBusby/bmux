#!/usr/bin/env python3
"""Behavioral guard for the CI xcodebuild prompt wrapper."""

from __future__ import annotations

import subprocess
import sys
import textwrap
import os
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "ci" / "xcodebuild_noninteractive.py"
PROMPT = "Press space to interact, D to debug, or any other key to quit"


def check_test_progress_watchdog() -> None:
    # The real app-host output runs Swift Testing after Selected tests finishes.
    # The child workload includes a silent test longer than the cleanup deadline;
    # execution belongs to the existing general idle watchdog until run completion.
    env = {
        **os.environ,
        "BMUX_XCODEBUILD_NONINTERACTIVE_IDLE_TIMEOUT_SECONDS": "3",
        "BMUX_XCODEBUILD_NONINTERACTIVE_POST_TEST_TIMEOUT_SECONDS": "0.4",
    }
    for status in [0, 65]:
        child = textwrap.dedent(f"""
            import os, sys, time
            print("Test Suite 'Selected tests' passed at now", flush=True)
            start = "◇ Test run started.\\n".encode()
            os.write(1, start[:1])
            time.sleep(0.02)
            os.write(1, start[1:])
            time.sleep(0.6)
            for index in range(10):
                print(f"◇ Test case passing 1 argument value → {{index}} to example(value:) started.", flush=True)
                time.sleep(0.08)
                print(f"✔ Test example(value:) passed after 0.08 seconds.", flush=True)
            # Real PTY reads may split a lifecycle line, including UTF-8 glyphs.
            summary = "{'✔' if status == 0 else '✘'} Test run with 10 tests{' in 1 suite' if status == 0 else ''} {'passed' if status == 0 else 'failed'} after 0.8 seconds.\\n".encode()
            os.write(1, summary[:1])
            time.sleep(0.02)
            os.write(1, summary[1:19])
            time.sleep(0.02)
            os.write(1, summary[19:])
            raise SystemExit({status})
        """)
        result = subprocess.run(
            [sys.executable, str(HELPER), sys.executable, "-c", child],
            cwd=ROOT, text=True, capture_output=True, timeout=5, env=env,
        )
        assert result.returncode == status, (
            f"Active Swift Testing must reach native exit {status}, got {result.returncode}\n"
            + result.stdout + result.stderr
        )
        assert "Test run with 10 tests" in result.stdout

    # xcodebuild may restart an XCTest host after an unexpected exit. Its active
    # work must not inherit the previous host's cleanup deadline either.
    child = textwrap.dedent("""
        import time
        print("Test Suite 'Selected tests' failed at previous", flush=True)
        print("Test Suite 'Selected tests' started at restarted", flush=True)
        time.sleep(0.6)
        print("Test Suite 'Selected tests' passed at finished", flush=True)
        raise SystemExit(65)
    """)
    result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", child],
        cwd=ROOT, text=True, capture_output=True, timeout=5, env=env,
    )
    assert result.returncode == 65, result.stdout + result.stderr

    # Later passed summaries must not erase a prior failure, including restarts.
    # A completed run marker followed by chatter must not be repeatedly rediscovered
    # in the rolling buffer and keep stalled cleanup alive.
    for failed_summary in [False, True]:
        child = textwrap.dedent(f"""
            import os, time
            print("Test Suite 'Selected tests' {'failed' if failed_summary else 'passed'} at now", flush=True)
            print("Test Suite 'Selected tests' started at later", flush=True)
            print("Test Suite 'Selected tests' passed at later", flush=True)
            print("◇ Test run started.", flush=True)
            summary = "✔ Test run with 1 test passed after 0.01 seconds.\\n".encode()
            os.write(1, summary[:1])
            time.sleep(0.02)
            os.write(1, summary[1:])
            for _ in range(40):
                print("unrelated app diagnostic", flush=True)
                time.sleep(0.05)
            print("cleanup-child-finished", flush=True)
        """)
        result = subprocess.run(
            [sys.executable, str(HELPER), sys.executable, "-c", child],
            cwd=ROOT, text=True, capture_output=True, timeout=5, env=env,
        )
        expected = 125 if failed_summary else 124
        assert result.returncode == expected, result.stdout + result.stderr
        assert "cleanup-child-finished" not in result.stdout, "Cleanup must terminate despite app noise"

    # Active Swift Testing retains the existing general output-idle deadline.
    child = (
        "import time\n"
        "print(\"Test Suite 'Selected tests' passed at now\", flush=True)\n"
        "print('◇ Test run started.', flush=True)\n"
        "time.sleep(10)\n"
    )
    result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", child],
        cwd=ROOT, text=True, capture_output=True, timeout=5,
        env={**env, "BMUX_XCODEBUILD_NONINTERACTIVE_IDLE_TIMEOUT_SECONDS": "0.6"},
    )
    assert result.returncode == 124, result.stdout + result.stderr
    assert "Idle timed out after 0.6s" in result.stderr, result.stderr



def main() -> int:
    child = textwrap.dedent(
        f"""
        import sys
        import termios
        import tty

        prompt = {PROMPT!r}
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        tty.setraw(fd)
        try:
            for _ in range(2):
                print(prompt, flush=True)
                ch = sys.stdin.read(1)
                print('received=' + ch, flush=True)
                termios.tcflush(fd, termios.TCIFLUSH)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        raise SystemExit(7)
        """
    )
    result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", child],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )

    if result.returncode != 7:
        print(result.stdout, end="")
        print(result.stderr, end="", file=sys.stderr)
        print(f"FAIL: expected wrapped command exit 7, got {result.returncode}")
        return 1
    if result.stdout.count("received=q") != 2:
        print(result.stdout, end="")
        print("FAIL: helper did not answer each crash prompt with q")
        return 1

    timeout_child = textwrap.dedent(
        """
        import time

        print("ready", flush=True)
        time.sleep(10)
        """
    )
    timeout_env = {
        **os.environ,
        "BMUX_XCODEBUILD_NONINTERACTIVE_IDLE_TIMEOUT_SECONDS": "0.2",
    }
    timeout_result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", timeout_child],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        timeout=5,
        env=timeout_env,
    )
    if timeout_result.returncode != 124:
        print(timeout_result.stdout, end="")
        print(timeout_result.stderr, end="", file=sys.stderr)
        print(f"FAIL: expected timeout exit 124, got {timeout_result.returncode}")
        return 1
    if "Idle timed out after 0.2s" not in timeout_result.stderr:
        print(timeout_result.stdout, end="")
        print(timeout_result.stderr, end="", file=sys.stderr)
        print("FAIL: helper did not report idle timeout")
        return 1

    post_test_env = {
        **os.environ,
        "BMUX_XCODEBUILD_NONINTERACTIVE_POST_TEST_TIMEOUT_SECONDS": "0.2",
    }
    passing_post_test_child = textwrap.dedent(
        """
        import time

        print("Test Suite 'Selected tests' passed at now", flush=True)
        print("\\t Executed 1 test, with 0 failures (0 unexpected) in 0.001 seconds", flush=True)
        time.sleep(10)
        """
    )
    passing_post_test_result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", passing_post_test_child],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        timeout=5,
        env=post_test_env,
    )
    if passing_post_test_result.returncode != 124:
        print(passing_post_test_result.stdout, end="")
        print(passing_post_test_result.stderr, end="", file=sys.stderr)
        print(
            "FAIL: expected post-test timeout after partial Selected tests summary to exit 124, "
            f"got {passing_post_test_result.returncode}"
        )
        return 1

    noisy_post_test_child = textwrap.dedent(
        """
        import time

        print("Test Suite 'Selected tests' passed at now", flush=True)
        print("\\t Executed 1 test, with 0 failures (0 unexpected) in 0.001 seconds", flush=True)
        for _ in range(20):
            print("post-summary-noise", flush=True)
            time.sleep(0.1)
        """
    )
    noisy_started = time.monotonic()
    noisy_post_test_result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", noisy_post_test_child],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        timeout=5,
        env=post_test_env,
    )
    noisy_elapsed = time.monotonic() - noisy_started
    if noisy_post_test_result.returncode != 124:
        print(noisy_post_test_result.stdout, end="")
        print(noisy_post_test_result.stderr, end="", file=sys.stderr)
        print(
            "FAIL: expected noisy post-test timeout after passing Selected tests summary "
            f"to exit 124, got {noisy_post_test_result.returncode}"
        )
        return 1
    if noisy_elapsed > 1.5:
        print(noisy_post_test_result.stdout, end="")
        print(noisy_post_test_result.stderr, end="", file=sys.stderr)
        print(f"FAIL: noisy post-test timeout was rearmed; elapsed {noisy_elapsed:.2f}s")
        return 1

    # An early XCTest summary may precede Swift Testing. Neither that summary
    # nor a printed success marker replaces the native process exit status.
    for trailing_output in ["Swift Testing recorded an issue", "** TEST SUCCEEDED **"]:
        child = (
            "import time\n"
            "print(\"Test Suite 'Selected tests' passed at now\", flush=True)\n"
            f"print({trailing_output!r}, flush=True)\n"
            "time.sleep(10)\n"
        )
        result = subprocess.run(
            [sys.executable, str(HELPER), sys.executable, "-c", child],
            cwd=ROOT, text=True, capture_output=True, timeout=5, env=post_test_env,
        )
        if result.returncode != 124:
            print(result.stdout, end="")
            print(f"FAIL: expected incomplete native run to exit 124, got {result.returncode}")
            return 1

    failing_post_test_child = textwrap.dedent(
        """
        import time

        print("Test Suite 'Selected tests' failed at now", flush=True)
        print("\\t Executed 1 test, with 1 failure (1 unexpected) in 0.001 seconds", flush=True)
        time.sleep(10)
        """
    )
    failing_post_test_result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", failing_post_test_child],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        timeout=5,
        env=post_test_env,
    )
    if failing_post_test_result.returncode != 125:
        print(failing_post_test_result.stdout, end="")
        print(failing_post_test_result.stderr, end="", file=sys.stderr)
        print(
            "FAIL: expected post-test timeout after failed Selected tests summary to exit 125, "
            f"got {failing_post_test_result.returncode}"
        )
        return 1

    direct_output_child = "import sys; sys.stdout.write('x' * 262144); sys.stdout.flush()"
    direct_output_result = subprocess.run(
        [sys.executable, str(HELPER), sys.executable, "-c", direct_output_child],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        timeout=5,
    )
    if direct_output_result.returncode != 0:
        print(direct_output_result.stdout, end="")
        print(direct_output_result.stderr, end="", file=sys.stderr)
        print(f"FAIL: expected direct output child exit 0, got {direct_output_result.returncode}")
        return 1
    if direct_output_result.stdout.count("x") != 262144:
        print(direct_output_result.stderr, end="", file=sys.stderr)
        print(
            f"FAIL: direct helper output was truncated to {direct_output_result.stdout.count('x')} bytes"
        )
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        log_path = Path(tmp) / "helper.log"
        log_child = "print('child-log-line', flush=True)"
        log_result = subprocess.run(
            [sys.executable, str(HELPER), sys.executable, "-c", log_child],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
            env={
                **os.environ,
                "BMUX_XCODEBUILD_NONINTERACTIVE_LOG_PATH": str(log_path),
            },
        )
        if log_result.returncode != 0:
            print(log_result.stdout, end="")
            print(log_result.stderr, end="", file=sys.stderr)
            print(f"FAIL: expected log child exit 0, got {log_result.returncode}")
            return 1
        if "child-log-line" not in log_path.read_text():
            print(log_result.stdout, end="")
            print(log_result.stderr, end="", file=sys.stderr)
            print("FAIL: helper did not write child output to log path")
            return 1

    check_test_progress_watchdog()

    print("PASS: xcodebuild noninteractive helper dismisses crash prompts and idle-times out stuck children")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
