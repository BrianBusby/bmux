# bmux Rust Client

Synchronous Rust client for the bmux-mux Unix-socket JSON-lines protocol.

## Build

```bash
cd mux
cargo build -p bmux-client --locked
```

## Usage

```rust
use bmux_client::{ClientConfig, BmuxClient};

let socket = std::env::var("BMUX_MUX_SOCKET")?;
let mut client = BmuxClient::connect(ClientConfig::from_socket_path(socket))?;
let surface = client.new_workspace(Some("sdk-demo"), Some(80), Some(24))?.surface;
client.send(surface, Some("echo hello\r"), None)?;
println!("{}", client.read_screen(surface)?.text);
# Ok::<(), Box<dyn std::error::Error>>(())
```

## E2E

```bash
cd mux
BMUX_MUX_SOCKET=/path/to/session.sock cargo run -p bmux-client --example e2e --locked
```
