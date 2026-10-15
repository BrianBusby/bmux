#!/usr/bin/env python3
"""Exercise the native deadline across a console supervisor that cannot forward signals."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from test_ci_app_host_cancellation import become_subreaper, reap_owned_children
from test_ci_xcodebuild_exit_reporting import executable, workflow_script

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == "linux", "owned orphan cleanup requires Linux subreaping")
class ConsoleNativeWatchdogTests(unittest.TestCase):
    def run_native(self, status):
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
                     "BMUX_UNIT_TEST_TIMEOUT_SECONDS": "1", "OWNED_NATIVE_STATUS": str(status)},
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


if __name__ == "__main__":
    unittest.main()
