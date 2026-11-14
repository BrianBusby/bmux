#!/usr/bin/env python3
"""Non-discovery red experiment: later unverified request invalidates currentness.

The first plan is a synthetic structured event submitted through the public PE
SDK, with a deliberately synthetic source label. The second is a synthetic CLI
transcript call, not evidence of a live provider notification. Current PE has no
public request/acknowledgment event or current-plan validity field; the proposed
reason below is not shipped. No production code, native app, or user DB is used.
"""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
import codex_plan_rejected_outcome_repro as base

ROOT = Path(__file__).resolve().parent.parent
SESSION = base.SESSION
OLD = "Original structured step"
NEW = "Unverified proposed step"


def private_environment(root):
    return {
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": str(root), "CFFIXED_USER_HOME": str(root),
        "BMUX_PROVENANCE_HOME": str(root), "BMUX_DEBUG_LOG": str(root / "debug.log"),
        "BMUX_CLI_SENTRY_DISABLED": "1", "TMPDIR": str(root),
    }


def row(timestamp, kind, payload):
    return json.dumps({"timestamp": timestamp, "type": kind, "payload": payload}) + "\n"


class PlanCurrentAmbiguityRepro(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cli = Path(os.environ["BMUX_TEST_CLI"]).resolve(strict=True)
        cls.expected = os.environ["BMUX_TEST_CLI_SHA256"].lower()
        assert base.sha256(cls.cli) == cls.expected
        cls.addClassCleanup(cls.check_hash)
        cls.temp = tempfile.TemporaryDirectory(prefix="pe-plan-current-", dir="/tmp")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        package = cls.root / "Probe"
        (package / "Sources/Probe").mkdir(parents=True)
        local_pe = json.dumps(str(ROOT / "Packages/macOS/ProvenanceEngine"))
        (package / "Package.swift").write_text(
            '// swift-tools-version: 6.0\nimport PackageDescription\n'
            'let package = Package(name: "Probe", platforms: [.macOS(.v10_15)], '
            f'dependencies: [.package(path: {local_pe})], targets: ['
            '.executableTarget(name: "Probe", dependencies: ['
            '.product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine"), '
            '.product(name: "ProvenanceEngineSDK", package: "ProvenanceEngine")])])\n', encoding="utf-8")
        shutil.copyfile(ROOT / "tests/plan_current_ambiguity_probe.swift", package / "Sources/Probe/Probe.swift")
        build = cls.root / "build"
        subprocess.run(["swift", "build", "-j", "2", "--package-path", str(package), "--scratch-path", str(build), "-q"],
                       env=private_environment(cls.root), capture_output=True, text=True, timeout=180, check=True)
        cls.probe = build / "debug/Probe"

    @classmethod
    def check_hash(cls):
        assert base.sha256(cls.cli) == cls.expected

    def run_case(self, result):
        directory = Path(tempfile.mkdtemp(prefix="case-", dir=self.root))
        source = directory / "transcript.jsonl"
        db = directory / "provenance.sqlite"
        initial = row("2026-01-01T00:00:00Z", "session_meta", {"id": SESSION, "source": "cli", "cwd": "/tmp/synthetic"})
        initial += row("2026-01-01T00:00:00Z", "event_msg", {"type": "task_started", "turn_id": "turn-1"})
        source.write_text(initial, encoding="utf-8")
        env = private_environment(directory)
        def run(args):
            completed = subprocess.run([str(x) for x in args], env=env, capture_output=True, text=True, timeout=20, check=True)
            return json.loads(completed.stdout)
        command = [self.cli, "--json", "provenance", "import", "codex-transcripts", "--path", source, "--database", db]
        run(command)
        seeded = run([self.probe, db, SESSION, "seed"])
        self.assertEqual(seeded["factual"]["snapshot"]["latest_turn"]["current_plan"]["steps"][0]["text"], OLD)
        old_revision = seeded["outcome"]["outcome"]["projection"]["revision_id"]
        evidence = seeded["outcome"]["outcome"]["plan_items"][0]["evidence"]
        self.assertEqual(evidence[0]["event_id"], "structured-plan-event")
        self.assertEqual(evidence[0]["evidence_origin"], "synthetic-structured-agent-plan")
        call = row("2026-01-01T00:00:02Z", "response_item", {"type": "function_call", "name": "update_plan", "call_id": "plan-1", "turn_id": "turn-1", "arguments": json.dumps({"plan": [{"step": NEW, "status": "in_progress"}]})})
        if result == "overlap":
            call += row("2026-01-01T00:00:03Z", "response_item", {"type": "function_call", "name": "update_plan", "call_id": "plan-2", "turn_id": "turn-1", "arguments": json.dumps({"plan": [{"step": "Another unverified step", "status": "pending"}]})})
        source.write_text(initial + call, encoding="utf-8")
        run(command)
        current = run([self.probe, db, SESSION, "read"])
        self.assertEqual(source.read_text(encoding="utf-8"), initial + call)
        history = run([self.probe, db, SESSION, "read", old_revision])
        historical_plan = history["outcome"]["outcome"]["plan_items"][0]
        self.assertEqual(historical_plan["text"], OLD)
        self.assertEqual(historical_plan["evidence"][0]["event_id"], "structured-plan-event")
        self.assertEqual(historical_plan["evidence"][0]["evidence_origin"], "synthetic-structured-agent-plan")
        return seeded, current, old_revision

    def test_future_later_unverified_request_leaves_current_plan_unknown(self):
        for result in ("missing", "overlap"):
            _, current, _ = self.run_case(result)
            with self.subTest(result=result, field="current_plan"):
                plan = current["factual"]["snapshot"]["latest_turn"].get("current_plan")
                self.assertIsNone(plan, "neither old nor unverified plan is established current")
            with self.subTest(result=result, field="plan_items_availability"):
                fields = current["outcome"]["outcome"]["completeness"]["fields"]
                field = next(item for item in fields if item["field"] == "plan_items")
                self.assertIn(field["status"], ("partial", "unavailable"))

    @unittest.skipUnless(os.environ.get("BMUX_RUN_BASELINE_CHARACTERIZATION") == "1",
                         "Baseline attribution characterization, not a future safety requirement")
    def test_baseline_transcript_plan_projection_has_transcript_origin(self):
        _, current, _ = self.run_case("missing")
        item = current["outcome"]["outcome"]["plan_items"][0]
        self.assertEqual(item["text"], NEW)
        self.assertEqual(item["evidence"][0]["evidence_origin"], "codex-transcript")
        self.assertNotEqual(item["evidence"][0]["event_id"], "structured-plan-event")

    @unittest.skip("No public plan-request/ack evidence contract or current-validity field exists")
    def test_future_both_sources_remain_inspectable_with_correct_validity(self):
        pass


if __name__ == "__main__":
    unittest.main()
