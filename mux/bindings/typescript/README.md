# bmux TypeScript Client

Node.js client for the bmux-mux Unix-socket JSON-lines protocol.

## Build

```bash
npm i bmux
npm install
npm run build
```

The package has no runtime dependencies. Node 20 or newer is required.

## Usage

```ts
import { BmuxClient } from "bmux";

const client = new BmuxClient({ socketPath: process.env.BMUX_MUX_SOCKET });
const info = await client.identify();
const created = await client.newWorkspace({ name: "sdk-demo", cols: 80, rows: 24 });
await client.send(created.surface, { text: "echo hello\r" });
console.log((await client.readScreen(created.surface)).text);
await client.close();
```

## E2E

```bash
BMUX_MUX_SOCKET=/path/to/session.sock npm run e2e
```
