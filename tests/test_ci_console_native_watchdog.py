#!/usr/bin/env python3
"""Exercise the native deadline across a console supervisor that cannot forward signals."""
import os
from pathlib import Path
import shutil
import select
import signal
import subprocess
import sys
import tempfile
import time
import unittest

from test_ci_app_host_cancellation import become_subreaper, reap_owned_children
from test_ci_xcodebuild_exit_reporting import executable, workflow_script

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == "linux", "owned orphan cleanup requires Linux subreaping")
class ConsoleNativeWatchdogTests(unittest.TestCase):
    def run_native(self, status, timeout="1"):
        become_subreaper()
        with tempfile.TemporaryDirectory(prefix="console-watchdog-") as directory:
            root = Path(directory)
            scripts = root / "scripts/ci"
            scripts.mkdir(parents=True)
            # Execute workflow tee/retry/status logic; substitute external GUI
            # and build commands. No privileged tool or app is launched.
            executable(scripts / "run-in-console-session.sh", f"#!{sys.executable}\n" + '''
import subprocess, sys
# Signals to this outer supervisor cannot cross the console session boundary.
child = subprocess.Popen(sys.argv[1:], start_new_session=True)
raise SystemExit(child.wait())
''')
            executable(scripts / "run-app-host-xcodebuild.sh", f"#!{sys.executable}\n" + '''
import os, pathlib, signal
root = pathlib.Path(os.environ["RUNNER_TEMP"])
status = os.environ["OWNED_NATIVE_STATUS"]
(root / "native-started").write_text("started")
if status != "hang":
    print("owned native result", flush=True)
    raise SystemExit(int(status))
def finish(signum, frame):
    (root / "native-joined").write_text("cancelled")
    raise SystemExit(128 + signum)
signal.signal(signal.SIGTERM, finish)
signal.signal(signal.SIGINT, finish)
print("owned native awaiting cancellation", flush=True)
while True:
    signal.pause()
''')
            # Keep the build prerequisite separate from the native deadline probe.
            executable(scripts / "xcodebuild_noninteractive.py", f"#!{sys.executable}\n" + '''
import sys
assert sys.argv[-1] == "build-for-testing"
raise SystemExit(0)
''')
            executable(scripts / "bmux_unit_test_shard.py", '''import pathlib, sys
pathlib.Path(sys.argv[-1]).write_text('-only-testing:bmuxTests/OwnedFixture\\n')
''')
            # The old workflow runs without the future extracted owner as well.
            for path in (ROOT / "scripts/ci").glob("run-unit-tests-with-timeout.py"):
                shutil.copy2(path, scripts / path.name)
            script = workflow_script("ci.yml", "Run unit tests")
            process = subprocess.Popen(
                ["/bin/bash", "-c", script], cwd=root,
                env={"PATH": os.defpath, "HOME": directory, "RUNNER_TEMP": directory,
                     "BMUX_DERIVED_DATA_PATH": str(root / "derived"),
                     "BMUX_UNIT_TEST_TIMEOUT_SECONDS": timeout, "OWNED_NATIVE_STATUS": str(status)},
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            )
            failure = None
            try:
                # Existing polling and shutdown grace fit this failure bound.
                output, _ = process.communicate(timeout=15)
                self.assertEqual(process.returncode, 124 if status == "hang" else status, output)
                if status == "hang":
                    self.assertEqual((root / "native-joined").read_text(), "cancelled")
                    self.assertIn("unit test timeout", output)
                self.assertTrue((root / "native-started").is_file())
            except subprocess.TimeoutExpired:
                failure = AssertionError("native deadline left the console output pipeline open")
            except BaseException as error:
                failure = error
            finally:
                # Expected-red orphan descendants join before temporary cleanup.
                reap_owned_children(process, {}, set())
                process.communicate(timeout=2)
                process.stdout.close()
            if failure:
                raise failure

    def test_console_boundary_timeout_finishes_the_output_pipeline(self):
        self.run_native("hang")

    def test_console_boundary_preserves_native_status(self):
        for status in (0, 65, 124):
            with self.subTest(status=status):
                self.run_native(status)


    def test_empty_timeout_retains_default_and_native_status(self):
        self.run_native(65, timeout="")

    def test_external_cancellation_joins_running_stopped_and_cleanup_children(self):
        for phase in ("running", "stopped", "deadline-cleanup"):
            for signum in (signal.SIGTERM, signal.SIGINT):
                with self.subTest(phase=phase, signum=signum):
                    self.cancel_owned_child(phase, signum)

    def read_marker(self, descriptor):
        deadline = time.monotonic() + 5
        value = b""
        while not value.endswith(b"\n"):
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([descriptor], [], [], remaining)[0]:
                raise AssertionError("owned phase marker not delivered")
            value += os.read(descriptor, 1)  # Leave the next marker in the FIFO.
        return value.rstrip(b"\n")

    def cancel_owned_child(self, phase, signum):
        become_subreaper()
        with tempfile.TemporaryDirectory(prefix="console-deadline-cancel-") as directory:
            root = Path(directory)
            child = root / "child.py"
            child.write_text('''import os, pathlib, signal, sys
root = pathlib.Path(sys.argv[1])
phase = sys.argv[2]
(root / "pid").write_text(str(os.getpid()))
def notify(message):
    with (root / "ready").open("w") as output:
        output.write(message + "\\n")
def terminate(signum, frame):
    if phase == "deadline-cleanup":
        notify("terminating")
    else:
        raise SystemExit(0)
if phase != "stopped":
    signal.signal(signal.SIGTERM, terminate)
notify("ready")
if phase == "stopped":
    os.kill(os.getpid(), signal.SIGSTOP)
while True:
    signal.pause()
''')
            os.mkfifo(root / "ready")
            ready = os.open(root / "ready", os.O_RDWR | os.O_NONBLOCK)
            process = subprocess.Popen(
                [sys.executable, str(ROOT / "scripts/ci/run-unit-tests-with-timeout.py"),
                 sys.executable, str(child), directory, phase],
                env={"PATH": os.defpath, "BMUX_UNIT_TEST_TIMEOUT_SECONDS": "1" if phase == "deadline-cleanup" else "30"},
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            try:
                self.assertEqual(self.read_marker(ready), b"ready")
                if phase == "stopped":
                    pid = int((root / "pid").read_text())
                    deadline = time.monotonic() + 5
                    while True:
                        state = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0]
                        if state == "T":
                            break  # Observe the owned child's actual SIGSTOP before cancellation.
                        if time.monotonic() >= deadline:
                            raise AssertionError("owned child never entered stopped state")
                        select.select([], [], [], 0.01)
                if phase == "deadline-cleanup":
                    self.assertEqual(self.read_marker(ready), b"terminating")
                process.send_signal(signum)
                output, _ = process.communicate(timeout=8)
                self.assertEqual(process.returncode, 128 + signum, output)
                with self.assertRaises(ProcessLookupError):
                    os.kill(int((root / "pid").read_text()), 0)
            finally:
                os.close(ready)
                reap_owned_children(process, {}, set())
                process.communicate(timeout=2)
                process.stdout.close()


if __name__ == "__main__":
    unittest.main()
