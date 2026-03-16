# Datadog Synthetic API Tests as Code

This repository defines and manages **Datadog Synthetic API tests** using Terraform. Tests are version-controlled, reviewed via pull requests, and deployed from code instead of the Datadog UI.

## Purpose

- **Single source of truth**: All synthetic API tests live in Terraform.
- **Multi-environment**: Separate `dev` and `prod` (and more) with their own state and config.
- **Reusable module**: Add new tests with minimal duplication via the `synthetic-api-test` module.
- **Secrets-safe**: Credentials are supplied via environment variables or non-committed tfvars; nothing sensitive is stored in git.
- **CI/CD-ready**: Structure supports plan/apply in pipelines (e.g. GitHub Actions, GitLab CI).

## Prerequisites

- [Node.js](https://nodejs.org/) (v18+) and npm — for `npm run` scripts (branch creation, Terraform helpers)
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- A [Datadog](https://www.datadoghq.com/) account with API and Application keys that can create and manage synthetics

**For the MCP development workflow** (exploring the GraphQL API and building out the synthetic suite):

- [Docker](https://docs.docker.com/get-docker/) — to run the Apollo MCP Server via `npm run mcp:start` or `mcp:start:auth`
- [Cursor](https://cursor.com/) (or another MCP-compatible IDE) — so the AI can use the MCP tools to introspect the schema and run queries
- The same Auth0 dev credentials as the GraphQL synthetics (see Required Environment Variables below) if you want to run *authenticated* queries via MCP

## Required Environment Variables

Set these before running Terraform (or use a non-committed `terraform.tfvars` file):

| Variable | Description | Example |
|----------|-------------|---------|
| `TF_VAR_dd_api_key` | Datadog API key | (from Datadog Organization Settings → API Keys) |
| `TF_VAR_dd_app_key` | Datadog Application key | (from Datadog Organization Settings → Application Keys) |

Optional:

| Variable | Description | Default |
|----------|-------------|---------|
| `TF_VAR_dd_api_url` | Datadog API base URL (site) | `https://api.datadoghq.com` (US1). Use `https://api.datadoghq.eu` for EU. |

**Dev multi-step test (Auth0 → GraphQL)** also needs (set via `TF_VAR_*` or in `.env`; never commit):

| Variable | Description |
|----------|-------------|
| `TF_VAR_dev_username` | Auth0 dev username (email) |
| `TF_VAR_dev_password` | Auth0 dev password |
| `TF_VAR_dev_client_secret` | Auth0 dev client secret |

Use **raw** values (e.g. `user+tag@gmail.com`), not URL-encoded; they are encoded when the Auth0 request is built (Terraform and the MCP token script).

**Never commit** `terraform.tfvars` or any file containing real API/app keys or Auth0 credentials. Use `terraform.tfvars.example` as a template only.

For npm scripts, put these variables in a `.env` file at the repo root (copy from `.env.example`). The `tf:*` scripts load `.env` automatically.

## Repository Structure

```
.
├── README.md
├── .env.example
├── .cursor/
│   └── mcp.json           # Cursor MCP: connects to Apollo MCP server (dev)
├── config/
│   ├── apollo-mcp.yaml            # Apollo MCP config (dev; no auth)
│   └── apollo-mcp-with-auth.yaml  # Apollo MCP config with Bearer token (dev)
├── docs/                  # Approach docs: schema ingestion, MCP, synthetics, dev-only scope
├── synthetic-data/        # Per-service synthetic data: which query uses which data (YAML per service)
├── package.json
├── tsconfig.json
├── scripts/
│   ├── new-branch.ts      # Create a new branch from main
│   ├── new-branch.test.ts
│   ├── terraform.ts       # Run Terraform with .env (init/plan/apply/validate)
│   ├── get-auth0-token.ts # Auth0 token for MCP (dev; same as synthetics)
│   └── mcp-start-with-auth.ts  # Start MCP server with Auth0 token (dev)
├── modules/
│   └── synthetic-api-test/    # Reusable module for one API synthetic test
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/
    │   ├── main.tf            # Provider + shared locals + test modules
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── tests.tf           # Additional tests (optional)
    │   └── terraform.tfvars.example
    └── prod/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── tests.tf
        └── terraform.tfvars.example
```

- **Environments**: Each environment (`dev`, `prod`) has its own Terraform state. Run `terraform` from the chosen environment directory.
- **Module**: `modules/synthetic-api-test` exposes inputs (name, URL, method, headers, assertions, locations, frequency, tags, status, message, etc.) and creates a single `datadog_synthetics_test` API test.
- **Multi-step tests**: Use `datadog_synthetics_test` with `subtype = "multi"` and multiple `api_step` blocks (e.g. Auth0 token then GraphQL). See `environments/dev/graphql.tf` and `.cursor/rules/datadog-graphql-synthetics.mdc` for implementation-derived instructions. To explore the API and design new tests, use the [MCP development workflow](#development-workflow-building-the-graphql-synthetic-suite) (Apollo MCP + Cursor).

## NPM Scripts (Node.js / TypeScript)

From the repo root, after `npm install`:

| Script | Description |
|--------|-------------|
| `npm run new-branch [name]` | Create and checkout a new branch from `main`. If `name` is omitted, you’re prompted. Use e.g. `LINEAR-123-feature-name`. |
| `npm test` | Run tests (e.g. `scripts/new-branch.test.ts`). |
| `npm run tf:init:dev` / `tf:init:prod` | Run `terraform init` in that environment (loads `.env`). |
| `npm run tf:plan:dev` / `tf:plan:prod` | Run `terraform plan` (loads `.env`). |
| `npm run tf:apply:dev` / `tf:apply:prod` | Run `terraform init` then `terraform apply -auto-approve` (loads `.env`). |
| `npm run tfvars:from-synthetic-data` | Generate `environments/dev/synthetic-data.auto.tfvars.json` from `synthetic-data/*.yaml` so Terraform gets injected values without setting variables by hand. Run after editing synthetic data, then plan/apply. |
| `npm run tf:validate:dev` / `tf:validate:prod` | Run `terraform validate` (loads `.env`). |
| **MCP (dev only)** | |
| `npm run mcp:select-schema` | Prompt to choose which federated schema to work on (Asset, Job, Timecard, User, Supergraph, or router). |
| `npm run mcp:start` | Start Apollo MCP Server (no auth). Cursor can introspect schema and run GraphQL queries. |
| `npm run mcp:start:auth` | Get Auth0 token and start MCP server with it so Cursor runs *authenticated* queries. |
| `npm run mcp:auth` | Print a fresh Auth0 access token (for debugging; requires dev credentials in `.env`). |
| `npm run mcp:schema` | Fetch schema and write `config/schema.graphql`. Uses Rover for the selected subgraph/supergraph if `APOLLO_KEY` is set; otherwise introspects the router. |

Ensure a `.env` file exists (copy from `.env.example`) with `TF_VAR_*` and any other variables Terraform needs. All `tf:*` commands load `.env` automatically via `dotenv-cli`. For authenticated MCP, the same Auth0 vars as the dev GraphQL synthetics are required (`TF_VAR_dev_username`, `TF_VAR_dev_password`, `TF_VAR_dev_client_secret`).

Alternative: run the Terraform script directly with `npx ts-node scripts/terraform.ts <init|plan|apply|validate> <dev|prod>`; it loads `.env` and runs Terraform in the chosen environment.

## Development workflow: building the GraphQL synthetic suite

We use **Apollo MCP Server** and **Cursor** to explore the dev GraphQL API (schema + run queries) and then turn that into synthetic tests. This is **dev-only**; production promotion is a separate process (see [docs/dev-only-scope.md](docs/dev-only-scope.md)).

### Targeting a federated schema

The dev graph is federated (Asset, Job, Timecard, User services, plus supergraph/API). To work on one schema at a time instead of the whole API:

1. Run **`npm run mcp:select-schema`** and choose the schema (e.g. Asset Service, User Service, or Supergraph).
2. Your choice is saved to `config/selected-schema.json` (gitignored). Then **`npm run mcp:schema`** (and **`mcp:start:auth`**) will use it: with **Rover** installed and **APOLLO_KEY** (and optional **APOLLO_GRAPH_REF**) in `.env`, the schema is fetched from GraphOS for that subgraph/supergraph; otherwise the script falls back to introspecting the router.
3. Option **“Use router introspection (full API)”** skips Rover and keeps the current behavior (full composed schema from the router).

Schema options and Studio links are in `config/schema-options.json`.

### Prerequisites for MCP

- **Docker** — Apollo MCP Server runs in a container (see [Prerequisites](#prerequisites)).
- **Cursor** — So the AI can use the MCP tools. The project’s `.cursor/mcp.json` is already configured; no manual MCP server entry in Cursor settings is needed.
- **`.env` with Auth0 (for authenticated queries)** — Same as the dev GraphQL synthetics: `TF_VAR_dev_username`, `TF_VAR_dev_password`, `TF_VAR_dev_client_secret`. Optional: `TF_VAR_dev_auth0_domain`. Without these you can still run `mcp:start` (no auth) if your dev graph allows unauthenticated access.

### Setup and how to use the MCP server

**One-time setup**

1. From the repo root: `npm install`
2. Copy `.env.example` to `.env` and fill in at least the Auth0 dev vars if you want authenticated queries: `TF_VAR_dev_username`, `TF_VAR_dev_password`, `TF_VAR_dev_client_secret`
3. Open this repo in Cursor (or restart Cursor / reload the window once) so it loads `.cursor/mcp.json`

**Each time you want to use MCP**

1. **Start the MCP server** in a terminal (from repo root):
   - **With auth** (recommended for our API):  
     ```bash
     npm run mcp:start:auth
     ```  
     This fetches an Auth0 token and starts the server with it. Requires the Auth0 vars in `.env`.
   - **Without auth**:  
     ```bash
     npm run mcp:start
     ```
2. Leave that terminal running. The server listens on port **8000**; Cursor connects to it via `.cursor/mcp.json`.
3. **In Cursor**, ask the AI to use the GraphQL tools, for example:
   - *“What’s on the Query type in our GraphQL schema?”*
   - *“Search the schema for types related to Asset.”*
   - *“Run the assetSystemCheck query and show me the response.”*

The AI will use the MCP tools (introspect, search, execute) against the **dev** GraphQL endpoint. Use the results to decide what synthetic data you need and to implement new query synthetics in Terraform.

**Stopping:** Stop the MCP server with `Ctrl+C` in the terminal where it’s running.

### What’s in place (reference)

- **Apollo MCP Server** — Runs in Docker and talks to the dev GraphQL router; exposes tools for schema introspection and running operations.
- **Cursor** — `.cursor/mcp.json` points at `http://127.0.0.1:8000/mcp`. No extra Cursor configuration required.
- **Config** — `config/apollo-mcp.yaml` (no auth), `config/apollo-mcp-with-auth.yaml` (with Bearer token). Default endpoint is the dev router.

### Workflow to build out the synthetic suite

1. **Explore** — With MCP running, use Cursor to introspect the schema and run queries. See what operations exist and what data they need (IDs, account context, etc.).
2. **Document required data** — When you see what the API needs, add entries to the required-data spec (see [docs/configurable-synthetic-data.md](docs/configurable-synthetic-data.md)) and supply values in the configured data store (e.g. `.env` or a config file).
3. **Implement query synthetics** — Add new GraphQL query tests in Terraform (e.g. `environments/dev/graphql_asset_service.tf`, `graphql_user_service.tf`) following the existing Auth0 → GraphQL pattern. Start with queries; they’re read-only and safe to run in dev.
4. **Implement mutation workflows later** — Mutations are exercised as multi-step workflows (create → modify → delete) so we don’t leave synthetic data in the environment. Use MCP to explore mutation shapes, then design those workflows.

Detailed docs: [docs/apollo-mcp-cursor.md](docs/apollo-mcp-cursor.md), [docs/queries-as-synthetics.md](docs/queries-as-synthetics.md), [docs/mutations-as-workflows.md](docs/mutations-as-workflows.md). For the big picture and dev-only scope, see [docs/README.md](docs/README.md).

## Quick Start

### 1. Install dependencies and set up environment

```bash
npm install
cp .env.example .env
# Edit .env with your Datadog API key, app key, and any Auth0/dev credentials.
```

### 2. Initialize Terraform

From the repo root you can use npm (recommended) or run Terraform manually:

```bash
# Using npm (loads .env automatically)
npm run tf:init:dev

# Or manually
cd environments/dev
terraform init
```

### 3. Plan Changes

```bash
# Using npm (loads .env)
npm run tf:plan:dev

# Or manually: set TF_VAR_* then run terraform plan in environments/dev
```

Review the plan to see which synthetic tests will be created or updated.

### 4. Apply Changes

When the plan looks correct:

```bash
# Using npm (loads .env, runs init + apply -auto-approve)
npm run tf:apply:dev

# Or manually: terraform apply (confirm with yes or use -auto-approve)
```

### 5. Using a tfvars File (Optional)

Copy the example and edit locally (do not commit the copy):

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your API key, app key, URLs, etc.
terraform plan
terraform apply
```

Keep `terraform.tfvars` out of version control (it is in `.gitignore`).

## Validation

- **Format**: `terraform fmt -recursive`
- **Validate**: From an environment directory, run `terraform validate`
- **Plan**: Always run `terraform plan` before `apply` to avoid surprises

## Adding a New Synthetic API Test

1. Open the environment where the test should exist (e.g. `environments/dev/main.tf` or `environments/dev/tests.tf`).

2. Add a new `module` block that uses the reusable module. Example for a second test:

```hcl
module "my_api_health" {
  source = "../../modules/synthetic-api-test"

  name      = "My API health (${local.env_name})"
  status    = "live"
  message   = "My API health check failed in ${local.env_name}."
  locations = local.locations
  frequency = local.frequency
  tags      = concat(local.base_tags, ["service:my-api"])

  request_url    = "https://api.example.com/health"
  request_method = "GET"
  request_headers = {
    "Accept" = "application/json"
  }
  assertions = [
    { type = "statusCode", operator = "is", target = "200" },
    { type = "responseTime", operator = "lessThan", target = "3000" }
  ]
}
```

3. Use a **unique module name** (e.g. `my_api_health`) per test.

4. Rely on **locals** (`local.locations`, `local.frequency`, `local.base_tags`) to avoid duplication; override any variable when this test needs different values.

5. Add outputs in `outputs.tf` if you need to expose the new test’s ID or monitor ID.

6. Run `terraform plan` and `terraform apply` from that environment directory.

The module supports: `name`, `request_url`, `request_method`, `request_headers`, `assertions`, `locations`, `frequency`, `tags`, `status`, `message`, and optional `retry_count` / `follow_redirects`. See `modules/synthetic-api-test/variables.tf` for the full list.

## Deployment and CI/CD

- **Per-environment**: Run Terraform from the correct environment directory (`environments/dev` or `environments/prod`). Use separate state (e.g. different S3 backend keys or workspaces) per environment.

- **Credentials in CI**: Store `TF_VAR_dd_api_key` and `TF_VAR_dd_app_key` as secrets in your CI system. Set `TF_VAR_dd_api_url` if you use a non-US1 site.

- **Typical pipeline**:
  1. **On PR**: Run `terraform init`, `terraform validate`, `terraform plan` and (optionally) post the plan as a comment.
  2. **On merge to main** (or a release): Run `terraform init`, `terraform plan -out=tfplan`, `terraform apply -auto-approve tfplan` for each environment (e.g. dev first, then prod), using that environment’s state and secrets.

- **Remote state**: Uncomment and configure the `backend` block in each environment’s `main.tf` (e.g. S3 + DynamoDB for locking) so that CI and local runs share the same state.

- **Approval**: Prefer requiring a manual approval or separate job for `apply` in production.

## Assumptions

- Only **API** synthetics (HTTP) are in scope; browser or other test types would need a different module or resource.
- **One state per environment** (directory-based); no Terraform workspaces in the examples.
- **Secrets** are never committed; they are provided via env vars or secure tfvars.
- **Tags** include `env`, `managed_by:terraform`, and `project:railway` by default; you can extend or change these in each environment’s `main.tf` or `tests.tf`.

## License

Internal use; adjust as needed for your organization.
