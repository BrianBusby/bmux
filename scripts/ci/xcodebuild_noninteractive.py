#!/usr/bin/env python3
"""Run xcodebuild under a PTY and dismiss Swift crash prompts in CI."""

from __future__ import annotations

import os
import pty
import re
import select
import signal
import sys
import time
from typing import BinaryIO


SWIFT_CRASH_PROMPT = b"Press space to interact, D to debug, or any other key to quit"
TIMEOUT_EXIT_CODE = 124
POST_TEST_FAILED_EXIT_CODE = 125
SELECTED_TESTS_DONE_RE = re.compile(rb"Test Suite 'Selected tests' (passed|failed) at ")
ANSI_SGR_RE = re.compile(rb"\x1b\[[0-9;:]*m")
SELECTED_TESTS_STARTED = b"Test Suite 'Selected tests' started at "
SWIFT_TESTING_STARTED = "◇ Test run started.".encode()
SWIFT_TESTING_DONE_RE = re.compile(
    r"[✔✘] Test run with \d+ tests?(?: in \d+ suites?)? (?:passed|failed)\b".encode()
)


def child_exit_code(status: int) -> int:
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 1


def idle_timeout_seconds() -> float | None:
    raw = os.environ.get("BMUX_XCODEBUILD_NONINTERACTIVE_IDLE_TIMEOUT_SECONDS")
    if raw is None:
        raw = os.environ.get("BMUX_XCODEBUILD_NONINTERACTIVE_TIMEOUT_SECONDS")
    if not raw:
        return None
    try:
        seconds = float(raw)
    except ValueError:
        print(
            "BMUX_XCODEBUILD_NONINTERACTIVE_IDLE_TIMEOUT_SECONDS must be numeric",
            file=sys.stderr,
        )
        raise SystemExit(2)
    if seconds <= 0:
        return None
    return seconds


def post_test_timeout_seconds() -> float | None:
    raw = os.environ.get("BMUX_XCODEBUILD_NONINTERACTIVE_POST_TEST_TIMEOUT_SECONDS")
    if not raw:
        return None
    try:
        seconds = float(raw)
    except ValueError:
        print(
            "BMUX_XCODEBUILD_NONINTERACTIVE_POST_TEST_TIMEOUT_SECONDS must be numeric",
            file=sys.stderr,
        )
        raise SystemExit(2)
    if seconds <= 0:
        return None
    return seconds


def terminate_child(pid: int, wake_fd: int, cancellation: list) -> None:
    # Keep the leader unreaped until the final group signal: its PID anchors the
    # owned process-group identity even if TERM exits the leader before workers.
    def send(sig: int) -> None:
        try:
            os.killpg(pid, sig)
        except (ProcessLookupError, PermissionError):
            try:
                # Darwin reports EPERM for a group containing only a zombie;
                # the unreaped child also covers the pre-setsid startup boundary.
                os.kill(pid, sig)
            except ProcessLookupError:
                pass

    send(signal.SIGTERM)
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if cancellation[0]:
            deadline = min(deadline, cancellation[1] + 3)
        if select.select([wake_fd], [], [], max(0, deadline - time.monotonic()))[0]:
            events = os.read(wake_fd, 4096)
            # SIGCHLD is only a state-change hint (including stop/continue).
            # Escalation is already authorized here; this does not declare exit.
            if int(signal.SIGCHLD) in events:
                break
    send(signal.SIGKILL)
    os.waitpid(pid, 0)


