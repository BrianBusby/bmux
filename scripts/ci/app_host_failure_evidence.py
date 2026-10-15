#!/usr/bin/env python3
"""Bounded, sanitized post-failure evidence; never owns the native test result."""
from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import resource
import signal
import subprocess
import sys
import tempfile
import time

BUDGET_SECONDS = 30
MAX_TOOL_BYTES = 8 * 1024 * 1024
MAX_LOG_BYTES = 64 * 1024 * 1024
MAX_LINE_BYTES = 16384
MAX_REPORT_BYTES = 2 * 1024 * 1024
MAX_RECORDS = 2048
MAX_PENDING = 64
MAX_PENDING_LOG_BYTES = 128 * 1024 * 1024
MAX_STATE_BYTES = 2 * 1024 * 1024
MAX_FRAMES = 128
MAX_STRING = 256
IDENTITY = re.compile(r'(?:[A-Za-z_][A-Za-z_0-9]*[./])*[A-Za-z_][A-Za-z_0-9]*(?:\((?:[A-Za-z_][A-Za-z_0-9]*:|_:)*\))?\Z')
RESULTS = {'Passed', 'Failed', 'Skipped', 'Expected Failure', 'unknown'}
IMAGE = re.compile(r'^0x([0-9a-fA-F]{1,16})[–-]0x([0-9a-fA-F]{1,16})\s+([0-9a-fA-F]{32})\s+(.+?)\s{2,}(/.+)$')
FRAME = re.compile(r'^\s*\d+\s+(?:\S+\s+)?0x([0-9a-fA-F]{1,16})(?:\s+.*)?$')


def limited_child_output():
    # This standalone, single-threaded collector launches only owned diagnostic tools.
    resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_TOOL_BYTES, MAX_TOOL_BYTES))


class DiagnosticTools:
    """One absolute budget and joined process groups for post-test tools."""
    def __init__(self, seconds=BUDGET_SECONDS):
        self.deadline = time.monotonic() + seconds

    def remaining(self):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('diagnostic_budget')
        return remaining

    def run(self, args):
        remaining = self.remaining()
        with tempfile.TemporaryFile() as output:
            proc = subprocess.Popen(args, stdout=output, stderr=subprocess.DEVNULL,
                                    start_new_session=True, preexec_fn=limited_child_output)
            try:
                proc.wait(timeout=remaining)
                if proc.returncode != 0:
                    raise RuntimeError('diagnostic_tool_exit')
                if output.tell() >= MAX_TOOL_BYTES:
                    raise ValueError('diagnostic_tool_output_limit')
                output.seek(0)
                return output.read(MAX_TOOL_BYTES).decode('utf-8', errors='replace')
            finally:
                # Includes descendants of a failed/cancelled tool, never the app host.
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()


def contained(path, root):
    resolved = Path(path).resolve()
    return resolved if resolved.is_relative_to(root.resolve()) else None


def identity(value):
    return value if isinstance(value, str) and len(value) <= MAX_STRING and IDENTITY.fullmatch(value) else None


def numeric(value):
    return value if type(value) in (int, float) and 0 <= value <= 1e18 and math.isfinite(value) else None


def result_bundles(root):
    directory = contained(root / 'Logs' / 'Test', root)
    if directory is None:
        raise ValueError('result_directory_escape')
    names = []
    if directory.is_dir():
        with os.scandir(directory) as entries:
            for count, entry in enumerate(entries):
                if count >= MAX_RECORDS:
                    raise ValueError('result_directory_entry_limit')
                if entry.name.endswith('.xcresult') and entry.is_dir() and contained(entry.path, directory):
                    names.append(entry.name)
                    if len(names) > MAX_RECORDS:
                        raise ValueError('result_count_limit')
    return sorted(names)


def snapshot(root, output):
    if len(pending_outputs(output.parent.parent)) >= MAX_PENDING:
        raise ValueError('pending_attempt_limit')
    output.mkdir(parents=True, exist_ok=False)
    state = {'before': result_bundles(root), 'started': time.monotonic(), 'root': str(root.resolve())}
    (output / 'state.json').write_text(json.dumps(state))


