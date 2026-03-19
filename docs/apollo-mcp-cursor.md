# Apollo MCP Server + Cursor for Schema and Query Exploration

## Scope: dev only

This setup is for the **dev environment only**. Do not point it at production. Promoting to production will be a separate process (see [Dev-only scope and production firewall](./dev-only-scope.md)).

## Goal

Connect our Apollo Server (dev) to **Cursor via Apollo MCP Server** so that:

1. **Cursor (and the AI) can get the schema** — Introspection tools expose the graph schema to the model’s context.
2. **Cursor can run queries** — The `execute` tool runs GraphQL operations against our API so we can see real responses and **infer what synthetic data we need** to build synthetic tests.

This supports the synthetic-test workflow: explore the API from the IDE, then implement queries as synthetics and mutations as workflows.

## Why this approach

- **Single source of truth**: Schema and operations come from the live (or staged) Apollo Server, so we stay aligned with the real API.
- **Discovery in context**: The AI in Cursor can introspect types, search the schema, and run queries without leaving the editor — ideal for designing test payloads and assertions.
- **No separate tooling**: We don’t need a separate script or UI to “understand” the API; Cursor + MCP is the exploration environment.
- **Reuse existing MCP setup**: Cursor already supports MCP (e.g. other servers like Linear); adding Apollo MCP Server follows the same pattern.

