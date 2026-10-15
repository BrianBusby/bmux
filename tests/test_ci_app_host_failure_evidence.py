#!/usr/bin/env python3
"""Behavioral controls for bounded, private app-host failure evidence."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from test_ci_xcodebuild_exit_reporting import executable, workflow_script

SPEC = importlib.util.spec_from_file_location('evidence', Path(__file__).resolve().parents[1] / 'scripts/ci/app_host_failure_evidence.py')
evidence = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(evidence)


class FakeTools:
    def __init__(self, uuid='a' * 32):
        self.calls = []
        self.uuid = uuid

    def remaining(self):
        return 30

    def run(self, args):
        self.calls.append(args)
        if 'dwarfdump' in args:
            return f'UUID: {self.uuid} (arm64) ignored-private-path'
        if 'atos' in args:
            return 'knownFunction (in app) (/private/secret/file.swift:12)\n'
        if 'summary' in args:
            return json.dumps({'result': 'Failed', 'failedTests': 2, 'environmentDescription': 'SECRET'})
        return json.dumps({'testNodes': [
            {'nodeType': 'Test Suite', 'nodeIdentifier': 'ActualSuite', 'children': [
                {'nodeType': 'Test Case', 'nodeIdentifier': 'ActualSuite/testCase()', 'result': 'Failed', 'children': [
                    {'nodeType': 'Test Case Run', 'name': 'SECRET PARAMETER', 'result': 'Failed'},
                    {'nodeType': 'Failure Message', 'name': 'SECRET MESSAGE'},
                ]},
            ]},
        ]})


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / 'dd'
        self.root.mkdir()
        self.results = self.root / 'Logs/Test'
        self.results.mkdir(parents=True)
        self.products = self.root / 'Build/Products'
        self.products.mkdir(parents=True)
        self.log = Path(self.temp.name) / 'native.log'
        self.log.write_text('')

    def tearDown(self):
        self.temp.cleanup()

    def test_separate_invocations_keep_only_new_results_and_sanitize(self):
        (self.results / 'old.xcresult').mkdir()
        first = Path(self.temp.name) / 'attempt-1'
        evidence.snapshot(self.root, first)
        for name in ('new.xcresult', 'restart.xcresult'):
            (self.results / name).mkdir()
        report = evidence.collect(self.root, self.log, first, 65, FakeTools())
        self.assertEqual(report['event'], 'app_host_failure_evidence')
        self.assertEqual(report['new_result_count'], 2)
        self.assertEqual(len(report['results']), 2)
        self.assertEqual(len(report['results'][0]['tests']), 3)
        self.assertNotIn('SECRET', json.dumps(report))
        self.assertFalse((first / 'state.json').exists())
        second = Path(self.temp.name) / 'attempt-2'
        evidence.snapshot(self.root, second)
        report2 = evidence.collect(self.root, self.log, second, 124, FakeTools())
        self.assertEqual(report2['new_result_count'], 0)
        self.assertEqual(report2['native_exit_code'], 124)

    def test_exhausted_tools_preserve_all_numeric_crashes_and_restarts(self):
        class ExpiredTools(FakeTools):
            def run(self, args):
                raise TimeoutError('diagnostic_budget')
        binary = self.products / 'owned'
        binary.write_bytes(b'owned')
        self.log.write_text((f'Program crashed: signal 11\nThread 0 crashed:\n0 0x1005\n0x1000–0x1010 {"a"*32} app  {binary}\nRestarting after unexpected exit, crash, or test timeout\n') * 2)
        output = Path(self.temp.name) / 'attempt-2-AB1234/capture'
        evidence.snapshot(self.root, output)
        (self.results / 'result.xcresult').mkdir()
        report = evidence.collect(self.root, self.log, output, 65, ExpiredTools())
        self.assertEqual(report['invocation'], 'attempt-2-AB1234')
        self.assertEqual(report['wrapper_attempt'], 2)
        self.assertEqual(len(report['crashes']), 2)
        self.assertEqual(len(report['events']), 2)
        for crash in report['crashes']:
            self.assertEqual(crash['crashed_thread'], 0)
            self.assertEqual(crash['images'][0]['symbolication'], 'TimeoutError')
            self.assertEqual(crash['images'][0]['frames'], [{'offset': '0x5', 'thread': 0, 'symbol': None}])
        self.assertEqual(report['results'][0]['unavailable'], 'TimeoutError')

    def test_invalid_case_never_inherits_suite_as_case_identity(self):
        value = {'testNodes': [{'nodeType': 'Test Suite', 'nodeIdentifier': 'Suite', 'children': [
            {'nodeType': 'Test Case', 'nodeIdentifier': 'payload(secret)', 'children': [
                {'nodeType': 'Test Case Run', 'name': 'SECRET'}]}]}]}
        report = evidence.tests_report(value)
        self.assertEqual(report['tests'], [{'identity': 'Suite', 'kind': 'Test Suite'}])
        self.assertEqual(report['omitted_nodes'], 1)

    def test_parameter_payload_omitted_but_repeated_results_preserved(self):
        report = evidence.tests_report({'testNodes': [{
            'nodeType': 'Test Case', 'nodeIdentifier': 'Suite/case(value:)', 'children': [{
                'nodeType': 'Arguments', 'name': 'SECRET parameter', 'children': [
                    {'nodeType': 'Test Case Run', 'name': 'SECRET run', 'result': 'Failed'},
                    {'nodeType': 'Test Case Run', 'name': 'SECRET run', 'result': 'Passed'},
                ]}]}]})
        self.assertEqual([r.get('result') for r in report['tests']], [None, 'Passed', 'Failed'])
        self.assertEqual({r['identity'] for r in report['tests']}, {'Suite/case(value:)'})
        self.assertNotIn('SECRET', json.dumps(report))

    def test_native_ranges_restart_and_uuid_gate(self):
        binary = self.products / 'app.app/Contents/MacOS/app'
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b'owned')
        self.log.write_text(f'Program crashed: signal 11\n0 0x1005 a\n1 0x2005 b\n0x1000–0x1010 {"a"*32} app  {binary}\nRestarting after unexpected exit, crash, or test timeout\nTime limit was exceeded: SECRET\n')
        crashes, events, limits, _ = evidence.crash_records(self.log, FakeTools())
        self.assertEqual([e['kind'] for e in events], ['runner_restart', 'test_time_limit'])
        tools = FakeTools()
        report = evidence.symbolicate(crashes[0], self.root, tools)
        self.assertEqual(report['images'][0]['frames'], [{'offset': '0x5', 'thread': None, 'symbol': 'knownFunction'}])
        self.assertNotIn('secret', json.dumps(report))
        mismatch = FakeTools('b' * 32)
        report = evidence.symbolicate(crashes[0], self.root, mismatch)
        self.assertEqual(report['images'][0]['symbolication'], 'uuid_mismatch')
        self.assertFalse(any('atos' in call for call in mismatch.calls))
        self.assertFalse(limits['byte_limit_reached'])

    def test_path_escapes_never_reach_tools(self):
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        (outside / 'foreign.xcresult').mkdir()
        self.results.rmdir()
        self.results.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            evidence.snapshot(self.root, Path(self.temp.name) / 'attempt')
        image = self.products / 'escape'
        image.symlink_to(outside)
        tools = FakeTools()
        crash = {'line': 1, 'frames': [{'pc': 1, 'thread': 0}], 'images': [{'path': str(image / 'binary'), 'uuid': 'a'*32, 'base': 0, 'end': 2}]}
        report = evidence.symbolicate(crash, self.root, tools)
        self.assertEqual(report['images'][0]['symbolication'], 'outside_products_or_missing')
        self.assertEqual(tools.calls, [])

    def test_log_and_record_caps(self):
        self.log.write_text('SECRET' * 100 + '\nProgram crashed: signal 11\n')
        with patch.object(evidence, 'MAX_LINE_BYTES', 64):
            crashes, _, limits, _ = evidence.crash_records(self.log, FakeTools())
        self.assertEqual(len(crashes), 1)
        self.assertEqual(limits['oversized_lines_omitted'], 1)
        with patch.object(evidence, 'MAX_LOG_BYTES', 32):
            _, _, limits, _ = evidence.crash_records(self.log, FakeTools())
        self.assertTrue(limits['byte_limit_reached'])
        with patch.object(evidence, 'MAX_RECORDS', 2):
            report = evidence.tests_report({'testNodes': [{'nodeType': 'Test Case', 'nodeIdentifier': 'Case'}] * 10})
        self.assertEqual(len(report['tests']), 2)

    def test_tool_timeout_joins_leader(self):
        pid_file = Path(self.temp.name) / 'pid'
        script = f'import os,signal;open({str(pid_file)!r},"w").write(str(os.getpid()));signal.pause()'
        with self.assertRaises(subprocess.TimeoutExpired):
            evidence.DiagnosticTools(.3).run([sys.executable, '-c', script])
        pid = int(pid_file.read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    def test_wrapper_preserves_native_status_when_collector_fails_or_is_cancelled(self):
        repository = Path(__file__).resolve().parents[1]
        stub = Path(self.temp.name) / 'bin'
        stub.mkdir()
        python = stub / 'python3'
        python.write_text(f"#!/bin/sh\ncase \"$*\" in\n *app_host_failure_evidence.py*collect*) kill -TERM $$;;\n *) exec {sys.executable} \"$@\";;\nesac\n")
        python.chmod(0o755)
        native = stub / 'xcodebuild'
        native.write_text('#!/bin/sh\nexit "$OWNED_NATIVE_STATUS"\n')
        native.chmod(0o755)
        env = {**os.environ, 'PATH': str(stub) + os.pathsep + os.environ['PATH'],
               'RUNNER_TEMP': self.temp.name, 'BMUX_APP_HOST_TEST_LOCK_ACTIVE': '1',
               'BMUX_APP_HOST_XCODEBUILD_ATTEMPTS': '1', 'BMUX_APP_HOST_PROCESS_DIAGNOSTICS': '0'}
        for status in (65, 124):
            env['OWNED_NATIVE_STATUS'] = str(status)
            result = subprocess.run(['bash', str(repository / 'scripts/ci/run-app-host-xcodebuild.sh'),
                                     'test', '-derivedDataPath', str(self.root)],
                                    cwd=repository, env=env, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, status, result.stderr)
            self.assertIn(f'native status remains {status}'.encode(), result.stderr)
        self.assertEqual(list(Path(self.temp.name).glob('bmux-failure-evidence/**/state.json')), [])

    def test_cancelled_tool_is_joined(self):
        child_pid = Path(self.temp.name) / 'child'
        ready = Path(self.temp.name) / 'ready'
        worker = f'import os,signal;open({str(child_pid)!r},"w").write(str(os.getpid()));signal.pause()'
        launcher = f"import sys,signal;sys.path.insert(0,{str(Path(evidence.__file__).parent)!r});import app_host_failure_evidence as e;signal.signal(signal.SIGTERM,lambda *a: (_ for _ in ()).throw(InterruptedError()));open({str(ready)!r},'w').close();e.DiagnosticTools(10).run({[sys.executable, '-c', worker]!r})"
        with tempfile.TemporaryFile() as output:
            parent = subprocess.Popen([sys.executable, '-c', launcher], stdout=output, stderr=output)
            try:
                deadline = time.monotonic() + 3
                while not child_pid.exists() and time.monotonic() < deadline:
                    time.sleep(.01)
                self.assertTrue(child_pid.exists())
                parent.terminate()
                parent.wait(timeout=3)
                with self.assertRaises(ProcessLookupError):
                    os.kill(int(child_pid.read_text()), 0)
            finally:
                if parent.poll() is None:
                    parent.kill()
                parent.wait()

    def test_collection_outside_native_watchdog_preserves_exit(self):
        repository = Path(__file__).resolve().parents[1]
        work = Path(self.temp.name) / 'work'
        scripts = work / 'scripts/ci'
        scripts.mkdir(parents=True)
        for name in ('run-app-host-xcodebuild.sh', 'xcodebuild_noninteractive.py',
                     'app_host_failure_evidence.py'):
            shutil.copy2(repository / 'scripts/ci' / name, scripts / name)
        executable(scripts / 'run-in-console-session.sh', '#!/bin/bash\nexec "$@"\n')
        executable(scripts / 'bmux_unit_test_shard.py',
                   'import sys\nfrom pathlib import Path\nPath(sys.argv[-1]).write_text("-only-testing:bmuxTests/OwnedFixture\\n")\n')
        executable(work / 'bin/xcodebuild', '''#!/usr/bin/env python3
import os
from pathlib import Path
(Path(os.environ['BMUX_DERIVED_DATA_PATH']) / 'Logs/Test/owned.xcresult').mkdir()
print('Owned native failure', flush=True)
raise SystemExit(65)
''')
        # A bounded diagnostic tool crosses the shorter native watchdog. No
        # app, Xcode, external service or duration assertion is used.
        executable(work / 'bin/xcrun', '''#!/usr/bin/env python3
import os, signal
from pathlib import Path
Path(os.environ['OWNED_TOOL_ENTERED']).write_text('entered')
def finish(*_):
    print('{}', flush=True)
    raise SystemExit(0)
signal.signal(signal.SIGALRM, finish)
signal.alarm(2)
signal.pause()
''')
        # Keep the real SECONDS watchdog, with faster bounded predicate polling
        # than the workflow's five-second interval for this owned process graph.
        executable(work / 'bin/sleep',
                   '#!/usr/bin/env python3\nimport select\nselect.select([], [], [], .01)\n')
        entered = Path(self.temp.name) / 'tool-entered'
        env = {**os.environ, 'PATH': str(work / 'bin') + os.pathsep + os.environ['PATH'],
               'RUNNER_TEMP': self.temp.name, 'BMUX_DERIVED_DATA_PATH': str(self.root),
               'BMUX_APP_HOST_TEST_LOCK_ACTIVE': '1', 'BMUX_APP_HOST_XCODEBUILD_ATTEMPTS': '1',
               'BMUX_APP_HOST_PROCESS_DIAGNOSTICS': '0', 'BMUX_UNIT_TEST_TIMEOUT_SECONDS': '1',
               'OWNED_TOOL_ENTERED': str(entered)}
        process = subprocess.Popen(['bash', '-c', workflow_script('ci.yml', 'Run unit tests')],
                                   cwd=work, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            output, _ = process.communicate(timeout=12)
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        # Execute the actual always-step when present. Before the repair,
        # synchronous collection above changes the native result from 65 to 124.
        try:
            collection = workflow_script('ci.yml', 'Collect app-host failure evidence')
        except ValueError:
            collection = ':'
        subprocess.run(['bash', '-c', collection], cwd=work, env=env, check=True, timeout=12)
        self.assertTrue(entered.exists())
        reports = list(Path(self.temp.name).glob('bmux-failure-evidence/**/report.json'))
        self.assertEqual(len(reports), 1)
        self.assertEqual(json.loads(reports[0].read_text())['native_exit_code'], 65)
        self.assertEqual(process.returncode, 65, output.decode(errors='replace'))

    def test_tool_output_limit(self):
        with patch.object(evidence, 'MAX_TOOL_BYTES', 4096):
            with self.assertRaises((RuntimeError, ValueError)):
                evidence.DiagnosticTools(2).run([sys.executable, '-c', 'import os;os.write(1,b"x"*10000)'])


if __name__ == '__main__':
    unittest.main()