def pending_outputs(directory):
    outputs = []
    if directory.exists():
        with os.scandir(directory) as entries:
            for index, entry in enumerate(entries):
                if index >= MAX_RECORDS:
                    raise ValueError('pending_directory_limit')
                if not re.fullmatch(r'attempt-\d+-[A-Za-z0-9]+', entry.name):
                    continue
                output = Path(entry.path) / 'capture'
                if output.is_dir() and contained(output, directory) is not None and not entry.is_symlink() and not output.is_symlink():
                    outputs.append(output)
                if len(outputs) > MAX_PENDING:
                    raise ValueError('pending_attempt_limit')
    return sorted(outputs)


def defer_collection(root, log, output, status):
    """Freeze only this attempt's bounded private evidence; never launch tools."""
    if status == 0:
        (output / 'state.json').unlink(missing_ok=True)
        return
    outputs = pending_outputs(output.parent.parent)
    used = sum((p / 'native.log').stat().st_size for p in outputs if (p / 'native.log').is_file())
    remaining = min(MAX_LOG_BYTES, max(0, MAX_PENDING_LOG_BYTES - used))
    state = json.loads((output / 'state.json').read_text())
    state.update(status=status, elapsed=max(0, time.monotonic() - state['started']),
                 bundles=[name for name in result_bundles(root) if name not in state['before']],
                 log_bytes=log.stat().st_size, retained_log_bytes=min(log.stat().st_size, remaining))
    with open(log, 'rb') as source, open(output / 'native.log', 'wb') as target:
        while remaining:
            block = source.read(min(1024 * 1024, remaining))
            if not block:
                break
            target.write(block)
            remaining -= len(block)
    (output / 'state.json').write_text(json.dumps(state))


def collect_pending(directory, tools=None):
    """Parse every attempt before tools consume the single post-step budget."""
    tools = tools or DiagnosticTools()
    outputs = pending_outputs(directory)
    pending = []
    try:
        for output in outputs:
            state_path, log = output / 'state.json', output / 'native.log'
            if not state_path.is_file():
                continue
            pending.append((output, None, None))
            try:
                if state_path.stat().st_size > MAX_STATE_BYTES:
                    raise ValueError('pending_state_limit')
                state = json.loads(state_path.read_text())
                if not isinstance(state.get('root'), str) or not Path(state['root']).is_absolute():
                    raise ValueError('pending_root_invalid')
                parsed = crash_records(log, tools) if log.is_file() else ([], [], {'unavailable': True}, [])
                pending[-1] = (output, state, parsed)
            except (OSError, ValueError, KeyError) as error:
                (output / 'report.json').write_text(json.dumps({'event': 'app_host_failure_evidence',
                    'invocation': output.parent.name, 'errors': [type(error).__name__]}))
        for output, state, parsed in pending:
            if state is not None:
                collect(Path(state['root']), output / 'native.log', output, state.get('status'), tools, parsed)
    finally:
        # Includes cancellation: pending files stay private and are never uploaded.
        for output in outputs:
            (output / 'state.json').unlink(missing_ok=True)
            (output / 'native.log').unlink(missing_ok=True)


def summary_report(value):
    if not isinstance(value, dict):
        raise ValueError('summary_schema')
    report = {key: value[key] for key in ('result',) if value.get(key) in RESULTS}
    for key in ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests', 'expectedFailures', 'startTime', 'finishTime'):
        if numeric(value.get(key)) is not None:
            report[key] = value[key]
    return report


