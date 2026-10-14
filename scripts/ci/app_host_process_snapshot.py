"""macOS process identity lookup; never reads process arguments or environment."""
from __future__ import annotations

import ctypes
import time
from pathlib import Path


class BSDInfo(ctypes.Structure):
    # Darwin sys/proc_info.h PROC_PIDTBSDINFO; names are not emitted.
    _fields_ = [(name, ctypes.c_uint32) for name in (
        'flags', 'state', 'status', 'pid', 'ppid', 'uid', 'gid', 'ruid', 'rgid',
        'svuid', 'svgid', 'reserved')]
    _fields_ += [('comm', ctypes.c_char * 16), ('name', ctypes.c_char * 32)]
    _fields_ += [(name, ctypes.c_uint32) for name in (
        'nfiles', 'pgid', 'jobc', 'tdev', 'tpgid', 'nice')]
    _fields_ += [('start_seconds', ctypes.c_uint64), ('start_microseconds', ctypes.c_uint64)]


class MacProcesses:
    def __init__(self):
        self.lib = ctypes.CDLL('/usr/lib/libproc.dylib')

    def snapshot(self):
        size = self.lib.proc_listpids(1, 0, None, 0)
        pids = (ctypes.c_int * (size // 4 + 256))()
        size = self.lib.proc_listpids(1, 0, pids, ctypes.sizeof(pids))
        result = {}
        for pid in pids[:max(0, size // 4)]:
            info = BSDInfo()
            if self.lib.proc_pidinfo(pid, 3, 0, ctypes.byref(info), ctypes.sizeof(info)) != ctypes.sizeof(info):
                continue
            path = ctypes.create_string_buffer(4096)
            if self.lib.proc_pidpath(pid, path, len(path)) <= 0:
                continue
            result[pid] = dict(pid=pid, ppid=info.ppid, state=info.state,
                               birth=(info.start_seconds, info.start_microseconds),
                               path=path.value.decode('utf-8', errors='replace'))
        return result

    def metrics(self, record):
        # PROC_PIDTASKINFO: six uint64 counters followed by twelve int32 values.
        counters = ctypes.create_string_buffer(96)
        if self.lib.proc_pidinfo(record['pid'], 4, 0, counters, len(counters)) != 96:
            return {}
        values = (ctypes.c_uint64 * 6).from_buffer(counters)
        integers = (ctypes.c_int32 * 12).from_buffer(counters, 48)
        return dict(cpu_nanoseconds=values[2] + values[3], threads=integers[9],
                    elapsed_seconds=max(0, time.time() - record['birth'][0] - record['birth'][1] / 1e6))


def selected_processes(records, derived_data):
    app = Path(derived_data).resolve() / 'Build/Products/Debug/bmux DEV.app/Contents'
    hosts = {pid for pid, item in records.items() if item['path'] == str(app / 'MacOS/bmux DEV')}
    cli_path = str(app / 'Resources/bin/bmux')
    selected = {pid: {**records[pid], 'role': 'host'} for pid in hosts}
    for pid, item in records.items():
        if item['path'] != cli_path:
            continue
        ancestor, visited = item['ppid'], {pid}
        while ancestor in records and ancestor not in visited:
            if ancestor in hosts:
                selected[pid] = {**item, 'role': 'cli'}
                break
            visited.add(ancestor)
            ancestor = records[ancestor]['ppid']
    return selected