def write_child_output(chunk: bytes, log_file: BinaryIO | None, stdout_fd: int) -> None:
    if log_file is not None:
        log_file.write(chunk)
        log_file.flush()

        try:
            os.write(stdout_fd, chunk)
        except BlockingIOError:
            # GitHub log streaming can apply backpressure during very noisy
            # xcodebuild phases. Keep the timeout loop moving; the full output
            # is still persisted to the per-attempt log file.
            return
        return

    view = memoryview(chunk)
    while view:
        written = os.write(stdout_fd, view)
        if written <= 0:
            return
        view = view[written:]


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "usage: xcodebuild_noninteractive.py <command> [args...]",
            file=sys.stderr,
        )
        return 2

    timeout = idle_timeout_seconds()
    post_test_timeout = post_test_timeout_seconds()
    deadline = time.monotonic() + timeout if timeout else None
    post_test_deadline: float | None = None
    selected_tests_failed = False
    log_path = os.environ.get("BMUX_XCODEBUILD_NONINTERACTIVE_LOG_PATH")
    log_file: BinaryIO | None = None
    if log_path:
        log_file = open(log_path, "ab", buffering=0)
    stdout_fd = sys.stdout.fileno()
    if log_file is not None:
        try:
            os.set_blocking(stdout_fd, False)
        except OSError:
            pass

    # Forward a fast, non-interactive Swift crash backtrace into the XCTest
    # host process (bmux DEV.app). The crash that matters happens in the app
    # host, not in xcodebuild, and the job-level SWIFT_BACKTRACE only reaches
    # xcodebuild itself. xcodebuild copies TEST_RUNNER_-prefixed env vars (with
    # the prefix stripped) into the test host's environment, so this is what
    # actually makes an app-host crash backtrace cheap instead of an 80s+
    # symbolicated, interactive hang that eats the CI budget.
    os.environ.setdefault(
        "TEST_RUNNER_SWIFT_BACKTRACE",
        os.environ.get(
            "SWIFT_BACKTRACE", "interactive=no,timeout=0s,symbolicate=off,color=no"
        ),
    )

    # XCTest hosts need the same CI classification as the invoking process.
    # Preserve explicit test-host overrides, including empty or false values.
    for name in ("CI", "GITHUB_ACTIONS"):
        if name in os.environ:
            os.environ.setdefault(f"TEST_RUNNER_{name}", os.environ[name])

    wake_read, wake_write = os.pipe()
    os.set_blocking(wake_read, False)
    os.set_blocking(wake_write, False)
    cancellation = [0, None]
    previous = {}
    previous_wakeup = signal.set_wakeup_fd(wake_write)

    def receive(sig, frame):
        if sig != signal.SIGCHLD and not cancellation[0]:
            cancellation[:] = [sig, time.monotonic()]

    pid, fd = None, None
    try:
        for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGCHLD):
            previous[signum] = signal.signal(signum, receive)
        if cancellation[0]:
            return 128 + cancellation[0]
        pid, fd = pty.fork()
        if pid == 0:
            signal.set_wakeup_fd(-1)
            os.close(wake_read)
            os.close(wake_write)
            for signum in previous:
                signal.signal(signum, signal.SIG_DFL)
            try:
                os.setsid()
            except OSError:
                pass
            os.execvp(sys.argv[1], sys.argv[1:])

        prompt_window = b""
        pending_line = b""
        timed_out = False
        post_test_timed_out = False
        while True:
            if cancellation[0]:
                terminate_child(pid, wake_read, cancellation)
                return 128 + cancellation[0]
            select_timeout = None
            if deadline is not None:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    timed_out = True
                    break
                select_timeout = min(1, remaining)
            if post_test_deadline is not None:
                remaining = post_test_deadline - time.monotonic()
                if remaining <= 0:
                    post_test_timed_out = True
                    break
                select_timeout = min(select_timeout if select_timeout is not None else remaining, remaining, 1)

            try:
                readable, _, _ = select.select([fd, wake_read], [], [], select_timeout)
            except OSError:
                break
            if wake_read in readable:
                os.read(wake_read, 4096)
                if cancellation[0]:
                    continue
            if not readable:
                continue
            if fd not in readable:
                continue

            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break

            write_child_output(chunk, log_file, stdout_fd)
            if timeout:
                deadline = time.monotonic() + timeout
            prompt_window = (prompt_window + chunk)[-4096:]
            # XCTest's Selected-tests summary precedes Swift Testing. The cleanup
            # watchdog applies between frameworks and after completion, never while
            # a framework is executing; the general idle watchdog still applies.
            # Consume complete lines once so noise cannot rediscover old markers.
            lines = (pending_line + chunk).split(b"\n")
            pending_line = lines.pop()[-4096:]
            for line in lines:
                # Swift Testing styles glyphs on this PTY; normalize only parser input.
                line = ANSI_SGR_RE.sub(b"", line)
                selected_match = SELECTED_TESTS_DONE_RE.search(line)
                if selected_match:
                    selected_tests_failed |= selected_match.group(1) == b"failed"
                    if post_test_timeout:
                        post_test_deadline = time.monotonic() + post_test_timeout
                elif SELECTED_TESTS_STARTED in line or SWIFT_TESTING_STARTED in line:
                    post_test_deadline = None
                elif post_test_timeout and SWIFT_TESTING_DONE_RE.search(line):
                    post_test_deadline = time.monotonic() + post_test_timeout
            if SWIFT_CRASH_PROMPT in prompt_window:
                # The Swift crash backtracer asks for one key. Send q to choose the
                # noninteractive quit path and let xcodebuild continue reporting.
                os.write(fd, b"q")
                prompt_window = b""

        if timed_out:
            assert timeout is not None
            print(f"Idle timed out after {timeout:g}s: {' '.join(sys.argv[1:])}", file=sys.stderr)
            if log_file is not None:
                log_file.write(
                    f"Idle timed out after {timeout:g}s: {' '.join(sys.argv[1:])}\n".encode()
                )
                log_file.close()
            terminate_child(pid, wake_read, cancellation)
            return 128 + cancellation[0] if cancellation[0] else TIMEOUT_EXIT_CODE

        if post_test_timed_out:
            assert post_test_timeout is not None
            message = (
                f"Post-test timed out after {post_test_timeout:g}s; terminating "
                f"xcodebuild after test framework completion"
            )
            print(message, file=sys.stderr)
            if log_file is not None:
                log_file.write(f"{message}\n".encode())
                log_file.close()
            terminate_child(pid, wake_read, cancellation)
            if cancellation[0]:
                return 128 + cancellation[0]
            # XCTest may finish before Swift Testing. Even a success marker cannot
            # establish the native process result when the runner must kill it.
            if selected_tests_failed:
                return POST_TEST_FAILED_EXIT_CODE
            return TIMEOUT_EXIT_CODE

        # EOF is not proof of exit: a child may close its PTY and keep running.
        while True:
            if cancellation[0]:
                terminate_child(pid, wake_read, cancellation)
                return 128 + cancellation[0]
            finished, status = os.waitpid(pid, os.WNOHANG)
            if finished:
                break
            select.select([wake_read], [], [])
            os.read(wake_read, 4096)
        if log_file is not None:
            log_file.close()
        return child_exit_code(status)
    finally:
        if pid != 0:  # The exec-failure child already released its wakeup descriptors.
            signal.set_wakeup_fd(previous_wakeup)
            for signum, handler in previous.items():
                signal.signal(signum, handler)
            os.close(wake_read)
            os.close(wake_write)
            if fd is not None:
                os.close(fd)
            if log_file is not None and not log_file.closed:
                log_file.close()


if __name__ == "__main__":
    raise SystemExit(main())
