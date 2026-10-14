#!/usr/bin/env python3
"""Exercise the real CLI after its reply peer has observably closed."""

from __future__ import annotations

import os
from pathlib import Path
import signal
import socket
import subprocess
import tempfile
import unittest


class ClosedPeerCLI:
    """Own the child and socket; stop acknowledgment makes closure ordering causal."""

    def __init__(self, executable: str, deadline: float) -> None:
        self.executable = executable
        self.deadline = deadline

    def run(self, reply: bytes) -> subprocess.CompletedProcess[bytes]:
        if signal.getitimer(signal.ITIMER_REAL) != (0.0, 0.0):
            raise RuntimeError("closed-peer fixture requires an unowned process timer")
        previous_handler = signal.getsignal(signal.SIGALRM)
        phase = "launch"

        def deadline_expired(_signum: int, _frame: object) -> None:
            raise TimeoutError(f"closed-peer fixture deadline during {phase}")

        # This main-thread deadline bounds native accept/read/waitpid, not a settling delay.
        signal.signal(signal.SIGALRM, deadline_expired)
        try:
            with tempfile.TemporaryDirectory(prefix="bmux-peer-", dir="/tmp") as root:
                path = str(Path(root) / "s")
                environment = {
                    "PATH": os.defpath,
                    "HOME": root,
                    "CFFIXED_USER_HOME": root,
                    "XDG_CONFIG_HOME": str(Path(root) / "config"),
                    "XDG_DATA_HOME": str(Path(root) / "data"),
                    "XDG_CACHE_HOME": str(Path(root) / "cache"),
                    "BMUX_UI_TEST_MODE": "1",
                    "XCTestConfigurationFilePath": str(Path(root) / "owned.xctestconfiguration"),
                    "BMUX_CLI_SENTRY_DISABLED": "1",
                    "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
                }
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener, \
                        open(Path(root) / "stdout", "w+b") as stdout, \
                        open(Path(root) / "stderr", "w+b") as stderr:
                    listener.bind(path)
                    listener.listen(1)
                    command = [self.executable, "--socket", path, "ping"]
                    child = subprocess.Popen(command, env=environment, stdin=subprocess.DEVNULL,
                                             stdout=stdout, stderr=stderr)
                    try:
                        # Arm only after the child handle belongs to this cleanup scope.
                        signal.setitimer(signal.ITIMER_REAL, self.deadline)
                        phase = "accept"
                        connection, _ = listener.accept()
                        with connection:
                            phase = "request"
                            request = bytearray()
                            while not request.endswith(b"\n"):
                                chunk = connection.recv(4096)
                                if not chunk:
                                    raise RuntimeError("CLI closed before sending its request")
                                request.extend(chunk)
                            if request != b"ping\n":
                                raise RuntimeError("CLI sent an unexpected fixture request")

                            phase = "stop acknowledgment"
                            child.send_signal(signal.SIGSTOP)
                            pid, stopped = os.waitpid(child.pid, os.WUNTRACED)
                            if pid != child.pid or not os.WIFSTOPPED(stopped):
                                if os.WIFEXITED(stopped) or os.WIFSIGNALED(stopped):
                                    child.returncode = os.waitstatus_to_exitcode(stopped)
                                raise RuntimeError("owned CLI exited before stop acknowledgment")
                            if os.WSTOPSIG(stopped) != signal.SIGSTOP:
                                raise RuntimeError("owned CLI stopped for an unexpected signal")
                            phase = "closed-peer reply"
                            connection.sendall(reply)
                        # The peer is closed before any next client userspace read/configuration.
                        child.send_signal(signal.SIGCONT)
                        phase = "CLI completion"
                        returncode = child.wait()
                    finally:
                        signal.setitimer(signal.ITIMER_REAL, 0)
                        if child.poll() is None:
                            # Always resume a potentially stopped owned child before kill/join.
                            child.send_signal(signal.SIGCONT)
                            child.kill()
                            child.wait(timeout=self.deadline)
                    stdout.seek(0)
                    stderr.seek(0)
                    return subprocess.CompletedProcess(command, returncode, stdout.read(), stderr.read())
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous_handler)


class ClosedPeerReceiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        executable = os.environ.get("BMUX_CLI_BIN")
        if not executable or not Path(executable).is_file() or not os.access(executable, os.X_OK):
            raise RuntimeError("Set BMUX_CLI_BIN to the exact built CLI executable")
        cls.fixture = ClosedPeerCLI(executable, deadline=3.0)

    def test_complete_replies_survive_peer_close_before_receive(self) -> None:
        for reply in (b"PONG\n", b"TAGGED\n", "TAGGED\n  日本語: second line  \n".encode(), b"first\nlast"):
            with self.subTest(reply=reply):
                result = self.fixture.run(reply)
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                self.assertEqual(result.stdout, reply if reply.endswith(b"\n") else reply + b"\n")
                self.assertEqual(result.stderr, b"")

    def test_empty_closed_peer_retains_eof_error(self) -> None:
        result = self.fixture.run(b"")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"Error: Socket closed before reply\n")

    def test_truncated_closed_peer_retains_incomplete_reply_error(self) -> None:
        result = self.fixture.run(b"TAGGED")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"Error: Socket closed before complete reply\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
