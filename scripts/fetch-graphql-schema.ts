#!/usr/bin/env npx tsx
/**
 * Fetches the GraphQL schema and writes config/schema.graphql for Apollo MCP Server.
 * If you ran mcp:select-schema and chose a subgraph/supergraph, and APOLLO_KEY is set,
 * uses Rover to fetch that schema. Otherwise introspects the dev router endpoint.
 * DEV ONLY. Run: npm run mcp:schema
 */

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const INTROSPECTION_QUERY = `
  query IntrospectionQuery {
    __schema {
      queryType { name }
      mutationType { name }
      subscriptionType { name }
      types {
        ...FullType
      }
      directives {
        name
        description
        locations
        args {
          ...InputValue
        }
      }
    }
  }
  fragment FullType on __Type {
    kind
    name
    description
    fields(includeDeprecated: true) {
      name
      description
      args {
        ...InputValue
      }
      type {
        ...TypeRef
      }
      isDeprecated
      deprecationReason
    }
    inputFields {
      ...InputValue
    }
    interfaces {
      ...TypeRef
    }
    enumValues(includeDeprecated: true) {
      name
      description
      isDeprecated
      deprecationReason
    }
    possibleTypes {
      ...TypeRef
    }
  }
  fragment InputValue on __InputValue {
    name
    description
    type {
      ...TypeRef
    }
    defaultValue
  }
  fragment TypeRef on __Type {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
        }
      }
    }
  }
`;

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

type SelectedSchema = {
  id: string | null;
  label: string;
  roverType?: "subgraph" | "supergraph";
  roverName?: string;
  graphRef?: string;
};

function tryRoverFetch(selected: SelectedSchema): string | null {
  if (!selected.roverType || !process.env.APOLLO_KEY) return null;
  const graphRef = selected.graphRef ?? process.env.APOLLO_GRAPH_REF ?? "Ribbiot-Serverless@dev-current";
  let cmd: string;
  if (selected.roverType === "subgraph" && selected.roverName) {
    cmd = `rover subgraph fetch ${graphRef} --name ${selected.roverName}`;
  } else if (selected.roverType === "supergraph") {
    cmd = `rover supergraph fetch ${graphRef}`;
  } else {
    return null;
  }
  try {
    const out = execSync(cmd, {
      encoding: "utf-8",
      env: { ...process.env, APOLLO_KEY: process.env.APOLLO_KEY },
    });
    return out.trim() || null;
  } catch {
    return null;
  }
}

async function main(): Promise<void> {
  loadEnv();
  const outPath = resolve(process.cwd(), "config/schema.graphql");
  const selectedPath = resolve(process.cwd(), "config/selected-schema.json");

  let sdl: string | null = null;
  try {
    const selectedRaw = readFileSync(selectedPath, "utf-8");
    const selected = JSON.parse(selectedRaw) as SelectedSchema;
    if (selected.id != null && selected.roverType) {
      sdl = tryRoverFetch(selected);
          if (sdl) console.log("Fetched via Rover:", selected.label);
    }
  } catch {
    // No selection or invalid; fall back to introspection
  }

  if (!sdl) {
    const endpoint =
      process.env.APOLLO_GRAPHQL_ENDPOINT ?? "https://ribbiot-router-dev.up.railway.app/graphql";
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    const token = process.env.AUTH0_ACCESS_TOKEN;
    if (token) headers["Authorization"] = `Bearer ${token}`;

    const res = await fetch(endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify({ query: INTROSPECTION_QUERY }),
    });
    if (!res.ok) {
      console.error("Introspection failed:", res.status, await res.text());
      process.exit(1);
    }
    const json = (await res.json()) as { data?: { __schema?: unknown }; errors?: unknown[] };
    if (json.errors?.length) {
      console.error("GraphQL errors:", JSON.stringify(json.errors, null, 2));
      process.exit(1);
    }
    if (!json.data?.__schema) {
      console.error("No __schema in response");
      process.exit(1);
    }

    const { buildClientSchema, printSchema } = await import("graphql");
    const schema = buildClientSchema(json.data as { __schema: unknown });
    sdl = printSchema(schema);
    console.log("Fetched via router introspection");
  }

  writeFileSync(outPath, sdl, "utf-8");
  console.log("Wrote", outPath);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
