"""Reject stale owned-host bindings before lifecycle or naming mutations."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import unittest


class ConnectedCodexHookBindingTests(unittest.TestCase):
    def test_moved_or_closed_surface_never_falls_back_to_old_workspace(self):
        cli = os.environ['BMUX_CLI_BIN']
        workspace = '11111111-1111-1111-1111-111111111111'
        moved_surface = '22222222-2222-2222-2222-222222222222'
        other_surface = '33333333-3333-3333-3333-333333333333'
        for command in [['codex', 'prompt-submit'], ['codex', 'stop'],
                        ['codex', 'auto-name'], ['feed', '--source', 'codex', '--event', 'PreToolUse']]:
            with self.subTest(command=command), tempfile.TemporaryDirectory() as directory:
                path = str(Path(directory) / 'bmux.sock')
                requests = []
                with socket.socket(socket.AF_UNIX) as server:
                    server.bind(path)
                    server.listen(1)
                    server.settimeout(5)

                    def serve():
                        connection, _ = server.accept()
                        with connection, connection.makefile('rb') as stream:
                            for line in stream:
                                request = json.loads(line)
                                requests.append(request)
                                result = {'surfaces': [{'id': other_surface, 'ref': 'surface:1'}]}
                                connection.sendall((json.dumps({'id': request['id'], 'ok': True, 'result': result}) + '\n').encode())

                    thread = threading.Thread(target=serve, daemon=True)
                    thread.start()
                    env = dict(os.environ, BMUX_CODEX_CONNECTED_HOST='1', BMUX_SOCKET_PATH=path,
                               BMUX_WORKSPACE_ID=workspace, BMUX_SURFACE_ID=moved_surface,
                               BMUX_CLAUDE_HOOK_STATE_PATH=str(Path(directory) / 'hooks.json'))
                    result = subprocess.run([cli, '--socket', path, 'hooks', *command], env=env,
                                            input='{"session_id":"roof-session","prompt":"Review flashing"}',
                                            capture_output=True, text=True, timeout=10)
                    thread.join(timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), {})
                self.assertEqual([request['method'] for request in requests], ['surface.list'])
                self.assertEqual(requests[0]['params']['workspace_id'], workspace.upper())


if __name__ == '__main__':
    unittest.main()
