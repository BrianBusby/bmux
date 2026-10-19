#!/usr/bin/env python3
"""Executable process ownership/status tests; never attach to an app."""
import importlib
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/ci'))
diag = importlib.import_module('app_host_process_diagnostics')
snapshot = importlib.import_module('app_host_process_snapshot')


def record(pid, parent, path, birth=(1, 2)):
    return dict(pid=pid, ppid=parent, state=2, path=str(path), birth=birth)


class DiagnosticsTests(unittest.TestCase):
    def test_exact_path_and_descendants_only(self):
        root = Path('/owned/DerivedData')
        app = root / 'Build/Products/Debug/bmux DEV.app/Contents'
        host, cli = app / 'MacOS/bmux DEV', app / 'Resources/bin/bmux'
        records = {1: record(1, 0, host), 2: record(2, 1, '/bin/sh'),
                   3: record(3, 2, cli), 4: record(4, 0, cli),
                   5: record(5, 1, str(cli) + '-other'),
                   6: record(6, 1, '/unrelated/bmux'),
                   7: record(7, 8, cli), 8: record(8, 7, '/bin/sh')}
        self.assertEqual(set(snapshot.selected_processes(records, root)), {1, 3})
        self.assertEqual(snapshot.selected_processes(records, Path('/other')), {})

    def test_stack_output_discards_headers_dynamic_labels_paths_and_footer(self):
        raw = b'''Process: secret-argv
Path: /private/secret
Call graph:
    100 Thread_12: DispatchQueue_secret-payload
    + 100 a_symbol (in bmux) + 12 [0x123]
    + 20 secret_label
    + 12 file_symbol (in /secret/path)
    + 4 another_symbol (in libdispatch.dylib) + 8
Total number in stack: secret-footer
Binary Images: secret-binaries
'''
        result = diag.stack_only(raw)
        self.assertIn('a_symbol', result)
        self.assertIn('another_symbol', result)
        self.assertNotIn('secret', result)
        self.assertLessEqual(len(diag.stack_only(raw * 10000).encode()), diag.MAX_STACK_BYTES)

    def test_real_command_status_and_observer_join(self):
        for status in (0, 65, 124, 125):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as name:
                root = Path(name).resolve()
                stopped = root / 'stopped'
                def observer(fd):
                    return [sys.executable, '-c',
                            'import os,sys; from pathlib import Path; '
                            'os.read(int(sys.argv[1]),1); Path(sys.argv[2]).write_text("joined")',
                            str(fd), str(stopped)]
                result = diag.run([sys.executable, '-c', f'raise SystemExit({status})'],
                                  root, root / 'log', root / 'out', observer)
                self.assertEqual(result, status)
                self.assertEqual(stopped.read_text(), 'joined')

    def test_sampler_failure_and_output_failure_preserve_native_failure(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve()
            command = [sys.executable, '-c', 'raise SystemExit(65)']
            self.assertEqual(diag.run(command, root, root/'log', root/'out',
                                     lambda fd: ['/does-not-exist']), 65)
            self.assertEqual((root/'out/sampler-error.txt').read_text(), 'FileNotFoundError\n')
            self.assertEqual(diag.run(command, root, root/'log', root/'out'), 65)

    def test_native_signal_status_is_preserved(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve()
            result = diag.run([sys.executable, '-c', 'import os,signal; os.kill(os.getpid(),signal.SIGTERM)'],
                              root, root/'log', root/'out', lambda fd: [sys.executable, '-c', 'pass'])
            self.assertEqual(result, 128 + signal.SIGTERM)

    def test_wedged_observer_is_killed_without_replacing_native_status(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve()
            fifo = root / 'ready'
            pid_file = root / 'observer-pid'
            os.mkfifo(fifo)
            def observer(fd):
                return [sys.executable, '-c',
                        'import os,signal,sys,subprocess; from pathlib import Path; '
                        'child=subprocess.Popen([sys.executable,"-c","import signal; signal.pause()"]); '
                        'signal.signal(signal.SIGTERM,signal.SIG_IGN); '
                        'Path(sys.argv[2]).write_text(str(os.getpid())+"\\n"+str(child.pid)); '
                        'f=open(sys.argv[1],"w"); f.write("ready"); f.close(); '
                        'child.wait(); signal.pause()', str(fifo), str(pid_file)]
            command = [sys.executable, '-c',
                       'import sys; open(sys.argv[1]).read(); raise SystemExit(65)', str(fifo)]
            self.assertEqual(diag.run(command, root, root/'log', root/'out', observer), 65)
            for pid in map(int, pid_file.read_text().splitlines()):
                with self.assertRaises(ProcessLookupError): os.kill(pid, 0)

    def test_opted_in_wrapper_preserves_failure_and_unique_artifacts(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve()
            tool = root/'xcodebuild'
            tool.write_text('#!/bin/sh\necho "SocketControlServer: Listening on /owned.sock"\nexit 65\n')
            tool.chmod(0o755)
            environment = {**os.environ, 'PATH': str(root)+os.pathsep+os.environ['PATH'],
                           'RUNNER_TEMP': str(root), 'BMUX_APP_HOST_PROCESS_DIAGNOSTICS': '1',
                           'BMUX_APP_HOST_TEST_LOCK_FILE': str(root/'lock')}
            for _ in range(2):
                result = subprocess.run(['bash', 'scripts/ci/run-app-host-xcodebuild.sh',
                                         '-derivedDataPath', str(root/'DerivedData'), 'test'],
                                        cwd=ROOT, env=environment, capture_output=True, timeout=15)
                self.assertEqual(result.returncode, 65, result.stderr.decode())
            self.assertEqual(len(list((root/'bmux-process-diagnostics').glob('attempt-*/capture'))), 2)

    def test_forced_stop_kills_worker_after_observer_exits_on_term(self):
        child = ('import signal; signal.signal(signal.SIGTERM,signal.SIG_IGN); '
                 'print("worker-ready",flush=True); signal.pause()')
        owner = ('import subprocess,sys; '
                 'subprocess.Popen([sys.executable,"-c",sys.argv[1]]).wait()')
        observer = subprocess.Popen([sys.executable, '-c', owner, child],
                                    stdout=subprocess.PIPE, start_new_session=True)
        try:
            self.assertTrue(select.select([observer.stdout], [], [], 5)[0])
            self.assertEqual(observer.stdout.readline(), b'worker-ready\n')
            self.assertEqual(diag.stop_observer(observer), -signal.SIGTERM)
            # EOF proves the TERM-ignoring worker released its inherited descriptor.
            self.assertTrue(select.select([observer.stdout], [], [], 5)[0])
            self.assertEqual(observer.stdout.read(), b'')
        finally:
            try: os.killpg(observer.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            observer.wait()
            observer.stdout.close()

    def test_delayed_log_creation_does_not_disable_observation(self):
        original_open = open
        attempted = []
        def delayed_open(path, *args, **kwargs):
            if Path(path).name == 'log' and not attempted:
                attempted.append(True)
                raise FileNotFoundError('not created yet')
            return original_open(path, *args, **kwargs)
        with mock.patch.object(diag, 'open', side_effect=delayed_open, create=True):
            self.run_observation()
        self.assertEqual(attempted, [True])

    def run_observation(self, change_birth=False, expire=False):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name).resolve()
            app = root / 'Build/Products/Debug/bmux DEV.app/Contents'
            records = {1: record(1, 0, app/'MacOS/bmux DEV')}
            records.update({pid: record(pid, 1, app/'Resources/bin/bmux') for pid in range(2, 14)})
            class Backend:
                calls = 0
                def snapshot(self):
                    self.calls += 1
                    if expire:
                        clock[0] += 31
                    if change_birth:
                        return {pid: {**item, 'birth': (self.calls, 0)} for pid, item in records.items()}
                    return records
                def metrics(self, item):
                    return dict(cpu_nanoseconds=10, threads=2, elapsed_seconds=1)
            log = root/'log'
            log.write_bytes('◇ Test run started.\n'.encode())
            output = root/'out'
            output.mkdir()
            read_fd, write_fd = os.pipe()
            fifo = root/'ready'
            os.mkfifo(fifo)
            ready = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
            errors, clock = [], [0.0]
            def command(pid):
                return [sys.executable, '-c',
                        'import os,sys; '
                        'f=open(sys.argv[1],"w"); f.write(str(os.getpid())+"\\n"); f.close(); '
                        'print("Call graph:\\n + 1 owned_frame (in fixture) + 4\\nBinary Images: secret")',
                        str(fifo)]
            def observe():
                try:
                    diag.watch(root, log, output, read_fd, Backend(), command)
                except BaseException as error:
                    errors.append(error)
            with mock.patch.object(diag.time, 'monotonic', side_effect=lambda: clock[0]) if expire else mock.patch.object(diag, 'WINDOW_SECONDS', 1 if change_birth else 30):
                thread = threading.Thread(target=observe)
                thread.start()
                try:
                    if not (change_birth or expire):
                        received = b''
                        while len(received.splitlines()) < 8:
                            self.assertTrue(select.select([ready], [], [], 5)[0], f'sample readiness: {errors}, alive={thread.is_alive()}, {(output / "processes.jsonl").read_text()}')
                            received += os.read(ready, 4096)
                    else:
                        thread.join(5)
                        self.assertFalse(thread.is_alive())
                finally:
                    os.close(write_fd)
                    thread.join(5)
                    os.close(read_fd)
                    os.close(ready)
            self.assertFalse(thread.is_alive())
            self.assertEqual(errors, [])
            events = [json.loads(line) for line in (output/'processes.jsonl').read_text().splitlines()]
            starts = [event for event in events if event['event'] == 'sample_started']
            self.assertEqual(len(starts), 0 if change_birth or expire else 8)
            self.assertEqual(events[-1]['event'], 'stopped')
            live = 0
            for event in events:
                if event['event'] == 'sample_started': live += 1
                if event['event'] == 'sample_finished': live -= 1
                self.assertLessEqual(live, 2)
            for path in output.glob('stack-*.txt'):
                self.assertNotIn('secret', path.read_text())
            if not (change_birth or expire):
                for pid in map(int, received.splitlines()):
                    with self.assertRaises(ProcessLookupError): os.kill(pid, 0)

    def test_bounded_real_sample_workers_are_joined(self):
        self.run_observation()

    def test_pid_reuse_excludes_sample(self):
        self.run_observation(change_birth=True)

    def test_window_expiry_prevents_sample_after_discovery(self):
        self.run_observation(expire=True)


if __name__ == '__main__':
    unittest.main()
