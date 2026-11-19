#!/usr/bin/env python3
"""Red synthetic transcript-plan regression, intentionally outside test discovery.

BMUX_TEST_CLI selects an existing isolated CLI. This probes transcript tool
calls, not native structured plan notifications. Explicit turn_id fields on
calls/outputs are synthetic; the no-turn-ID case follows the published Codex
0.168.0 ResponseItem shape, not a live runtime observation:
https://github.com/openai/codex/blob/rust-v0.168.0/codex-rs/protocol/src/models.rs
Source retention here is temporary, not durable PE request retention. The
session-outcome-only availability check covers plan_items; its current contract
has no separate field availability for actions_completed. Matching CLI hashes
and schema version do not attest source revision or rule out replacement ABA.
`unverified_plan_evidence` is a proposed reason code, not a shipped contract.
Set BMUX_RUN_BASELINE_CHARACTERIZATION=1 only to reproduce the old accepted-plan
projection; a safe reported-but-unknown-current contract need not satisfy it.
"""

import hashlib
import json
import os
import shutil
import sqlite3
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
    if result == "rejected_no_turn":
        del rows[2]["payload"]["turn_id"]
    if result != "missing":
        output = {"type": "function_call_output", "call_id": "plan-1",
                  "output": REJECTED if result in ("rejected", "rejected_no_turn") else "Plan updated"}
        if result != "rejected_no_turn":
            output["turn_id"] = "turn-1"
        rows.append({"type": "response_item", "payload": output})
    return "".join(json.dumps(row) + "\n" for row in rows)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class CodexPlanRejectedOutcomeRepro(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cli = str(Path(os.environ["BMUX_TEST_CLI"]).resolve(strict=True))
        cls.cli_hash = os.environ["BMUX_TEST_CLI_SHA256"].lower()
        if sha256(Path(cls.cli)) != cls.cli_hash:
            raise AssertionError("CLI does not match BMUX_TEST_CLI_SHA256")
        cls.addClassCleanup(cls.check_cli_hash)
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

    @classmethod
    def check_cli_hash(cls) -> None:
        if sha256(Path(cls.cli)) != cls.cli_hash:
            raise AssertionError("CLI changed during fixture run")

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
        # This checks storage-schema compatibility only, not source-to-binary identity.
        with sqlite3.connect(f"file:{db}?mode=ro", uri=True) as connection:
            self.assertEqual(connection.execute("PRAGMA user_version").fetchone()[0], 31)
        factual = run([str(self.probe), str(db), SESSION])
        outcome = run([self.cli, "--json", "provenance", "session", "outcome", SESSION, "--database", str(db)])
        self.assertEqual(source.read_text(encoding="utf-8"), text, "source transcript was altered")
        self.assertEqual(json.loads(text.splitlines()[2])["payload"]["arguments"],
                         json.dumps({"plan": [{"step": STEP, "status": "completed"}]}))
        self.assertTrue(factual["found"])
        self.assertTrue(outcome["found"])
        return report, factual["snapshot"], outcome["outcome"]

    @unittest.skipUnless(os.environ.get("BMUX_RUN_BASELINE_CHARACTERIZATION") == "1",
                         "Baseline characterization only; not a safety requirement")
    def test_baseline_characterization_acknowledged_plan_is_current(self) -> None:
        report, factual, _ = self.observe("accepted")
        self.assertEqual(report["evidence"]["plans"], 1)
        self.assertEqual(factual["latest_turn"]["current_plan"]["steps"][0]["text"], STEP)

    def test_future_acknowledged_plan_status_is_not_verified_accomplishment(self) -> None:
        _, _, outcome = self.observe("accepted")
        # Plan status is an agent report, not independently verified accomplishment.
        self.assertNotIn(STEP, [item["text"] for item in outcome["actions_completed"]])

    def test_future_missing_or_rejected_result_does_not_become_current_plan(self) -> None:
        for kind in ("missing", "rejected", "rejected_no_turn"):
            with self.subTest(kind=kind):
                _, factual, _ = self.observe(kind)
                self.assertIsNone(factual["latest_turn"].get("current_plan"),
                                  "unconfirmed transcript request was promoted to current plan")

    def test_future_missing_or_rejected_result_does_not_claim_completed_action(self) -> None:
        for kind in ("missing", "rejected", "rejected_no_turn"):
            with self.subTest(kind=kind):
                _, _, outcome = self.observe(kind)
                self.assertNotIn(STEP, [item["text"] for item in outcome["actions_completed"]],
                                 "unconfirmed plan step became a completed action")

    def test_future_result_uncertainty_is_not_reported_as_observed_plan(self) -> None:
        for kind in ("missing", "rejected", "rejected_no_turn"):
            with self.subTest(kind=kind):
                _, _, outcome = self.observe(kind)
                field = next(item for item in outcome["completeness"]["fields"] if item["field"] == "plan_items")
                self.assertIn(field["status"], ("partial", "unavailable"), field)
                self.assertEqual(field.get("reason"), "unverified_plan_evidence", field)

    @unittest.skip("No public PE plan-request/acknowledgment evidence contract exists yet; transcript is source-only")
    def test_future_request_evidence_and_uncertainty_are_inspectable(self) -> None:
        pass


if __name__ == "__main__":
    unittest.main()
