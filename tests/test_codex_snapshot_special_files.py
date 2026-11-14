#!/usr/bin/env python3
"""Run the snapshot executable against special files with a bounded deadline."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


class SnapshotSpecialFiles(unittest.TestCase):
    def test_fifo_and_symlink_are_rejected_without_blocking(self) -> None:
        executable = os.environ["BMUX_SNAPSHOT_TEST_BINARY"]
        with tempfile.TemporaryDirectory(prefix="bmux-snapshot-special-", dir="/tmp") as temp:
            root = Path(temp)
            fifo = root / "input.fifo"
            os.mkfifo(fifo)
            link = root / "link"
            link.symlink_to(fifo)
            for path in (fifo, link):
                with self.subTest(path=path.name):
                    try:
                        result = subprocess.run([executable, str(path)], capture_output=True, timeout=1, check=False)
                    except subprocess.TimeoutExpired:
                        self.fail(f"snapshot blocked opening {path.name}")
                    self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))


if __name__ == "__main__":
    unittest.main()
