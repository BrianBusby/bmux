#!/usr/bin/env python3
"""Opt-in, bounded app-host observation. The wrapped command owns its result."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import select
import signal
import subprocess
import sys
import tempfile
import time

from app_host_process_snapshot import MacProcesses, selected_processes

WINDOW_SECONDS = 30
MAX_SAMPLES = 8
MAX_CONCURRENT = 2
MAX_STACK_BYTES = 256 * 1024
SAMPLE_WORKER_TIMEOUT_SECONDS = 5  # Includes symbol processing after the one-second sample.
SGR = re.compile(rb'\x1b\[[0-9;:]*m')


def stack_only(raw):
    """Discard sample's command/path header and binary image inventory."""
    text = raw.decode('utf-8', errors='replace')
    start = text.find('Call graph:')
    if start < 0:
        return 'No call graph available.\n'
    frames = []
    # sample's thread/dispatch-queue labels are dynamic. Keep only counted
    # symbol frames with an image identity; discard source paths and all labels.
    for line in text[start:].splitlines()[1:]:
        if line.startswith(('Total number', 'Binary Images:', 'Sort by')):
            break
        if not re.match(r'^[ +!:|]*[0-9]+ +.+ \(in [^/\\]+\)', line):
            continue
        if 'Thread_' in line or 'DispatchQueue_' in line or 'thread name' in line.lower():
            continue
        line = line.split('  [')[0]
        # Image/symbol lines containing paths are outside the output contract.
        if '/' not in line and '\\' not in line:
            frames.append(line)
    return ('\n'.join(frames) + '\n').encode()[:MAX_STACK_BYTES].decode('utf-8', errors='ignore')


def emit(file, **record):
    file.write(json.dumps(record) + '\n')
    file.flush()


def watch(root, log_path, output, stop_fd, backend=None, sample_command=None):
    backend = backend or MacProcesses()
    sample_command = sample_command or (lambda pid: ['/usr/bin/sample', str(pid), '1', '10', '-mayDie', '-file', '/dev/stdout'])
    workers, sampled, first_seen = [], set(), {}
    pending, offset, deadline = b'', 0, None
    with open(output / 'processes.jsonl', 'w') as events:
        emit(events, event='ready', window_seconds=WINDOW_SECONDS, max_samples=MAX_SAMPLES, cli_min_age_seconds=1, host_min_age_seconds=2)
        try:
            while True:
                if select.select([stop_fd], [], [], 0.25)[0]:
                    break
                if deadline is None:
                    try:
                        log = open(log_path, 'rb')
                    except FileNotFoundError:
                        continue
                    with log:
                        log.seek(0, os.SEEK_END)
                        end = log.tell()
                        # Read the fresh tail even if compile output outpaces observation.
                        log.seek(max(offset, end - 4 * 1024 * 1024))
                        chunk = log.read(4 * 1024 * 1024)
                        offset = log.tell()
                    lines = (pending + chunk).split(b'\n')
                    pending = lines.pop()[-4096:]
                    if any('◇ Test run started.'.encode() in SGR.sub(b'', line) for line in lines):
                        deadline = time.monotonic() + WINDOW_SECONDS
                        emit(events, event='window_started')
                    else:
                        continue
                now = time.monotonic()
                if now >= deadline:
                    break
                records = backend.snapshot()
                selected = selected_processes(records, root)
                for pid, item in selected.items():
                    emit(events, event='process', monotonic=now, pid=pid, ppid=item['ppid'],
                         state=item['state'], role=item['role'], **backend.metrics(item))
                for worker in workers[:]:
                    proc, capture, identity, started = worker
                    if proc.poll() is None and now - started < SAMPLE_WORKER_TIMEOUT_SECONDS:
                        continue
                    if proc.poll() is None:
                        proc.kill()
                    status = proc.wait()
                    workers.remove(worker)
                    try:
                        capture.seek(0)
                        (output / f'stack-{identity[0]}-{started:.6f}.txt').write_text(stack_only(capture.read(2 * 1024 * 1024)))
                    finally:
                        capture.close()
                    emit(events, event='sample_finished', pid=identity[0], status=status)
                for pid, item in selected.items():
                    identity = (pid, tuple(item['birth']))
                    first_seen.setdefault(identity, now)
                    # Avoid spending the stack budget on successful short-lived CLI calls.
                    if now - first_seen[identity] < (1 if item['role'] == 'cli' else 2):
                        continue
                    if identity in sampled or len(sampled) >= MAX_SAMPLES or len(workers) >= MAX_CONCURRENT:
                        continue
                    # Revalidate path, birth and ancestry immediately before observing.
                    current = selected_processes(backend.snapshot(), root).get(pid)
                    if current != item or time.monotonic() >= deadline:
                        continue
                    capture = tempfile.TemporaryFile()  # Unlinked: raw headers never enter artifacts.
                    try:
                        proc = subprocess.Popen(sample_command(pid), stdout=capture, stderr=subprocess.DEVNULL)
                    except OSError:
                        capture.close()
                        raise
                    sampled.add(identity)
                    workers.append((proc, capture, identity, now))
                    emit(events, event='sample_started', pid=pid, role=item['role'])
        finally:
            for proc, capture, identity, _ in workers:
                try:
                    if proc.poll() is None:
                        proc.kill()
                    proc.wait()
                    capture.seek(0)
                    (output / f'stack-{identity[0]}-stopped.txt').write_text(stack_only(capture.read(2 * 1024 * 1024)))
                except OSError as error:
                    report_error(output, type(error).__name__)
                finally:
                    capture.close()
            emit(events, event='stopped', samples=len(sampled))


