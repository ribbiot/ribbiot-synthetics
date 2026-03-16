#!/usr/bin/env npx tsx
/**
 * Reads synthetic-data/*.yaml, collects every synthetic_data key+value (where value is set),
 * and writes environments/dev/synthetic-data.auto.tfvars.json so Terraform can use them
 * as var.synthetic_data_values without setting variables by hand.
 *
 * Run before tf:plan:dev / tf:apply:dev, or add to your workflow (e.g. npm run tfvars:from-synthetic-data).
 */

import * as fs from "fs";
import * as path from "path";
import YAML from "yaml";

const REPO_ROOT = path.resolve(__dirname, "..");
const SYNTHETIC_DATA_DIR = path.join(REPO_ROOT, "synthetic-data");
const OUT_FILE = path.join(REPO_ROOT, "environments", "dev", "synthetic-data.auto.tfvars.json");

interface SyntheticDataItem {
  key?: string;
  value?: unknown;
  purpose?: string;
  where_to_set?: string;
  format?: string;
}

interface QueryEntry {
  name?: string;
  synthetic_data?: SyntheticDataItem[];
}

interface ServiceDoc {
  queries?: QueryEntry[];
}

function collectValues(): Record<string, string> {
  const values: Record<string, string> = {};
  const files = fs.readdirSync(SYNTHETIC_DATA_DIR).filter((f) => f.endsWith(".yaml") && f !== "README.md");
  for (const file of files) {
    const filePath = path.join(SYNTHETIC_DATA_DIR, file);
    const content = fs.readFileSync(filePath, "utf8");
    const doc = YAML.parse(content) as ServiceDoc;
    if (!doc?.queries) continue;
    for (const q of doc.queries) {
      for (const item of q.synthetic_data ?? []) {
        const key = item.key;
        if (key == null || key === "(input)" || item.value === undefined) continue;
        // Terraform map(string) requires all values to be strings; JSON-encode arrays/objects
        values[key] =
          typeof item.value === "string" ? item.value : JSON.stringify(item.value);
      }
    }
  }
  return values;
}

function main(): void {
  const values = collectValues();
  const payload = { synthetic_data_values: values };
  const outDir = path.dirname(OUT_FILE);
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(OUT_FILE, JSON.stringify(payload, null, 2) + "\n", "utf8");
  console.log(`Wrote ${Object.keys(values).length} synthetic data value(s) to ${OUT_FILE}`);
}

main();
