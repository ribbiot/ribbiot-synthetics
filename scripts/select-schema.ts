#!/usr/bin/env npx tsx
/**
 * Prompts which federated schema to work on so we can target one subgraph (or supergraph)
 * instead of the whole API. Writes config/selected-schema.json for fetch-graphql-schema and docs.
 * DEV ONLY. Run: npm run mcp:select-schema
 */

import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import inquirer from "inquirer";

const CONFIG_PATH = resolve(process.cwd(), "config/schema-options.json");
const OUT_PATH = resolve(process.cwd(), "config/selected-schema.json");

type SchemaOption = {
  id: string;
  label: string;
  roverType?: "subgraph" | "supergraph";
  roverName?: string;
  studioUrl?: string;
};

type SchemaOptionsConfig = {
  graphRef: string;
  options: SchemaOption[];
};

async function main(): Promise<void> {
  const raw = readFileSync(CONFIG_PATH, "utf-8");
  const config = JSON.parse(raw) as SchemaOptionsConfig;
  const choices = [
    ...config.options.map((o) => ({
      name: o.label,
      value: o,
      short: o.label,
    })),
    new inquirer.Separator(),
    {
      name: "Use router introspection (full API; no Rover)",
      value: null,
      short: "Router",
    },
  ];

  const { selected } = await inquirer.prompt<{ selected: SchemaOption | null }>([
    {
      type: "list",
      name: "selected",
      message: "Which schema do you want to implement synthetics for?",
      choices,
      pageSize: 12,
    },
  ]);

  if (selected === null) {
    writeFileSync(
      OUT_PATH,
      JSON.stringify({ id: null, label: "Router (introspection)", studioUrl: null }, null, 2),
      "utf-8"
    );
    console.log("Selected: Router (introspection). Schema fetch will use the dev router endpoint.");
    return;
  }

  const out = {
    id: selected.id,
    label: selected.label,
    roverType: selected.roverType,
    roverName: selected.roverName,
    studioUrl: selected.studioUrl ?? null,
    graphRef: config.graphRef,
  };
  writeFileSync(OUT_PATH, JSON.stringify(out, null, 2), "utf-8");
  console.log("Selected:", selected.label);
  if (selected.studioUrl) {
    console.log("Studio:", selected.studioUrl);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
