# bmux Go Client

Stdlib-only Go client for the bmux-mux Unix-socket JSON-lines protocol.

Import path remains unchanged:

```go
import "github.com/manaflow-ai/bmux/mux/bindings/go"
```

## Build

```bash
cd mux/bindings/go
go build ./...
```

## Usage

```go
ctx := context.Background()
client, err := bmux.NewClient(bmux.Options{SocketPath: os.Getenv("BMUX_MUX_SOCKET")})
if err != nil {
    panic(err)
}
defer client.Close()
surface, err := client.NewWorkspace(ctx, bmux.NewWorkspaceOptions{})
if err != nil {
    panic(err)
}
text := "echo hello\r"
_ = client.Send(ctx, surface.Surface, bmux.SendOptions{Text: &text})
screen, _ := client.ReadScreen(ctx, surface.Surface)
fmt.Println(screen.Text)
```

## E2E

```bash
cd mux/bindings/go
BMUX_MUX_SOCKET=/path/to/session.sock go run ./cmd/e2e
```
