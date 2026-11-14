#!/usr/bin/env python3
"""Run the snapshot executable against special files with a bounded deadline."""
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


class SnapshotSpecialFiles(unittest.TestCase):
    def test_newline_heavy_snapshot_has_bounded_memory(self) -> None:
        executable = os.environ["BMUX_SNAPSHOT_TEST_BINARY"]
        meta = b'{"type":"session_meta","payload":{"id":"session-a"}}\n'
        with tempfile.TemporaryDirectory(prefix="bmux-snapshot-memory-", dir="/tmp") as temp:
            path = Path(temp) / "source.jsonl"
            path.write_bytes(meta + b"\n" * (4 * 1024 * 1024 - len(meta)))
            process = subprocess.Popen([executable, str(path), "verified"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            peak_kib = 0
            start = time.monotonic()
            try:
                while process.poll() is None:
                    if time.monotonic() - start > 15:
                        self.fail("snapshot exceeded 15 seconds")
                    sample = subprocess.run(["ps", "-o", "rss=", "-p", str(process.pid)], capture_output=True, text=True)
                    if sample.stdout.strip():
                        peak_kib = max(peak_kib, int(sample.stdout.strip()))
                        if peak_kib > 192 * 1024:
                            self.fail(f"snapshot exceeded 192 MiB RSS: {peak_kib} KiB")
                    time.sleep(0.01)
                self.assertEqual(process.returncode, 0, process.stderr.read().decode(errors="replace"))
                print(f"newline-heavy peak sampled RSS: {peak_kib} KiB")
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
                process.stderr.close()

    def test_excessive_record_count_is_unknown(self) -> None:
        executable = os.environ["BMUX_SNAPSHOT_TEST_BINARY"]
        meta = b'{"type":"session_meta","payload":{"id":"session-a"}}\n'
        event = b'{"type":"event_msg","payload":{}}\n'
        with tempfile.TemporaryDirectory(prefix="bmux-snapshot-count-", dir="/tmp") as temp:
            path = Path(temp) / "source.jsonl"
            path.write_bytes(meta + event * 8191)
            at_limit = subprocess.run([executable, str(path), "verified"], capture_output=True, timeout=15, check=False)
            self.assertEqual(at_limit.returncode, 0, at_limit.stderr.decode(errors="replace"))
            path.write_bytes(meta + event * 8192)
            result = subprocess.run([executable, str(path)], capture_output=True, timeout=15, check=False)
            self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))

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
