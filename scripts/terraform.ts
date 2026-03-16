#!/usr/bin/env npx ts-node
/**
 * Run Terraform in an environment with variables from .env.
 * Usage: npx ts-node scripts/terraform.ts <init|plan|apply|validate> <dev|prod>
 * Or use npm run tf:apply:dev etc. which use dotenv-cli.
 */

import { execSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const ALLOWED_COMMANDS = ["init", "plan", "apply", "validate"] as const;
const ALLOWED_ENVS = ["dev", "prod"] as const;

function loadEnv(envPath: string): void {
  if (!existsSync(envPath)) {
    console.error(`Missing ${envPath}. Copy from .env.example and fill in values.`);
    process.exit(1);
  }
  const content = readFileSync(envPath, "utf-8");
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim();
    if (key && value !== undefined) process.env[key] = value;
  }
}

function runTerraform(env: string, command: string): void {
  const dir = resolve(process.cwd(), "environments", env);
  const needsAutoApprove = command === "apply";
  const args = ["-input=false"];
  if (needsAutoApprove) args.push("-auto-approve");
  const cmd = `terraform ${command} ${args.join(" ")}`;
  execSync(cmd, { cwd: dir, stdio: "inherit" });
}

function main(): void {
  const command = process.argv[2];
  const env = process.argv[3];

  if (!command || !ALLOWED_COMMANDS.includes(command as (typeof ALLOWED_COMMANDS)[number])) {
    console.error(`Usage: npx ts-node scripts/terraform.ts <${ALLOWED_COMMANDS.join("|")}> <dev|prod>`);
    process.exit(1);
  }
  if (!env || !ALLOWED_ENVS.includes(env as (typeof ALLOWED_ENVS)[number])) {
    console.error(`Environment must be one of: ${ALLOWED_ENVS.join(", ")}`);
    process.exit(1);
  }

  const envPath = resolve(process.cwd(), ".env");
  loadEnv(envPath);

  if (command === "init") {
    execSync("terraform init -input=false", {
      cwd: resolve(process.cwd(), "environments", env),
      stdio: "inherit",
    });
    return;
  }

  if (command === "validate") {
    execSync("terraform validate", {
      cwd: resolve(process.cwd(), "environments", env),
      stdio: "inherit",
    });
    return;
  }

  if (command === "plan" || command === "apply") {
    const dir = resolve(process.cwd(), "environments", env);
    execSync("terraform init -input=false", { cwd: dir, stdio: "inherit" });
    runTerraform(env, command);
  }
}

main();
