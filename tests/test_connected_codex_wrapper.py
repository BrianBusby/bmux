"""Exercise per-invocation hook injection for an explicitly owned connected host."""
import base64
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest


class ConnectedCodexWrapperTests(unittest.TestCase):
    def launch(self, owned=False, disabled=False, resume=None, arguments=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            codex = root / 'codex'
            codex.write_text('#!/usr/bin/python3\nimport json,sys,os\nprint(json.dumps({"args":sys.argv[1:],"resume":os.environ.get("BMUX_AGENT_LAUNCH_ARGV_B64")}))\n')
            cli = root / 'bmux'
            cli.write_text('#!/bin/sh\ncase "$*" in *inject-args*) printf "%s\\0" --enable hooks;; esac\n')
            for executable in (codex, cli):
                executable.chmod(0o700)
            with socket.socket(socket.AF_UNIX) as connection:
                connection.bind(str(root / 'bmux.sock'))
                env = dict(os.environ, BMUX_SURFACE_ID='roof-surface',
                           BMUX_SOCKET_PATH=str(root / 'bmux.sock'),
                           BMUX_BUNDLED_CLI_PATH=str(cli), BMUX_CUSTOM_CODEX_PATH=str(codex),
                           BMUX_CODEX_CONNECTED_HOST='1' if owned else '0',
                           BMUX_CODEX_HOOKS_DISABLED='1' if disabled else '0')
                if resume is not None:
                    env['BMUX_AGENT_LAUNCH_ARGV_B64'] = resume
                wrapper = Path(__file__).resolve().parents[1] / 'Resources/bin/bmux-codex-wrapper'
                result = subprocess.run([str(wrapper), *(arguments if arguments is not None else ['app-server', '--listen', 'ws://127.0.0.1:0'])],
                                        env=env, check=True, capture_output=True, text=True)
                capture = json.loads(result.stdout)
                self.resume_capture = capture['resume']
                return capture['args']

    def test_owned_host_receives_hooks(self):
        self.assertEqual(self.launch(owned=True),
                         ['--enable', 'hooks', 'app-server', '--listen', 'ws://127.0.0.1:0'])

    def test_owned_host_preserves_original_interactive_resume_arguments(self):
        for arguments in [b'/usr/local/bin/codex\0', b'/usr/local/bin/codex\0--model\0roof-model\0']:
            with self.subTest(arguments=arguments):
                expected = base64.b64encode(arguments).decode()
                self.launch(owned=True, resume=expected)
                self.assertEqual(self.resume_capture, expected)

    def test_nested_interactive_launch_recaptures_its_own_arguments(self):
        parent = base64.b64encode(b'/usr/local/bin/codex\0--model\0parent\0').decode()
        self.launch(owned=True, resume=parent, arguments=['--model', 'nested'])
        captured = base64.b64decode(self.resume_capture).decode().split('\0')
        self.assertEqual(captured[1:], ['--model', 'nested', ''])

    def test_unowned_server_is_unchanged(self):
        self.assertEqual(self.launch(), ['app-server', '--listen', 'ws://127.0.0.1:0'])

    def test_disabled_hooks_remain_disabled(self):
        self.assertEqual(self.launch(owned=True, disabled=True),
                         ['app-server', '--listen', 'ws://127.0.0.1:0'])


if __name__ == '__main__':
    unittest.main()
