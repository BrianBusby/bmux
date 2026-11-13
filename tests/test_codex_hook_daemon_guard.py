#!/usr/bin/env python3
"""Exercise generated Codex hooks from independent and shared-daemon parents."""

import os
from pathlib import Path
import re
import selectors
import shutil
import statistics
import subprocess
import sys
import tempfile
import time


def main():
    cli = sys.argv[1]
    baseline = "--baseline" in sys.argv[2:]
    with tempfile.TemporaryDirectory(prefix="bmux-hook-origin-") as directory:
        root = Path(directory)
        fifo = root / "capture"
        os.mkfifo(fifo)
        recorder = root / "recorder"
        recorder.write_text('#!/bin/sh\nprintf "%s" "${BMUX_CODEX_HOOK_IDENTITY_VERIFIED:-missing}" > "$CAPTURE_FIFO"\n')
        recorder.chmod(0o755)
        env = os.environ.copy()
        env["BMUX_CODEX_HOOK_IDENTITY_VERIFIED"] = "1"  # A daemon can inherit stale environment.
        env.update({"HOME": str(root), "CFFIXED_USER_HOME": str(root), "CODEX_HOME": str(root),
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
        stop_config = next(arg for arg in args if arg.startswith("hooks.Stop="))
        stop_match = re.search(r"command='''([^']+)'''", stop_config)
        if not stop_match:
            raise AssertionError("missing generated stop hook")
        stop_hook = stop_match.group(1)
        if not Path(hook).is_file():
            raise AssertionError("expected executable generated hook script")
        source = root / "parent.c"
        source.write_text(r'''#include <sys/wait.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 4) return 2;
    pid_t child = fork();
    if (child == 0) { execl("/bin/sh", "sh", argv[3], (char *)0); _exit(127); }
    int status = 0;
    if (child < 0 || waitpid(child, &status, 0) < 0) return 3;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 4;
}
''')
        codex = root / "codex"
        subprocess.run(["/usr/bin/clang", "-Wall", "-Werror", str(source), "-o", str(codex)], check=True, timeout=20)
        unknown = root / "unknown-parent"
        shutil.copyfile(codex, unknown)
        unknown.chmod(0o755)
        reader = os.open(fifo, os.O_RDONLY | os.O_NONBLOCK)
        try:
            selector = selectors.DefaultSelector()
            selector.register(reader, selectors.EVENT_READ)
            durations = {"independent": [], "managed": [], "unknown": [], "stop": []}
            for mode, expected in [("independent", b"1"), ("managed", b"0"), ("unknown", b"0"), ("stop", b"0")]:
                if baseline:
                    expected = b"1"
                daemon_args = ["app-server", "--managed-daemon"] if mode == "managed" else ["client", "--no-daemon"]
                for _ in range(5):
                    started = time.monotonic()
                    process = subprocess.run([str(unknown if mode == "unknown" else codex), *daemon_args,
                                              stop_hook if mode == "stop" else hook], input=b"{}", env=env,
                                             capture_output=True, timeout=10, check=True)
                    durations[mode].append((time.monotonic() - started) * 1000)
                    if process.stdout.strip() != b"{}":
                        raise AssertionError(f"{mode} hook did not acknowledge: {process.stdout!r}")
                    if not selector.select(timeout=2):
                        raise AssertionError(f"{mode} hook worker did not run")
                    actual = os.read(reader, 128)
                    if actual != expected:
                        raise AssertionError(f"{mode} hook identity was {actual!r}, expected {expected!r}")
        finally:
            os.close(reader)
    medians = {mode: round(statistics.median(samples), 1) for mode, samples in durations.items()}
    print(f"PASS: {'baseline' if baseline else 'attested'} hook latency medians ms (5 samples): {medians}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
