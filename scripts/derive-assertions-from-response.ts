#!/usr/bin/env npx tsx
/**
 * Derives a list of assertions (JSONPath + operator + targetvalue) from a sample
 * JSON response (e.g. from a dev GraphQL call). Paste the response into a file
 * or pipe via stdin; the script walks the tree and emits one assertion per leaf.
 *
 * Usage:
 *   npx tsx scripts/derive-assertions-from-response.ts response.json
 *   npx tsx scripts/derive-assertions-from-response.ts response.json --query scheduledAssetsForTasks
 *   curl ... | npx tsx scripts/derive-assertions-from-response.ts -
 *
 * Output: YAML snippet you can paste into synthetic-test-config/graphql/<env>/<service>.yaml
 * under environments.<env>.assertions. Optionally --terraform to emit Terraform
 * local value format.
 */

import * as fs from "fs";
import * as path from "path";

interface Assertion {
  jsonpath: string;
  operator: string;
  targetvalue: string | number | boolean | null;
}

function escapeJsonPathSegment(segment: string): string {
  // If segment contains special chars (e.g. hyphen, space), wrap in quotes and escape
  if (/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(segment)) return segment;
  return `['${String(segment).replace(/'/g, "\\'")}']`;
}

function leaves(
  obj: unknown,
  basePath: string
): Array<{ path: string; value: string | number | boolean | null }> {
  const out: Array<{ path: string; value: string | number | boolean | null }> = [];

  if (obj === null || obj === undefined) {
    out.push({ path: basePath, value: null });
    return out;
  }

  if (typeof obj === "boolean" || typeof obj === "number" || typeof obj === "string") {
    out.push({ path: basePath, value: obj });
    return out;
  }

  if (Array.isArray(obj)) {
    // Emit assertions for first element only (common for "one sample" responses)
    if (obj.length > 0) {
      const first = obj[0];
      const childBase = `${basePath}[0]`;
      if (
        typeof first === "object" &&
        first !== null &&
        !Array.isArray(first)
      ) {
        Object.entries(first).forEach(([k, v]) => {
          const seg = escapeJsonPathSegment(k);
          const nextPath = childBase + (seg.startsWith("[") ? seg : "." + seg);
          out.push(...leaves(v, nextPath));
        });
      } else {
        out.push({ path: childBase, value: first as string | number | boolean | null });
      }
    }
    return out;
  }

  // Plain object
  for (const [key, value] of Object.entries(obj)) {
    const seg = escapeJsonPathSegment(key);
    const nextPath = basePath
      ? basePath + (seg.startsWith("[") ? seg : "." + seg)
      : "$" + (seg.startsWith("[") ? seg : "." + seg);
    out.push(...leaves(value, nextPath));
  }
  return out;
}

function formatValue(v: string | number | boolean | null): string | number {
  if (v === null) return "null";
  if (typeof v === "number" || typeof v === "boolean") return v;
  return String(v);
}

function toYaml(assertions: Assertion[]): string {
  const lines: string[] = ["assertions:"];
  for (const a of assertions) {
    const tv = formatValue(a.targetvalue);
    const targetStr = typeof tv === "string" ? `"${String(tv).replace(/"/g, '\\"')}"` : String(tv);
    lines.push(`  - jsonpath: "${a.jsonpath}"`);
    lines.push(`    operator: ${a.operator}`);
    lines.push(`    targetvalue: ${targetStr}`);
  }
  return lines.join("\n");
}

function toTerraform(assertions: Assertion[]): string {
  const entries = assertions.map((a) => {
    const tv = formatValue(a.targetvalue);
    const targetStr = typeof tv === "string" ? `"${String(tv).replace(/"/g, '\\"')}"` : String(tv);
    return `  { jsonpath = "${a.jsonpath}", operator = "${a.operator}", targetvalue = ${targetStr} }`;
  });
  return `[\n${entries.join(",\n")}\n]`;
}

function main(): void {
  const args = process.argv.slice(2).filter((a) => a !== "--terraform");
  const useTerraform = process.argv.includes("--terraform");
  const queryIdx = args.findIndex((a) => a === "--query");
  let dataRoot: string | null = null;
  if (queryIdx !== -1 && args[queryIdx + 1]) {
    dataRoot = args[queryIdx + 1];
    args.splice(queryIdx, 2);
  }

  const file = args[0];
  if (!file) {
    console.error("Usage: derive-assertions-from-response.ts <response.json|-> [--query <queryName>] [--terraform]");
    process.exit(1);
  }

  let raw: string;
  if (file === "-") {
    raw = fs.readFileSync(0, "utf8");
  } else {
    const p = path.isAbsolute(file) ? file : path.resolve(process.cwd(), file);
    if (!fs.existsSync(p)) {
      console.error("File not found:", p);
      process.exit(1);
    }
    raw = fs.readFileSync(p, "utf8");
  }

  let data: unknown;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    console.error("Invalid JSON:", (e as Error).message);
    process.exit(1);
  }

  // If response is { data: { queryName: ... } }, optionally restrict to that root
  let root = data as Record<string, unknown>;
  let basePath = "$";
  if (dataRoot && typeof root.data === "object" && root.data !== null) {
    const dataObj = root.data as Record<string, unknown>;
    if (dataObj[dataRoot] !== undefined) {
      root = dataObj[dataRoot] as Record<string, unknown>;
      basePath = `$.data.${dataRoot}`;
    }
  } else if (typeof root.data === "object" && root.data !== null) {
    root = root.data as Record<string, unknown>;
    basePath = "$.data";
  }

  const leafList = leaves(root, basePath);
  const assertions: Assertion[] = leafList.map(({ path: p, value }) => ({
    jsonpath: p,
    operator: "is",
    targetvalue: value,
  }));

  if (assertions.length === 0) {
    console.error("No leaves found in JSON.");
    process.exit(1);
  }

  if (useTerraform) {
    console.log(toTerraform(assertions));
  } else {
    console.log("# Paste under the query's assertions in synthetic-test-config/graphql/<env>/<service>.yaml\n");
    console.log(toYaml(assertions));
  }
}

main();
