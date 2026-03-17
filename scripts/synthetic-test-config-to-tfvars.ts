#!/usr/bin/env npx tsx
/**
 * Reads synthetic-test-config/graphql/<env>/*.yaml (dev and prod separately), collects
 * synthetic_data key+value and assertions per query, and writes
 * environments/<env>/synthetic-test-config.auto.tfvars.json so Terraform gets
 * var.synthetic_data_values and var.synthetic_test_assertions. Config YAML is the
 * source of truth; run this before tf:plan / tf:apply.
 *
 * Run before tf:plan:dev / tf:apply:dev (or prod). Generates both dev and prod
 * tfvars by default; pass --env dev or --env prod to generate only one.
 */

import * as fs from "fs";
import * as path from "path";
import YAML from "yaml";

const REPO_ROOT = path.resolve(__dirname, "..");
const SYNTHETIC_TEST_CONFIG_ROOT = path.join(REPO_ROOT, "synthetic-test-config");
const GRAPHQL_DIR = path.join(SYNTHETIC_TEST_CONFIG_ROOT, "graphql");

interface SyntheticDataItem {
  key?: string;
  value?: unknown;
  purpose?: string;
  where_to_set?: string;
  format?: string;
}

interface AssertionItem {
  jsonpath?: string;
  operator?: string;
  targetvalue?: string;
}

interface QueryEntry {
  name?: string;
  synthetic_data?: SyntheticDataItem[];
  assertions?: AssertionItem[];
  /** When true, this query is omitted from tfvars and Terraform test generation (e.g. endpoint unused or data unreliable). */
  excluded?: boolean;
}

interface ServiceDoc {
  scope?: string;
  environment?: string;
  queries?: QueryEntry[];
}

function readYamlDir(dir: string): string[] {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter((f) => f.endsWith(".yaml"));
}

function collectValuesFromDoc(doc: ServiceDoc, values: Record<string, string>): void {
  if (!doc?.queries) return;
  for (const q of doc.queries) {
    // Excluded queries: still emit synthetic_data so existing Datadog globals are not destroyed (tests may still reference them).
    for (const item of q.synthetic_data ?? []) {
      const key = item.key;
      if (key == null || key === "(input)" || item.value === undefined) continue;
      const val = item.value;
      if (Array.isArray(val) && val.length === 0) continue; // skip empty array placeholder
      if (typeof val === "string" && val.trim() === "") continue; // skip empty string placeholder
      values[key] =
        typeof val === "string" ? val : JSON.stringify(val);
    }
  }
}

type AssertionOutput = { jsonpath: string; operator: string; targetvalue: string }[];

function collectAssertionsFromDoc(doc: ServiceDoc, assertions: Record<string, AssertionOutput>): void {
  if (!doc?.queries) return;
  for (const q of doc.queries) {
    const name = q.name;
    const list = q.assertions ?? [];
    if (name && list.length > 0) {
      assertions[name] = list.map((a) => ({
        jsonpath: String(a.jsonpath ?? ""),
        operator: String(a.operator ?? "is"),
        targetvalue: String(a.targetvalue ?? ""),
      }));
    }
  }
}

function collectForEnv(
  env: string
): { values: Record<string, string>; assertions: Record<string, AssertionOutput> } {
  const values: Record<string, string> = {};
  const assertions: Record<string, AssertionOutput> = {};
  const envDir = path.join(GRAPHQL_DIR, env);
  const files = readYamlDir(envDir);
  if (files.length > 0) {
    for (const file of files) {
      const content = fs.readFileSync(path.join(envDir, file), "utf8");
      const doc = YAML.parse(content) as ServiceDoc;
      collectValuesFromDoc(doc, values);
      collectAssertionsFromDoc(doc, assertions);
    }
    return { values, assertions };
  }
  // Fallback: legacy graphql/*.yaml (single file with environments.dev/prod) in synthetic-test-config for dev only
  if (env === "dev") {
    const legacyFiles = readYamlDir(GRAPHQL_DIR);
    for (const file of legacyFiles) {
      const content = fs.readFileSync(path.join(GRAPHQL_DIR, file), "utf8");
      const doc = YAML.parse(content) as ServiceDoc;
      if (doc?.queries) {
        for (const q of doc.queries) {
          for (const item of q.synthetic_data ?? []) {
            const key = item.key;
            if (key == null || key === "(input)" || item.value === undefined) continue;
            const envBlock = (q as Record<string, unknown>).environments as Record<string, unknown> | undefined;
            const devBlock = envBlock?.dev as Record<string, unknown> | undefined;
            if (!devBlock) continue;
            const val = item.value;
            if (Array.isArray(val) && val.length === 0) continue;
            if (typeof val === "string" && val.trim() === "") continue;
            values[key] = typeof val === "string" ? val : JSON.stringify(val);
          }
        }
      }
    }
    if (Object.keys(values).length > 0) return { values, assertions };
  }
  return { values, assertions };
}

function main(): void {
  const args = process.argv.slice(2);
  const envArg = args.find((a) => a === "--env");
  const envValue = envArg !== undefined ? args[args.indexOf("--env") + 1] : undefined;
  const envs: string[] =
    envValue === "dev" || envValue === "prod" ? [envValue] : ["dev", "prod"];

  const written: string[] = [];
  for (const env of envs) {
    const { values, assertions } = collectForEnv(env);
    const outFile = path.join(REPO_ROOT, "environments", env, "synthetic-test-config.auto.tfvars.json");
    const outDir = path.dirname(outFile);
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
    const payload = {
      synthetic_data_values: values,
      synthetic_test_assertions: assertions,
    };
    fs.writeFileSync(outFile, JSON.stringify(payload, null, 2) + "\n", "utf8");
    written.push(`${env} (${Object.keys(values).length} value(s), ${Object.keys(assertions).length} assertion set(s))`);
  }
  console.log(`Wrote synthetic-test-config.auto.tfvars.json for: ${written.join(", ")}`);
}

main();
