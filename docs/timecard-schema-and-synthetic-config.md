# Timecard schema and synthetic test config

Use this when defining or extending **timecard** synthetic tests.

## 1. Synthetic test config schema (YAML)

Config files:

- **Dev:** `synthetic-test-config/graphql/dev/timecard-service.yaml`
- **Prod:** `synthetic-test-config/graphql/prod/timecard-service.yaml`

Full YAML schema (queries, `synthetic_data`, assertions, locations): **[synthetic-test-config-schema.md](./synthetic-test-config-schema.md)**.

Each query entry can have:

| Key | Required | Description |
|-----|----------|-------------|
| `name` | Yes | GraphQL query name (e.g. `timecardSystemCheck`) |
| `excluded` | No | `true` = no Datadog test created; default `false` |
| `synthetic_data` | No | List of `{ key, value, purpose, where_to_set, format }` for variables |
| `notes` | No | Free-form notes |
| `locations` | No | e.g. `["aws:us-east-1", "aws:us-west-2", "gcp:us-west1"]` |
| `assertions` | No | List of `{ jsonpath, operator, targetvalue }` on the response |

## 2. Timecard GraphQL schema (queries and types)

The Timecard service is a **federated subgraph**. Its full schema is not stored in this repo; you fetch it from GraphOS via **Rover**. The Apollo MCP server does **not** fetch from Studio — it reads the local file **`config/schema.graphql`**. So the flow is: **fetch schema (Rover) → write to config/schema.graphql → start MCP → Cursor’s introspect/search use that schema.**

### Refresh Timecard schema for MCP (`config/schema.graphql`)

The Apollo MCP server reads **`config/schema.graphql`** only; it does not pull from Studio. Populate it with the same **`npm run mcp:schema`** flow as every other subgraph.

1. Set **`APOLLO_KEY`** in `.env` (from [Apollo Studio](https://studio.apollographql.com) → your graph → Settings → API keys). Ensure [Rover](https://www.apollographql.com/docs/rover/) is installed (`npm i -g @apollo/rover`).
2. Either:
   - **Interactive:** Run `npm run mcp:select-schema`, choose **Timecard Service**, then `npm run mcp:schema` (selection is stored in `config/selected-schema.json`, gitignored), **or**
   - **One-shot:**  
     ```bash
     npm run mcp:schema -- --schema=Dev-TimecardService
     ```  
     This uses the same Rover subgraph fetch as the interactive path and writes **`config/schema.graphql`** with the Timecard subgraph SDL (without updating `selected-schema.json`).
3. Start the MCP server (`npm run mcp:start` or `npm run mcp:start:auth`). Cursor’s **introspect** and **search** tools use whatever SDL is in **`config/schema.graphql`**.

### Other subgraphs

Use `mcp:select-schema` + `mcp:schema`, or pass the schema id:

```bash
npm run mcp:schema -- --schema=Dev-AssetService
```

Valid ids are in **`config/schema-options.json`**.

### Apollo Studio (browser)

To view or copy the SDL in the browser (logged in to Apollo):

- **Timecard schema (SDL):**  
  https://studio.apollographql.com/graph/Ribbiot-Serverless/variant/dev-current/schema/sdl?selectedSchema=Dev-TimecardService

### Known query (already in use)

From the existing Terraform and config:

- **`timecardSystemCheck(input: SystemCheckInput)`**  
  - **Input:** `SystemCheckInput` (`checkLaunchDarkly`, `checkSQL`).  
  - **Response:** `message`, `environment`, `featureFlags`, `launchDarklyStatus`, `sqlStatus`.

To add more timecard queries (e.g. timecard list, submit, etc.), refresh the Timecard SDL in `config/schema.graphql` (steps above), then define new entries in `synthetic-test-config/graphql/dev/timecard-service.yaml` (and prod) with the right `synthetic_data` and `assertions`; then run `npm run tfvars:from-synthetic-test-config` and add the corresponding test step in `environments/dev/graphql_timecard_service.tf` (see [synthetic-test-config-workflow](.cursor/rules/synthetic-test-config-workflow.mdc) and [datadog-graphql-synthetics](.cursor/rules/datadog-graphql-synthetics.mdc)).
