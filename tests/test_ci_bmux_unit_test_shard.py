#!/usr/bin/env python3
"""Behavioral guards for bmuxTests CI sharding."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "ci" / "bmux_unit_test_shard.py"


def write_large_suite_fixture(test_root: Path) -> None:
    methods = "\n".join(
        f"    func testGenerated{index:02d}() {{}}"
        for index in range(1, 41)
    )
    (test_root / "LargeSuiteTests.swift").write_text(
        f"""
final class LargeSuiteTests: XCTestCase {{
{methods}
}}
""".lstrip(),
        encoding="utf-8",
    )
    (test_root / "LargeSuiteExtensionTests.swift").write_text(
        """
extension LargeSuiteTests {
    func testExtensionRegression() {}
}
""".lstrip(),
        encoding="utf-8",
    )


def partition(root: Path, directory: Path, total: int) -> tuple[list[str], list[int]]:
    selectors: list[str] = []
    weights: list[int] = []
    for shard in range(1, total + 1):
        output = directory / f"shard-{total}-{shard}.args"
        result = subprocess.run(
            [sys.executable, str(HELPER), "--root", str(root),
             "--shard-index", str(shard), "--shard-total", str(total),
             "--output", str(output)],
            text=True, capture_output=True, check=True,
        )
        selectors.extend(output.read_text(encoding="utf-8").splitlines())
        weights.append(int(result.stdout.splitlines()[0].split("weight ", 1)[1].split(",", 1)[0]))
    assert len(selectors) == len(set(selectors)), f"{total} shards duplicate selectors"
    assert max(weights) - min(weights) <= 1, f"{total} shard weights are unbalanced: {weights}"
    return selectors, weights


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_root = Path(tmp)
        test_root = tmp_root / "bmuxTests"
        test_root.mkdir()
        write_large_suite_fixture(test_root)
        expected = {f"-only-testing:bmuxTests/LargeSuiteTests/testGenerated{index:02d}"
                    for index in range(1, 41)}
        expected.add("-only-testing:bmuxTests/LargeSuiteTests/testExtensionRegression")
        for total in (4, 8):
            selectors, _ = partition(tmp_root, tmp_root, total)
            assert set(selectors) == expected, f"{total} shards lost or added fixture tests"

    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        discovered = subprocess.run(
            [sys.executable, str(HELPER), "--root", str(ROOT), "--list"],
            text=True, capture_output=True, check=True,
        )
        expected = {"-only-testing:" + line.split("\t", 1)[0]
                    for line in discovered.stdout.splitlines()}
        for total in (4, 8):
            selectors, weights = partition(ROOT, directory, total)
            assert set(selectors) == expected, f"{total} shards lost or added repository selectors"
            for focused in (
                "BrowserSystemProxyMirrorTests",
                "DeferredTerminalSearchFocusTests",
                "GhosttyOptionAsAltModsTests",
                "WorkspaceStressProfileTests",
            ):
                assert f"-only-testing:bmuxTests/{focused}" not in selectors, "focused gate duplicated"
            print(f"PASS: {total} shards cover {len(selectors)} selectors exactly once; weights {weights}")

    print("PASS: extension methods and focused gates retain their original ownership")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
