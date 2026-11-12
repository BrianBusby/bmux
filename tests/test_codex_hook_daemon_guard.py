#!/usr/bin/env python3
"""Exercise generated Codex hooks from independent and shared-daemon parents."""

import os
from pathlib import Path
import re
import selectors
import subprocess
import sys
import tempfile


def main():
    cli = sys.argv[1]
    with tempfile.TemporaryDirectory(prefix="bmux-hook-origin-") as directory:
        root = Path(directory)
        fifo = root / "capture"
        os.mkfifo(fifo)
        recorder = root / "recorder"
        recorder.write_text('#!/bin/sh\nprintf invoked > "$CAPTURE_FIFO"\n')
        recorder.chmod(0o755)
        env = os.environ.copy()
        env.update({"HOME": str(root), "CFFIXED_USER_HOME": str(root),
                    "BMUX_BUNDLED_CLI_PATH": str(recorder), "BMUX_SURFACE_ID": "test-surface",
                    "CAPTURE_FIFO": str(fifo), "BMUX_CODEX_HOOKS_DISABLED": "0"})
        result = subprocess.run([cli, "hooks", "codex", "inject-args"], env=env,
                                capture_output=True, check=True, timeout=20)
        args = result.stdout.decode().split("\0")
        config = next(arg for arg in args if arg.startswith("hooks.UserPromptSubmit="))
        match = re.search(r"command='''([^']+)'''", config)
        if not match:
            raise AssertionError("missing generated hook command")
        hook = match.group(1)
        if not Path(hook).is_file():
            raise AssertionError("expected executable generated hook script")
        reader = os.open(fifo, os.O_RDONLY | os.O_NONBLOCK)
        try:
            selector = selectors.DefaultSelector()
            selector.register(reader, selectors.EVENT_READ)
            for mode, should_invoke in [("independent", True), ("managed", False)]:
                daemon_args = ["app-server", "--managed-daemon"] if mode == "managed" else ["client", "--no-daemon"]
                process = subprocess.run(
                    ["/bin/bash", "-c", 'export BMUX_CODEX_PID=$$; shift 2; "$@"; result=$?; exit "$result"',
                     "codex", *daemon_args, "/bin/sh", hook], input=b"{}", env=env,
                    capture_output=True, timeout=10, check=True)
                if process.stdout.strip() != b"{}":
                    raise AssertionError(f"{mode} hook did not acknowledge: {process.stdout!r}")
                ready = bool(selector.select(timeout=2))
                if ready:
                    os.read(reader, 128)
                if ready != should_invoke:
                    raise AssertionError(f"{mode} hook invocation was {ready}, expected {should_invoke}")
        finally:
            os.close(reader)
    print("PASS: independent hook captured; shared daemon hook suppressed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
