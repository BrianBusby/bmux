import { defineConfig } from "drizzle-kit";

function defaultDatabaseURL(): string {
  const rawPort = process.env.BMUX_PORT ?? process.env.PORT ?? "3777";
  const bmuxPort = /^\d+$/.test(rawPort) ? Number(rawPort) : 3777;
  const offset = Number(process.env.BMUX_DB_PORT_OFFSET ?? "10000");
  const dbPort = process.env.BMUX_DB_PORT ?? String(bmuxPort + offset);
  const user = process.env.BMUX_DB_USER ?? "bmux";
  const password = process.env.BMUX_DB_PASSWORD ?? "bmux";
  const database = process.env.BMUX_DB_NAME ?? "bmux";
  return `postgres://${user}:${password}@localhost:${dbPort}/${database}`;
}

export default defineConfig({
  schema: "./db/schema.ts",
  out: "./db/migrations",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DIRECT_DATABASE_URL ?? process.env.DATABASE_URL ?? defaultDatabaseURL(),
  },
  strict: true,
  verbose: true,
});
