#!/usr/bin/env python3
"""Authenticated provider fixture with Codex's 16 MiB frame limit.

The fake TUI sends a 24 MiB image-shaped request and a follow-up on the same
socket. No account, model, user filesystem, or external network is used.
"""
import base64
import hashlib
import json
import os
import socket
import struct
import sys

SIZE = 24 * 1024 * 1024 + 17
LIMIT = 16 * 1024 * 1024


def exact(sock, count):
    result = bytearray()
    while len(result) < count:
        chunk = sock.recv(count - len(result))
        if not chunk:
            raise EOFError()
        result.extend(chunk)
    return bytes(result)


def header(sock):
    result = bytearray()
    while not result.endswith(b"\r\n\r\n"):
        result.extend(exact(sock, 1))
        if len(result) > 65536:
            raise ValueError("header too large")
    return bytes(result)


def frame(sock, payload, masked=False):
    size = len(payload)
    mask_bit = 0x80 if masked else 0
    if size < 126:
        prefix = bytes([0x81, mask_bit | size])
    elif size <= 65535:
        prefix = bytes([0x81, mask_bit | 126]) + struct.pack("!H", size)
    else:
        prefix = bytes([0x81, mask_bit | 127]) + struct.pack("!Q", size)
    if masked:
        # Deterministic fixture mask; production clients choose random masks.
        prefix += b"\0\0\0\0"
    sock.sendall(prefix + payload)


def message(sock, frame_limit):
    output = bytearray()
    while True:
        flags, size = exact(sock, 2)
        masked = size & 128
        size &= 127
        if size == 126:
            size = struct.unpack("!H", exact(sock, 2))[0]
        elif size == 127:
            size = struct.unpack("!Q", exact(sock, 8))[0]
        if size > frame_limit:
            raise ValueError("frame too large")
        mask = exact(sock, 4) if masked else None
        data = exact(sock, size)
        if mask and mask != b"\0\0\0\0":
            repeated = (mask * ((size + 3) // 4))[:size]
            data = (int.from_bytes(data, "little") ^ int.from_bytes(repeated, "little")).to_bytes(size, "little")
        output.extend(data)
        if len(output) > 64 * 1024 * 1024:
            raise ValueError("message too large")
        if flags & 128:
            return bytes(output)


def serve(token):
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen()
        print("listening on: ws://127.0.0.1:%d" % listener.getsockname()[1], flush=True)
        while True:
            sock, _ = listener.accept()
            with sock:
                sock.settimeout(15)
                try:
                    request = header(sock)
                    fields = dict(line.split(b":", 1) for line in request.split(b"\r\n")[1:] if b":" in line)
                    if fields.get(b"Authorization", b"").strip() != b"Bearer " + token:
                        sock.sendall(b"HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\n\r\n")
                        continue
                    if b"Origin" in fields:
                        sock.sendall(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
                        continue
                    key = fields[b"Sec-WebSocket-Key"].strip()
                    accept = base64.b64encode(hashlib.sha1(key + b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest())
                    sock.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n")
                    request = json.loads(message(sock, LIMIT))
                    if request == {"method": "large-notification"}:
                        frame(sock, b"a" * SIZE)
                        assert message(sock, LIMIT) == b"follow-up"
                        frame(sock, b"connected")
                        continue
                    assert request == {"id": 1, "method": "turn/start", "params": {"threadId": "original", "image": "a" * SIZE}}
                    frame(sock, b'{"id":1,"result":"accepted once"}')
                    assert message(sock, LIMIT) == b'{"id":2,"method":"follow-up"}'
                    frame(sock, b'{"id":2,"result":"follow-up accepted"}')
                except (EOFError, OSError, ValueError, AssertionError):
                    pass  # Reject and close, like the pinned provider.


def client(endpoint, token):
    port = int(endpoint.rsplit(":", 1)[1])
    for credential, origin, status in [(b"wrong", b"", b"401"), (token, b"Origin: https://invalid.example\r\n", b"403")]:
        with socket.create_connection(("127.0.0.1", port), timeout=15) as denied:
            denied.sendall(b"GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nAuthorization: Bearer " + credential + b"\r\n" + origin + b"\r\n")
            assert header(denied).split(b" ")[1] == status
    with socket.create_connection(("127.0.0.1", port), timeout=15) as sock:
        key = base64.b64encode(os.urandom(16))
        sock.sendall(b"GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: " + key + b"\r\nAuthorization: Bearer " + token + b"\r\n\r\n")
        assert header(sock).startswith(b"HTTP/1.1 101")
        payload = json.dumps({"id": 1, "method": "turn/start", "params": {"threadId": "original", "image": "a" * SIZE}}).encode()
        frame(sock, payload, masked=True)
        first = json.loads(message(sock, LIMIT))["result"]
        frame(sock, b'{"id":2,"method":"follow-up"}', masked=True)
        second = json.loads(message(sock, LIMIT))["result"]
        print(first + "; " + second)


if __name__ == "__main__":
    if sys.argv[1] == "--version":
        print("codex-cli 0.162.0")
    elif sys.argv[1] == "app-server":
        with open(sys.argv[sys.argv.index("--ws-token-file") + 1], "rb") as source:
            serve(source.read())
    else:
        client(sys.argv[sys.argv.index("--remote") + 1], os.environ[sys.argv[sys.argv.index("--remote-auth-token-env") + 1]].encode())