Reference: [Apollo MCP Server docs](https://www.apollographql.com/docs/apollo-mcp-server).

## How Apollo MCP Server supports this

The MCP server **does not fetch the schema from Studio**. It reads the **local schema file** `config/schema.graphql` (mounted as `/data/schema.graphql` in Docker). You populate that file by running the schema fetch script (Rover) **before** starting the MCP server — e.g. `npm run mcp:schema:timecard` for the Timecard subgraph, or `npm run mcp:select-schema` then `npm run mcp:schema` for the selected subgraph. Once `config/schema.graphql` is set, the MCP server exposes **introspection tools**:

| Tool       | Purpose |
|-----------|---------|
| `introspect` | Get schema for a type name and depth — e.g. start from `Query` or `Mutation` to see operations and types. |
| `search`     | Search the schema by terms; returns type info and parent context so we can build operations. |
| `validate`   | Validate a GraphQL operation against the schema without executing it. |
| `execute`    | Run a GraphQL operation against the GraphQL endpoint. |

With these enabled, Cursor can:

- Load schema (and optionally minify it to save context) to understand types and fields.
- Run queries via `execute` to see response shapes and required/optional data.
- Use that to decide what synthetic data to supply (e.g. IDs, env vars, test users) and how to assert in synthetic tests.

## Setup (project-configured)

The project includes config and scripts so you can run the Apollo MCP server and connect Cursor with minimal steps.

### 1. (Optional) Choose a federated schema

The dev graph is federated (Asset, Job, Timecard, User services, plus supergraph/API). To get a **single subgraph schema** into `config/schema.graphql` (so MCP introspect/search see only that service):

- **Timecard only:** Run **`npm run mcp:schema:timecard`** (requires `APOLLO_KEY` and Rover). Then start the MCP server; Cursor will see the Timecard subgraph schema.
- **Any other:** Run **`npm run mcp:select-schema`** and pick the schema (e.g. Asset Service, User Service, or Supergraph). Your choice is stored in `config/selected-schema.json` (gitignored). Then run **`npm run mcp:schema`** — it uses **Rover** to fetch that subgraph/supergraph from GraphOS if **APOLLO_KEY** is set; otherwise it introspects the router (full composed API).
- To fetch a specific schema without changing the selection: **`npm run mcp:schema -- --schema=Dev-TimecardService`** (ids in `config/schema-options.json`).

### 2. Variables

In `.env` (see `.env.example`):

| Variable | Purpose |
|----------|---------|
| `APOLLO_GRAPHQL_ENDPOINT` | GraphQL endpoint the MCP server calls (default in config: dev router). Override for staging/prod or a local graph. |
| **For Auth0 (needed for `mcp:start:auth`):** | Same as multi-step synthetics — do not commit. |
| `TF_VAR_dev_username` | Auth0 dev user (e.g. test user email). |
| `TF_VAR_dev_password` | Auth0 dev password. |
| `TF_VAR_dev_client_secret` | Auth0 app client secret. |
| `TF_VAR_dev_auth0_domain` | Optional; default `devauth.ribbiot.com`. |
| **For Rover (targeted schema fetch):** | |
| `APOLLO_KEY` | GraphOS API key (for `rover subgraph fetch` / `rover supergraph fetch`). Optional. |
| `APOLLO_GRAPH_REF` | Graph ref (e.g. `Ribbiot-Serverless@dev-current`). Optional; default in config. |

Config file: `config/apollo-mcp.yaml` uses `${env.APOLLO_GRAPHQL_ENDPOINT:-...}` so the default works without any env.

### 3. Start the Apollo MCP server

From the repo root, with Docker available:

**Without auth (public or unauthenticated graph):**

```bash
npm run mcp:start
```

**With Auth0 (same credentials as our synthetics):**

Our GraphQL API expects a Bearer token. The project reuses the same Auth0 password grant as the multi-step synthetics (`environments/dev/graphql.tf`). Ensure `.env` has the same vars you use for Terraform:

- `TF_VAR_dev_username` — Auth0 dev user (e.g. test user email)
- `TF_VAR_dev_password` — Auth0 dev password
- `TF_VAR_dev_client_secret` — Auth0 app client secret  
- (Optional) `TF_VAR_dev_auth0_domain` — Auth0 domain (default: `devauth.ribbiot.com`)

Then start the MCP server with a fresh token:

```bash
npm run mcp:start:auth
```

This fetches an access token via Auth0, then starts the Apollo MCP server with `Authorization: Bearer <token>`. Cursor’s `execute` tool will then run authenticated queries.

**Token only (e.g. for debugging or manual calls):**

```bash
npm run mcp:auth
```

Prints the access token to stdout (credentials must be in `.env`).

---

Both `mcp:start` and `mcp:start:auth` run the [Apollo MCP Server](https://www.apollographql.com/docs/apollo-mcp-server/run) in Docker and expose **port 8000**. The server uses Streamable HTTP and introspection tools (`introspect`, `search`, `validate`, `execute`).

To override the GraphQL endpoint, set `APOLLO_GRAPHQL_ENDPOINT` in `.env` (or export it) before running.

Keep the MCP server process running in a terminal while you use Cursor.

**Without Docker:** Install the [standalone binary](https://www.apollographql.com/docs/apollo-mcp-server/run#standalone-mcp-server-binary). Use `config/apollo-mcp.yaml` for no auth, or `config/apollo-mcp-with-auth.yaml` with `AUTH0_ACCESS_TOKEN` set (e.g. from `npm run mcp:auth`).

### 4. Connect Cursor to the MCP server

The project defines a **project-level** MCP server in `.cursor/mcp.json`. Cursor uses this when the workspace is open.

- **Server name:** `apollo-graphql`
- **Connection:** Cursor runs `npx mcp-remote http://127.0.0.1:8000/mcp`, which proxies to the Apollo MCP server you started in step 2.

No manual “Add MCP Server” in Cursor settings is required; the config in `.cursor/mcp.json` is picked up automatically. If you already have a global MCP server with the same name, the project-level one takes precedence.

**First time:** Restart Cursor (or reload the window) after pulling the project so it loads `.cursor/mcp.json`. Then ensure the MCP server process from step 2 is running; Cursor will connect when it needs the tools.

### 5. Use the tools in Cursor

Once the server is running and Cursor has reloaded:

- Ask the AI to **introspect** the schema (e.g. “What’s on the Query type?”) or **search** for types.
- Ask it to **run a GraphQL query** (it will use the `execute` tool against your configured endpoint).
- Use the responses to decide what synthetic data to add to the [required-data spec](./configurable-synthetic-data.md) and to implement [queries as synthetics](./queries-as-synthetics.md).

### Auth summary

- **Authenticated (recommended for our API):** Use `npm run mcp:start:auth` with `TF_VAR_dev_username`, `TF_VAR_dev_password`, and `TF_VAR_dev_client_secret` in `.env` — same as the multi-step GraphQL synthetics.
- **Unauthenticated:** Use `npm run mcp:start`; no token is sent. Use only if your graph allows anonymous access.

## Relationship to other docs

- **Schema ingestion** ([schema-ingestion.md](./schema-ingestion.md)): MCP is one way to *obtain* and use the schema; we may still persist a copy (e.g. for CI or codegen) via a separate pipeline.
- **Queries as synthetics** ([queries-as-synthetics.md](./queries-as-synthetics.md)): Exploring with MCP (schema + `execute`) informs which queries to implement and what synthetic data they need.
- **Mutations as workflows** ([mutations-as-workflows.md](./mutations-as-workflows.md)): Same idea — use MCP to explore mutations and response shapes, then design create → modify → delete workflows and required synthetic data.
