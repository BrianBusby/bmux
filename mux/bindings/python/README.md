# bmux Python Client

Synchronous Python client for the bmux-mux Unix-socket JSON-lines protocol.

## Install

```bash
pip install bmux
```

## Usage

```python
import os

from bmux import BmuxClient

with BmuxClient(socket_path=os.environ["BMUX_MUX_SOCKET"]) as client:
    info = client.identify()
    surface = client.new_workspace(name="sdk-demo", cols=80, rows=24)
    client.send(surface.surface, text="echo hello\r")
    print(client.read_screen(surface.surface).text)
```
