#!/usr/bin/env python3
"""Execute workflow test steps against controlled native-runner outcomes."""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = {
    "ci.yml": "Run unit tests",
    "ci-macos-compat.yml": "Run unit tests",
    "test-depot.yml": "Run unit tests",
    "tmux-corpus.yml": "Run terminal corpus unit tests",
}
FAILURES = "Executed 10 tests, with 2 failures (0 unexpected) in 0.1 seconds"
ZERO = "Executed 0 tests, with 0 failures (0 unexpected) in 0.0 seconds"


def workflow_script(filename: str, step_name: str) -> str:
    # Extract the actual block scalar to execute it, not to assert source shape.
    # GitHub normally binds matrix.shard; this harness exercises shard 1.
    lines = (ROOT / ".github/workflows" / filename).read_text().splitlines()
    step = lines.index("      - name: " + step_name)
    start = next(i for i in range(step + 1, len(lines)) if lines[i] == "        run: |") + 1
    end = start
    while end < len(lines) and (not lines[end].strip() or lines[end].startswith("          ")):
        end += 1
    return textwrap.dedent("\n".join(lines[start:end])).replace("${{ matrix.shard }}", "1")


def executable(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents)
    path.chmod(0o755)


class WorkflowExitReportingTests(unittest.TestCase):
    def run_step(self, filename: str, outcomes: list[tuple[int, str]], *, tee_fails: bool = False):
        with tempfile.TemporaryDirectory(prefix="bmux-ci-exit-") as temporary:
            root = Path(temporary)
            fixture = root / "outcomes.json"
            fixture.write_text(json.dumps(outcomes))
            counter = root / "attempts"
            runner = """#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
# Compilation is a separate prerequisite; these outcomes model native tests.
if sys.argv[-1:] == ["build-for-testing"]:
    raise SystemExit(0)
counter = Path(os.environ['REPORTING_TEST_COUNTER'])
attempt = int(counter.read_text()) if counter.exists() else 0
counter.write_text(str(attempt + 1))
outcomes = json.loads(Path(os.environ['REPORTING_TEST_OUTCOMES']).read_text())
status, output = outcomes[min(attempt, len(outcomes) - 1)]
print(output, flush=True)
raise SystemExit(status)
"""
            # Native GUI/build executables are dependency boundaries. Never run
            # real xcodebuild, GUI routing, or cache deletion from this harness.
            for name in ["run-app-host-xcodebuild.sh", "xcodebuild_noninteractive.py"]:
                executable(root / "scripts/ci" / name, runner)
            executable(root / "scripts/ci/run-in-console-session.sh", '#!/bin/bash\nexec "$@"\n')
            executable(root / "scripts/ci/bmux_unit_test_shard.py", "import sys\nfrom pathlib import Path\nPath(sys.argv[-1]).write_text('-only-testing:bmuxTests/Fixture\\n')\n")
            for name in ["rm", "mkdir"]:
                executable(root / "bin" / name, "#!/bin/bash\nexit 0\n")
            executable(root / "bin/sleep", "#!/usr/bin/env python3\nimport time\ntime.sleep(0.01)\n")
            if tee_fails:
                executable(root / "bin/tee", "#!/usr/bin/env python3\nimport sys\nfrom pathlib import Path\ndata=sys.stdin.read()\nPath(sys.argv[1]).write_text(data)\nprint(data, end='')\nraise SystemExit(73)\n")
            shutil.copy2(ROOT / "scripts/ci/run-unit-tests-with-timeout.py", root / "scripts/ci")
            script = workflow_script(filename, WORKFLOWS[filename])
            # Isolate the two legacy hardcoded log destinations, preserving all
            # shell control flow and command-status handling from the workflow.
            for path in ["/tmp/test-output.txt", "/tmp/tmux-terminal-corpus-output.txt"]:
                script = script.replace(path, str(root / Path(path).name))
            result = subprocess.run(
                ["bash", "-c", script], cwd=root, text=True, capture_output=True,
                timeout=15,
                env={**os.environ, "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
                     "RUNNER_TEMP": str(root), "BMUX_DERIVED_DATA_PATH": str(root / "derived"),
                     "REPORTING_TEST_COUNTER": str(counter), "REPORTING_TEST_OUTCOMES": str(fixture)},
            )
            attempts = int(counter.read_text()) if counter.exists() else 0
            return result, attempts

    def test_nonzero_status_survives_misleading_summaries(self):
        for filename in WORKFLOWS:
            for status, output in [(65, FAILURES), (65, FAILURES + "\n" + ZERO),
                                   (65, ZERO + "\nSwift Testing recorded an issue"),
                                   (124, ZERO), (125, FAILURES), (143, ZERO),
                                   (65, "build failed before tests")]:
                with self.subTest(workflow=filename, status=status, output=output):
                    result, attempts = self.run_step(filename, [(status, output)])
                    self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                    self.assertEqual(attempts, 1)

    def test_zero_exit_including_expected_failures_passes(self):
        for filename in WORKFLOWS:
            for output in [ZERO, "Expected failure recorded\n** TEST SUCCEEDED **"]:
                with self.subTest(workflow=filename, output=output):
                    result, attempts = self.run_step(filename, [(0, output)])
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(attempts, 1)

    def test_swiftpm_retry_reports_final_attempt(self):
        for filename in WORKFLOWS:
            if filename == "tmux-corpus.yml":
                continue
            for final_status, output in [(0, ZERO), (65, FAILURES),
                                         (65, "Could not resolve package dependencies"), (124, ZERO)]:
                with self.subTest(workflow=filename, status=final_status):
                    result, attempts = self.run_step(filename, [
                        (65, "Could not resolve package dependencies"), (final_status, output)])
                    self.assertEqual(result.returncode, final_status, result.stdout + result.stderr)
                    self.assertEqual(attempts, 2)

    def test_log_pipeline_failure_is_not_success(self):
        for filename in ["ci.yml", "ci-macos-compat.yml", "tmux-corpus.yml"]:
            with self.subTest(workflow=filename):
                result, _ = self.run_step(filename, [(0, ZERO)], tee_fails=True)
                self.assertEqual(result.returncode, 73, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
