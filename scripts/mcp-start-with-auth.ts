#!/usr/bin/env npx tsx
/**
 * Fetches an Auth0 token (same as dev synthetics) and starts the Apollo MCP server
 * with it so Cursor can run authenticated GraphQL queries. DEV ONLY — do not use for production.
 * See docs/dev-only-scope.md.
 *
 * Requires .env (or env): TF_VAR_dev_username, TF_VAR_dev_password, TF_VAR_dev_client_secret.
 * Run: npm run mcp:start:auth  (or: dotenv -e .env -- npx tsx scripts/mcp-start-with-auth.ts)
 */

import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

async function getToken(): Promise<string> {
  const { execSync } = await import("node:child_process");
  const scriptPath = resolve(__dirname, "get-auth0-token.ts");
  return execSync(`npx tsx "${scriptPath}"`, {
    encoding: "utf-8",
    env: process.env,
  }).trim();
}

function loadEnv(): void {
  try {
    const path = resolve(process.cwd(), ".env");
    const content = readFileSync(path, "utf-8");
    for (const line of content.split("\n")) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith("#")) {
        const eq = trimmed.indexOf("=");
        if (eq > 0) {
          const key = trimmed.slice(0, eq).trim();
          let val = trimmed.slice(eq + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
            val = val.slice(1, -1);
          }
          if (!process.env[key]) process.env[key] = val;
        }
      }
    }
  } catch {
    // .env optional
  }
}

async function main(): Promise<void> {
  loadEnv();
  const token = await getToken();
  const configDir = resolve(process.cwd(), "config");
  // Refresh schema from dev endpoint (with auth) so MCP has current types
  try {
    const { execSync } = await import("node:child_process");
    execSync(`npx tsx "${resolve(__dirname, "fetch-graphql-schema.ts")}"`, {
      encoding: "utf-8",
      env: { ...process.env, AUTH0_ACCESS_TOKEN: token },
      stdio: "pipe",
    });
  } catch {
    // Proceed with existing config/schema.graphql if fetch fails
  }
  const args = [
    "run",
    "--rm",
    "-p",
    "8000:8000",
    "-v",
    `${configDir}:/data`,
    "-e",
    `AUTH0_ACCESS_TOKEN=${token}`,
  ];
  if (process.env.APOLLO_GRAPHQL_ENDPOINT) {
    args.push("-e", `APOLLO_GRAPHQL_ENDPOINT=${process.env.APOLLO_GRAPHQL_ENDPOINT}`);
  }
  args.push("ghcr.io/apollographql/apollo-mcp-server:latest", "/data/apollo-mcp-with-auth.yaml");
  const child = spawn("docker", args, {
    stdio: "inherit",
    cwd: process.cwd(),
  });
  child.on("exit", (code) => process.exit(code ?? 0));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
