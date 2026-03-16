# Configurable Synthetic Data

## Goal

When synthetics need **specific pieces of data per environment** (e.g. user IDs, asset IDs, org IDs, test account credentials), that data should be:

- **Configurable outside the project** — Not hardcoded in test code; supplied in a single, well-defined place in the framework.
- **Environment-specific** — Easy to swap values per environment (dev, staging, prod) so the same suite runs everywhere with the right data.
- **Discoverable** — Cursor (or the AI) can document what data is required; the end user reads that doc and supplies the values.
- **Iterative** — As we add synthetics, we add new required fields to the doc; the user adds new values to the config; we avoid scattering secrets or IDs across the codebase.

## Flow

1. **Discovery** — While building or exploring synthetics (e.g. via Apollo MCP, schema, or existing tests), Cursor determines what data a synthetic needs (e.g. “query `user(id)` needs a valid `userId`”).
2. **Document** — Cursor updates a **required-data spec** (a doc or manifest in the framework) that lists each required piece of data: name, purpose, which synthetics use it, and where to supply it.
3. **Supply** — The end user reads the spec and adds the corresponding values to the **configured data store** (e.g. env file or config file) for the relevant environment(s).
4. **Consume** — The framework reads from that store at runtime so synthetics use the configured data without hardcoding it.

This cycle repeats as new queries, mutations, or workflows are added: Cursor adds new entries to the spec, the user fills in new keys, and the framework keeps reading from the same store.

## Required-data spec (to be defined)

A **single source of truth** that describes what data the framework needs. Maintained by Cursor (or humans) as the synthetic suite grows.

- **Location**: **[synthetic-test-config/](../synthetic-test-config/)** — YAML per service per environment (e.g. `graphql/dev/asset-service.yaml`), plus `docs/required-synthetic-data.md` for a short index.
- **Contents** (per required item):
  - **Key / name** — Identifier used in the config store and in code (e.g. `TEST_USER_ID`, `SAMPLE_ASSET_ID`).
  - **Purpose** — Short description (e.g. “User ID for `user(id)` query synthetic”).
  - **Used by** — Which synthetics or workflows use this (e.g. “Query: GetUser”, “Workflow: UpdateAsset”).
  - **Where to set** — Reference to the configured data store (e.g. “Set in `.env` or `config/synthetic-data.<env>.json`”).
  - **Example / format** — Optional hint (e.g. “UUID”, “email”, “ID from GraphQL”).

The spec is the contract: Cursor tells the end user what to supply here; the user does not have to infer from code.

## Configured data store (to be defined)

A **single place in the framework** where the user puts values for each required key. Environment-specific so data can differ per environment.

- **Options** (pick one or a small set):
  - **Env file** — e.g. extend `.env` (or `synthetic-data.env`) with keys like `TEST_USER_ID`, `SAMPLE_ASSET_ID`. Loaded before runs; values can be swapped per environment via different `.env` files or CI secrets.
  - **Config file** — e.g. `config/synthetic-data.json` or `config/synthetic-data.<env>.yaml` (e.g. `synthetic-data.dev.yaml`, `synthetic-data.prod.yaml`) with key-value pairs. Can be gitignored for values; commit a template or example.
- **Rules**:
  - Framework code never hardcodes these values; it always reads from the store.
  - One canonical list of keys (the spec); the store holds only values. Missing keys can be validated at startup or per-synthetic and reported with a pointer to the spec.

## Iterative build-out

- **New synthetic needs data** → Cursor adds an entry to the required-data spec and (if applicable) a placeholder or comment in the config template.
- **User** → Fills in the new key in their local or CI config for the environments they care about.
- **Existing synthetics** → Unchanged; they already read from the same store.
- **Swapping environments** → User points the framework at a different env or config file (e.g. different `.env` or `synthetic-data.prod.yaml`); no code change.

## Relationship to other docs

- **Apollo MCP + Cursor** ([apollo-mcp-cursor.md](./apollo-mcp-cursor.md)): Exploration via MCP often reveals what IDs or credentials are needed; that feeds into the required-data spec.
- **Queries as synthetics** ([queries-as-synthetics.md](./queries-as-synthetics.md)): Query synthetics consume configured data (e.g. IDs for “get by ID” queries).
- **Mutations as workflows** ([mutations-as-workflows.md](./mutations-as-workflows.md)): Workflows may need starting IDs, credentials, or org context from the config store.
- **Schema ingestion** ([schema-ingestion.md](./schema-ingestion.md)): Schema and operations inform which fields are required; the spec translates that into concrete keys the user can supply.