def tests_report(value):
    if not isinstance(value, dict) or not isinstance(value.get('testNodes'), list):
        raise ValueError('tests_schema')
    records, omitted = [], 0
    roots = value['testNodes']
    omitted = max(0, len(roots) - MAX_RECORDS)
    pending = [(node, None) for node in roots[:MAX_RECORDS]]
    visited = 0
    while pending and visited < MAX_RECORDS:
        node, parent = pending.pop()
        visited += 1
        if not isinstance(node, dict):
            omitted += 1
            continue
        kind = node.get('nodeType')
        if kind in ('Failure Message', 'Source Code Reference', 'Attachment', 'Expression', 'Test Value', 'Runtime Warning'):
            omitted += 1
            continue
        if kind == 'Arguments':
            omitted += 1  # Omit its display/payload, but retain child run results by case identity.
        own = identity(node.get('nodeIdentifier')) if kind in ('Test Suite', 'Test Case') else None
        owner = own if kind in ('Test Suite', 'Test Case') else parent
        case_owner = own if kind == 'Test Case' else parent if kind not in ('Test Suite', 'Test Case') else None
        if owner and kind in ('Test Suite', 'Test Case', 'Repetition', 'Test Case Run'):
            item = {'identity': owner, 'kind': kind}
            if node.get('result') in RESULTS:
                item['result'] = node['result']
            if numeric(node.get('durationInSeconds')) is not None:
                item['duration_seconds'] = node['durationInSeconds']
            records.append(item)
        elif kind in ('Test Suite', 'Test Case'):
            omitted += 1  # Never fall back to parameterized display names.
        remaining = MAX_RECORDS - visited - len(pending)
        children = node.get('children', [])
        if not isinstance(children, list):
            omitted += 1
            continue
        pending.extend((child, case_owner) for child in children[:max(0, remaining)])
        omitted += max(0, len(children) - max(0, remaining))
    return {'tests': records, 'omitted_nodes': omitted + len(pending)}


def crash_records(log, tools):
    """Parse native numeric frames, keeping restart and deadline events distinct."""
    crashes, events, current = [], [], None
    lines, consumed, oversized, omitted = 0, 0, 0, 0
    dropped = {'events': 0, 'crashes': 0, 'images': 0}
    result_paths = []
    budget_expired = False
    thread, crashed_thread = None, False
    with open(log, 'rb') as source:
        while consumed < MAX_LOG_BYTES:
            try:
                tools.remaining()
            except TimeoutError:
                budget_expired = True
                break
            raw = source.readline(min(MAX_LINE_BYTES + 1, MAX_LOG_BYTES - consumed))
            if not raw:
                break
            consumed += len(raw)
            lines += 1
            if len(raw) > MAX_LINE_BYTES:
                oversized += 1
                while raw and not raw.endswith(b'\n') and consumed < MAX_LOG_BYTES:
                    try:
                        tools.remaining()
                    except TimeoutError:
                        budget_expired = True
                        break
                    raw = source.readline(min(MAX_LINE_BYTES, MAX_LOG_BYTES - consumed))
                    consumed += len(raw)
                continue
            line = raw.decode('utf-8', errors='replace').rstrip('\n')
            # GitHub archives add a timestamp; the wrapper's own log does not.
            line = re.sub(r'^\d{4}-\d\d-\d\dT\S+Z ', '', line)
            if line.strip().startswith('/') and line.strip().endswith('.xcresult') and len(result_paths) < 8:
                result_paths.append(line.strip())
            if 'Restarting after unexpected exit, crash, or test timeout' in line:
                if len(events) < MAX_RECORDS:
                    events.append({'kind': 'runner_restart', 'line': lines})
                else:
                    dropped['events'] += 1
                current = None
            elif 'Time limit was exceeded:' in line:
                if len(events) < MAX_RECORDS:
                    events.append({'kind': 'test_time_limit', 'line': lines})
                else:
                    dropped['events'] += 1
            if 'Program crashed:' in line and len(crashes) < 16:
                current = {'line': lines, 'frames': [], 'crashed_frames': [], 'images': []}
                thread, crashed_thread = None, False
                crashes.append(current)
            elif 'Program crashed:' in line:
                dropped['crashes'] += 1
                current = None
            if current is None:
                continue
            thread_match = re.fullmatch(r'Thread (\d{1,9})( crashed)?:', line.strip())
            if thread_match:
                thread, crashed_thread = int(thread_match[1]), bool(thread_match[2])
                if crashed_thread:
                    current['crashed_thread'] = thread
            image = IMAGE.fullmatch(line.strip())
            if image and len(current['images']) < 128:
                current['images'].append({'base': int(image[1], 16), 'end': int(image[2], 16), 'uuid': image[3].lower(), 'path': image[5]})
            elif image:
                dropped['images'] += 1
            frame = FRAME.match(line)
            if frame:
                target = current['crashed_frames'] if crashed_thread else current['frames']
                if len(target) < MAX_FRAMES:
                    target.append({'pc': int(frame[1], 16), 'thread': thread})
                else:
                    omitted += 1
    return crashes, events, {'bytes_examined': consumed, 'budget_expired': budget_expired, 'oversized_lines_omitted': oversized, 'frames_omitted': omitted, 'byte_limit_reached': consumed >= MAX_LOG_BYTES, 'records_omitted': dropped}, result_paths