def report_error(output, message):
    print('Process diagnostics unavailable: ' + message, file=sys.stderr)
    try:
        (output / 'sampler-error.txt').write_text(message + '\n')
    except OSError:
        pass  # The diagnostic error is reported above; native status stays authoritative.


def stop_observer(observer):
    # This group contains only our observer/sample helpers, never the test command.
    forced = False
    try:
        for timeout, next_signal in ((3, signal.SIGTERM), (0.5, signal.SIGKILL), (1, None)):
            try:
                return observer.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                if next_signal is not None:
                    forced = True
                    try:
                        os.killpg(observer.pid, next_signal)
                    except ProcessLookupError:
                        pass
        return 124
    finally:
        # The leader may exit on TERM while a sample worker ignores it.
        if forced:
            try:
                os.killpg(observer.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass


def run(command, root, log_path, output, observer_command=None):
    try:
        output.mkdir(parents=True, exist_ok=False)
    except OSError:
        print('Process diagnostics unavailable: output directory', file=sys.stderr)
        status = subprocess.call(command)
        return status if status >= 0 else 128 - status
    read_fd, write_fd = os.pipe()
    observer = None
    proc = subprocess.Popen(command)
    previous = {}
    def forward(sig, frame):
        try:
            proc.send_signal(sig)
        except ProcessLookupError:
            pass
    try:
        for signum in (signal.SIGTERM, signal.SIGINT):
            previous[signum] = signal.signal(signum, forward)
        try:
            observer_args = [sys.executable, __file__, '--watch', str(read_fd),
                             '--root', str(root), '--log', str(log_path), '--output', str(output)]
            observer = subprocess.Popen(observer_command(read_fd) if observer_command else observer_args,
                                        pass_fds=(read_fd,), stdout=subprocess.DEVNULL,
                                        stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as error:
            report_error(output, type(error).__name__)
        finally:
            os.close(read_fd)
        status = proc.wait()
    finally:
        os.close(write_fd)  # EOF also stops observation if this runner is killed.
        if observer is not None:
            observer_status = stop_observer(observer)
            if observer_status:
                report_error(output, f'Observer exited {observer_status}')
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    return status if status >= 0 else 128 - status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--log', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--watch', type=int)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.watch is not None:
        try:
            watch(args.root, args.log, args.output, args.watch)
        except Exception as error:
            report_error(args.output, type(error).__name__)
            return 1
        return 0
    return run(args.command[1:] if args.command[:1] == ['--'] else args.command,
               args.root, args.log, args.output)


if __name__ == '__main__':
    raise SystemExit(main())
