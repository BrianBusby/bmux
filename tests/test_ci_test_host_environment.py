#!/usr/bin/env python3
"""Exercise CI flag transport through the real console and PTY entrypoints."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONSOLE = ROOT / "scripts/ci/run-in-console-session.sh"
PTY = ROOT / "scripts/ci/xcodebuild_noninteractive.py"
FLAGS = ("CI", "GITHUB_ACTIONS", "TEST_RUNNER_CI", "TEST_RUNNER_GITHUB_ACTIONS")

# The first sudo models an environment-reset boundary, not the runner's actual
# sudo configuration. Every shim execs its successor; no privileged tool runs.
SHIM = r'''
import os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["OWNED_SHIM_ROOT"])
mode = (root / "mode").read_text()
if name == "stat":
    print("root" if mode == "no-console" else "owned-console")
elif name == "id":
    print("501")
elif name == "dscl":
    print("NFSHomeDirectory: " + str(root / "console-home"))
elif name == "sudo":
    if args == ["-n", "true"]:
        raise SystemExit(1 if mode == "no-sudo" else 0)
    if args[:2] == ["-n", "launchctl"]:
        # Deliberately retain only shim plumbing. Forwarded env assignments
        # must survive as argv through both hops, as in the real helper.
        env = {key: os.environ[key] for key in ("PATH", "OWNED_SHIM_ROOT")}
        os.execvpe("launchctl", args[1:], env)
    assert args[:5] == ["-n", "-u", "owned-console", "-E", "env"]
    os.execvp("env", args[4:])
elif name == "launchctl":
    assert args[:2] == ["asuser", "501"]
    os.execvp(args[2], args[2:])
else:
    raise AssertionError("Unexpected owned shim")
'''

PROBE = '''import json, os, sys
keys = ("CI", "GITHUB_ACTIONS", "TEST_RUNNER_CI", "TEST_RUNNER_GITHUB_ACTIONS",
        "OWNED_UNRELATED_FLAG", "HOME")
print(json.dumps({key: os.environ[key] for key in keys if key in os.environ}), flush=True)
raise SystemExit(7)
'''


class TestHostEnvironmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="ci-host-env-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / "console-home").mkdir()
        (self.root / "mode").write_text("reset")
        for name in ("stat", "id", "dscl", "sudo", "launchctl"):
            executable = self.bin / name
            executable.write_text(f"#!{sys.executable}\n" + SHIM)
            executable.chmod(0o755)
        self.probe = self.root / "probe.py"
        self.probe.write_text(PROBE)

    def cases(self):
        yield "unset", {}, {}
        for raw in ("CI", "GITHUB_ACTIONS"):
            prefixed = "TEST_RUNNER_" + raw
            for value in ("true", "false", ""):
                yield f"{raw}={value!r}", {raw: value}, {raw: value, prefixed: value}
            for override in ("true", "false", ""):
                inputs = {raw: "false" if override == "true" else "true", prefixed: override}
                yield f"{raw}-override={override!r}", inputs, inputs
            for value in ("true", "false", ""):
                yield f"{raw}-prefix-only={value!r}", {prefixed: value}, {prefixed: value}
        yield "independent-overrides", {
            "CI": "true", "TEST_RUNNER_CI": "false", "GITHUB_ACTIONS": "false",
            "TEST_RUNNER_GITHUB_ACTIONS": "true",
        }, {
            "CI": "true", "TEST_RUNNER_CI": "false", "GITHUB_ACTIONS": "false",
            "TEST_RUNNER_GITHUB_ACTIONS": "true",
        }

    def observe(self, inputs: dict[str, str], *, console: bool, pty: bool):
        release_read, release_write = os.pipe()
        command = [sys.executable, str(self.probe), str(release_read)]
        if pty:
            command = [sys.executable, str(PTY), *command]
        if console:
            command = ["/bin/bash", str(CONSOLE), *command]
        # No ambient credentials, CI flags or user paths enter the owned probe.
        environment = {
            "PATH": str(self.bin) + os.pathsep + os.defpath,
            "HOME": str(self.root), "GITHUB_WORKSPACE": str(self.root),
            "OWNED_SHIM_ROOT": str(self.root), "OWNED_UNRELATED_FLAG": "owned",
            **inputs,
        }
        process = None
        try:
            process = subprocess.Popen(command, env=environment, cwd=self.root,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       text=True, pass_fds=(release_read,))
            try:
                output, _ = process.communicate(timeout=5)
            except BaseException:
                # Cleanup also covers interruption; always rethrow the original failure.
                # TERM lets the real PTY owner join its child. The owned pipe
                # releases the diagnostic probe even if forced cleanup is needed.
                try:
                    process.terminate()
                except ProcessLookupError:
                    pass  # It exited at the timeout boundary; still join below.
                os.close(release_write)
                release_write = None
                try:
                    process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    try:
                        process.kill()
                    except ProcessLookupError:
                        pass  # Preserve the original failure if exit won the race.
                    process.communicate(timeout=5)
                raise
            self.assertEqual(process.returncode, 7, "Preserve the probe's native exit")
            return json.loads(output.strip())
        finally:
            os.close(release_read)
            if release_write is not None:
                os.close(release_write)
            if process is not None:
                self.last_returncode = process.returncode
                process.stdout.close()
                process.stderr.close()

    def test_direct_pty_maps_only_present_flags_and_preserves_overrides(self):
        for label, inputs, expected in self.cases():
            with self.subTest(case=label):
                observed = self.observe(inputs, console=False, pty=True)
                self.assertEqual({key: observed[key] for key in FLAGS if key in observed}, expected)
                self.assertEqual(observed["OWNED_UNRELATED_FLAG"], "owned")

    def test_reset_console_preserves_exact_inputs_without_forwarding_unrelated_flags(self):
        for label, inputs, _ in self.cases():
            with self.subTest(case=label):
                observed = self.observe(inputs, console=True, pty=False)
                self.assertEqual({key: observed[key] for key in FLAGS if key in observed}, inputs)
                self.assertNotIn("OWNED_UNRELATED_FLAG", observed)
                self.assertEqual(observed["HOME"], str(self.root / "console-home"))

    def test_reset_console_then_pty_preserves_test_host_overrides(self):
        for label, inputs, expected in self.cases():
            with self.subTest(case=label):
                observed = self.observe(inputs, console=True, pty=True)
                self.assertEqual({key: observed[key] for key in FLAGS if key in observed}, expected)
                self.assertNotIn("OWNED_UNRELATED_FLAG", observed)

    def test_timeout_rethrows_after_pty_owner_joins_released_probe(self):
        self.probe.write_text("""import os, pathlib, signal, sys