def symbolicate(crash, root, tools):
    products = contained(root / 'Build' / 'Products', root)
    records = []
    for image in crash['images']:
        path = contained(image['path'], products) if products else None
        # Only executable images already reported by this exact native crash.
        role = 'tests' if '.xctest/' in str(path) else 'app' if '.app/Contents/MacOS/' in str(path) else 'other'
        record = {'role': role, 'uuid': image['uuid'], 'base': hex(image['base'])}
        frames = [f for f in crash.get('crashed_frames', []) + crash['frames'] if image['base'] <= f['pc'] < image['end']]
        pcs = sorted({f['pc'] for f in frames})
        record['frames'] = [{'offset': hex(f['pc'] - image['base']), 'thread': f['thread'], 'symbol': None} for f in frames]
        if path is None or not path.is_file():
            record['symbolication'] = 'outside_products_or_missing'
            records.append(record)
            continue
        try:
            uuids = tools.run(['xcrun', 'dwarfdump', '--uuid', str(path)])
            match = next((m for m in re.finditer(r'UUID: ([A-Fa-f0-9-]+) \(([^)]+)\)', uuids)
                          if m[1].replace('-', '').lower() == image['uuid'] and m[2] in ('arm64', 'arm64e', 'x86_64')), None)
            if match is None:
                record['symbolication'] = 'uuid_mismatch'
            else:
                record['architecture'] = match[2]
                if pcs:
                    symbols = tools.run(['xcrun', 'atos', '-o', str(path), '-arch', match[2], '-l', hex(image['base']), *map(hex, pcs)])
                    resolved = {}
                    for pc, text in zip(pcs, symbols.splitlines()):
                        # Strip source/path information; never preserve tool diagnostic text.
                        symbol = text.split(' (in ')[0].split(' (')[0]
                        safe = bool(symbol) and symbol.isprintable() and len(symbol) <= MAX_STRING and '/' not in symbol and '\\' not in symbol and not symbol.startswith(('0x', 'atos:'))
                        resolved[hex(pc - image['base'])] = symbol if safe else None
                    for frame in record['frames']:
                        frame['symbol'] = resolved.get(frame['offset'])
                record['symbolication'] = 'checked'
        except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired, TimeoutError) as error:
            record['symbolication'] = type(error).__name__
        records.append(record)
    return {'line': crash['line'], 'crashed_thread': crash.get('crashed_thread'), 'images': records}


