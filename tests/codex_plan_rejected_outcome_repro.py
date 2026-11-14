#!/usr/bin/env python3
"""Red synthetic transcript-plan regression, intentionally outside test discovery.

BMUX_TEST_CLI selects an existing isolated CLI. This probes transcript tool
calls, not native structured plan notifications. The source file is retained
only for this temporary run; it does not prove durable PE request retention.
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SESSION = "plan-probe"
STEP = "Inspect changes"
REJECTED = "update_plan is a TODO/checklist tool and is not allowed in Plan mode"
REPO = Path(__file__).resolve().parent.parent


def environment(root: Path) -> dict:
    env = dict(os.environ)
    for key in tuple(env):
        if key.startswith(("BMUX_", "CMUX_", "CODEX_")):
            del env[key]
    env.update({"HOME": str(root), "CFFIXED_USER_HOME": str(root), "BMUX_PROVENANCE_HOME": str(root),
                "BMUX_DEBUG_LOG": str(root / "debug.log"), "BMUX_CLI_SENTRY_DISABLED": "1"})
    return env


def transcript(result: str) -> str:
    rows = [
        {"type": "session_meta", "payload": {"id": SESSION, "source": "cli", "cwd": "/tmp/synthetic"}},
        {"type": "event_msg", "payload": {"type": "task_started", "turn_id": "turn-1"}},
        {"type": "response_item", "payload": {
            "type": "function_call", "name": "update_plan", "call_id": "plan-1", "turn_id": "turn-1",
            "arguments": json.dumps({"plan": [{"step": STEP, "status": "completed"}]}),
        }},
    ]
    if result != "missing":
        rows.append({"type": "response_item", "payload": {
            "type": "function_call_output", "call_id": "plan-1", "turn_id": "turn-1",
            "output": REJECTED if result == "rejected" else "Plan updated",
        }})
    return "".join(json.dumps(row) + "\n" for row in rows)


class CodexPlanRejectedOutcomeRepro(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="bmux-plan-result-", dir="/tmp")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        package = cls.root / "Probe"
        (package / "Sources" / "Probe").mkdir(parents=True)
        local_pe = json.dumps(str(REPO / "Packages/macOS/ProvenanceEngine"))
        (package / "Package.swift").write_text(
            '// swift-tools-version: 6.0\nimport PackageDescription\n'
            'let package = Package(name: "Probe", platforms: [.macOS(.v10_15)], '
            f'dependencies: [.package(path: {local_pe})], targets: ['
            '.executableTarget(name: "Probe", dependencies: ['
            '.product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine"), '
            '.product(name: "ProvenanceEngineSDK", package: "ProvenanceEngine")])])\n', encoding="utf-8"
        )
        shutil.copyfile(REPO / "tests/codex_plan_rejected_factual_probe.swift", package / "Sources/Probe/Probe.swift")
        cls.build = cls.root / "build"
        subprocess.run(["swift", "build", "--package-path", str(package), "--scratch-path", str(cls.build), "-q"],
                       env=environment(cls.root), capture_output=True, text=True, timeout=120, check=True)
        cls.probe = cls.build / "debug/Probe"
        cls.cli = os.environ["BMUX_TEST_CLI"]

    def observe(self, kind: str) -> tuple[dict, dict, dict]:
        directory = Path(tempfile.mkdtemp(prefix=kind + "-", dir=self.root))
        source = directory / "transcript.jsonl"
        db = directory / "provenance.sqlite"
        text = transcript(kind)
        source.write_text(text, encoding="utf-8")
        env = environment(directory)

        def run(args: list[str]) -> dict:
            result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=20, check=True)
            return json.loads(result.stdout)

        report = run([self.cli, "--json", "provenance", "import", "codex-transcripts",
                      "--path", str(source), "--database", str(db)])
        factual = run([str(self.probe), str(db), SESSION])
        outcome = run([self.cli, "--json", "provenance", "session", "outcome", SESSION, "--database", str(db)])
        self.assertEqual(source.read_text(encoding="utf-8"), text, "source transcript was altered")
        self.assertEqual(json.loads(text.splitlines()[2])["payload"]["arguments"],
                         json.dumps({"plan": [{"step": STEP, "status": "completed"}]}))
        self.assertTrue(factual["found"])
        self.assertTrue(outcome["found"])
        return report, factual["snapshot"], outcome["outcome"]

    def test_explicitly_acknowledged_transcript_plan_control(self) -> None:
        report, factual, outcome = self.observe("accepted")
        self.assertEqual(report["evidence"]["plans"], 1)
        self.assertEqual(factual["latest_turn"]["current_plan"]["steps"][0]["text"], STEP)
        self.assertIn(STEP, [item["text"] for item in outcome["actions_completed"]])

    def test_future_missing_or_rejected_result_does_not_become_current_plan(self) -> None:
        for kind in ("missing", "rejected"):
            with self.subTest(kind=kind):
                _, factual, _ = self.observe(kind)
                self.assertIsNone(factual["latest_turn"].get("current_plan"),
                                  "unconfirmed transcript request was promoted to current plan")

    def test_future_missing_or_rejected_result_does_not_claim_completed_action(self) -> None:
        for kind in ("missing", "rejected"):
            with self.subTest(kind=kind):
                _, _, outcome = self.observe(kind)
                self.assertNotIn(STEP, [item["text"] for item in outcome["actions_completed"]],
                                 "unconfirmed plan step became a completed action")

    def test_future_result_uncertainty_is_not_reported_as_observed_plan(self) -> None:
        for kind in ("missing", "rejected"):
            with self.subTest(kind=kind):
                _, _, outcome = self.observe(kind)
                field = next(item for item in outcome["completeness"]["fields"] if item["field"] == "plan_items")
                self.assertIn(field["status"], ("partial", "unavailable"), field)
                self.assertTrue(field.get("reason"), field)

    @unittest.skip("No public PE plan-request/acknowledgment evidence contract exists yet; transcript is source-only")
    def test_future_request_evidence_and_uncertainty_are_inspectable(self) -> None:
        pass


if __name__ == "__main__":
    unittest.main()