root = pathlib.Path(__file__).parent
(root / "probe-pid").write_text(str(os.getpid()))
# The parent's owned EOF releases this probe even if TERM delivery overlaps
# its completion marker; the real PTY owner still must join it before return.
signal.signal(signal.SIGTERM, lambda signum, frame: None)
try:
    os.read(int(sys.argv[1]), 1)
finally:
    (root / "probe-finished").write_text("finished")
""")
        with self.assertRaises(subprocess.TimeoutExpired):
            self.observe({}, console=True, pty=True)
        self.assertEqual(self.last_returncode, 143)
        self.assertEqual((self.root / "probe-finished").read_text(), "finished")
        pid = int((self.root / "probe-pid").read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)  # Observation only: the PTY owner must have reaped it.

    def test_console_fallback_preserves_environment_and_native_status(self):
        for mode in ("no-console", "no-sudo"):
            (self.root / "mode").write_text(mode)
            for label, inputs, _ in self.cases():
                with self.subTest(mode=mode, case=label):
                    observed = self.observe(inputs, console=True, pty=False)
                    self.assertEqual({key: observed[key] for key in FLAGS if key in observed}, inputs)
                    self.assertEqual(observed["OWNED_UNRELATED_FLAG"], "owned")
                    self.assertEqual(observed["HOME"], str(self.root))


if __name__ == "__main__":
    unittest.main()