def collect(root, log, output, status, tools=None, parsed=None):
    tools = tools or DiagnosticTools()
    report = {'event': 'app_host_failure_evidence', 'schema': 1, 'native_exit_code': status, 'invocation': output.parent.name if re.fullmatch(r'attempt-\d+-[A-Za-z0-9]+', output.parent.name) else 'unavailable',
              'results': [], 'crashes': [], 'events': [], 'errors': []}
    attempt = re.match(r'attempt-(\d+)-', output.parent.name)
    if attempt:
        report['wrapper_attempt'] = int(attempt[1])
    shard = re.search(r'(?:shard|apphost)[-_]?(\d+)$', root.name)
    if shard:
        report['shard'] = int(shard[1])
    job = identity(os.environ.get('GITHUB_JOB'))
    if job:
        report['github_job'] = job
    for key in ('GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT'):
        value = os.environ.get(key, '')
        if value.isdecimal() and len(value) <= 32:
            report[key.lower()] = value
    sha = os.environ.get('GITHUB_SHA', '')
    if re.fullmatch('[a-fA-F0-9]{40}', sha):
        report['workflow_sha'] = sha.lower()
    try:
        state = json.loads((output / 'state.json').read_text())
        report['elapsed_seconds'] = state.get('elapsed', max(0, time.monotonic() - state['started']))
        if status is None:
            report['errors'].append('native_status_unavailable')
        # Parse numeric crash/restart evidence before tools can consume the budget.
        crashes, report['events'], report['log_limits'], result_paths = parsed if parsed is not None else crash_records(log, tools)
        if 'retained_log_bytes' in state:
            report['log_limits'].update(original_bytes=state['log_bytes'], retained_bytes=state['retained_log_bytes'])
        for crash in crashes:
            report['crashes'].append(symbolicate(crash, root, tools))
        if 'bundles' in state:
            bundles = state['bundles']
        else:
            bundles = [] if status is None else [name for name in result_bundles(root) if name not in state['before']]
        report['new_result_count'] = len(bundles)
        owned_paths = {contained(root / 'Logs' / 'Test' / name, root) for name in bundles}
        report['log_result_references'] = len(result_paths)
        report['log_result_matches_new_bundles'] = sum(contained(path, root) in owned_paths for path in result_paths)
        for index, name in enumerate(bundles[:8]):
            result = {'index': index}
            try:
                path = contained(root / 'Logs' / 'Test' / name, root)
                if path is None or not path.is_dir():
                    raise ValueError('result_path_escape')
                for operation, extract in (('summary', summary_report), ('tests', tests_report)):
                    raw = tools.run(['xcrun', 'xcresulttool', 'get', 'test-results', operation, '--path', str(path), '--compact'])
                    result.update(extract(json.loads(raw)))
            except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired, TimeoutError) as error:
                result['unavailable'] = type(error).__name__
            report['results'].append(result)
        report['omitted_results'] = max(0, len(bundles) - 8)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired, TimeoutError) as error:
        report['errors'].append(type(error).__name__)
    finally:
        encoded = json.dumps(report, indent=2)
        if len(encoded.encode()) > MAX_REPORT_BYTES:
            report['results'] = []
            report['crashes'] = []
            report['events'] = []
            report['errors'].append('report_byte_limit')
            encoded = json.dumps(report)
        (output / 'report.json').write_text(encoded + '\n')
        (output / 'state.json').unlink(missing_ok=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('snapshot', 'defer', 'collect', 'collect-pending'))
    parser.add_argument('--root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--log', type=Path)
    parser.add_argument('--status', type=int)
    args = parser.parse_args()
    def cancelled(_sig, _frame):
        raise InterruptedError('diagnostic_cancelled')
    signal.signal(signal.SIGTERM, cancelled)
    signal.signal(signal.SIGINT, cancelled)
    try:
        if args.phase == 'collect-pending':
            collect_pending(args.output)
        elif args.root is None:
            parser.error('--root is required for attempt operations')
        elif args.phase == 'snapshot':
            snapshot(args.root, args.output)
        else:
            if args.log is None or args.status is None:
                parser.error('collect/defer requires --log and --status')
            if args.phase == 'defer':
                defer_collection(args.root, args.log, args.output, args.status)
                return 0
            report = collect(args.root, args.log, args.output, args.status)
            if report['errors'] or any('unavailable' in r for r in report['results']):
                print('App-host failure evidence incomplete; see sanitized report', file=sys.stderr)
    except (OSError, ValueError) as error:
        print('App-host failure evidence unavailable: ' + type(error).__name__, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
