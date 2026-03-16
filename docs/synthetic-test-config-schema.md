# Synthetic Test Config Schema (GraphQL)

This doc describes the YAML schema for **graphql** synthetic test config (data, locations, implemented, assertions). The same repo may later use a different structure for other backends (e.g. Supabase).

## Scope and layout

- **Scope:** `scope: graphql` — this config is for GraphQL multi-step synthetics (Auth0 → GraphQL). Other scopes (e.g. `supabase`) may be added with a different shape.
- **Separate files per environment:** Dev and prod config live in **different files** so values and config don’t get mixed:
  - **Dev:** `synthetic-test-config/graphql/dev/<service>.yaml` (e.g. `dev/asset-service.yaml`)
  - **Prod:** `synthetic-test-config/graphql/prod/<service>.yaml` (e.g. `prod/asset-service.yaml`)
- The tfvars script reads `graphql/<env>/*.yaml` and writes `environments/<env>/synthetic-test-config.auto.tfvars.json` for that env only.

## Top-level keys (per file)

| Key | Required | Description |
|-----|----------|-------------|
| `scope` | Yes | `graphql` (or future: `supabase`, etc.) |
| `environment` | Yes | `dev` or `prod` — must match the folder (dev/ or prod/) |
| `service` | Yes | Human-readable service name (e.g. "Asset inventory service") |
| `graph` | Yes | Schema/graph ID (e.g. `Dev-AssetService` for dev, `Prod-AssetService` for prod) |
| `terraform_file` | No | Path to the Terraform file for this env (e.g. `environments/dev/graphql_asset_service.tf`) |
| `queries` | Yes | List of query entries (see below) |

## Query entry

Each item in `queries` has (all per-environment, since the file is already for one env):

| Key | Required | Description |
|-----|----------|-------------|
| `name` | Yes | GraphQL query name (e.g. `assetSystemCheck`, `scheduledAssetsForTasks`) |
| `synthetic_data` | No | List of input data items (key, value, purpose, where_to_set, format). Values are injected as Terraform globals for this env. |
| `notes` | No | Free-form notes. |
| `implemented` | Yes | Whether a synthetic test exists in Terraform for this query in this env (`true` / `false`) |
| `locations` | No | List of Datadog location IDs (e.g. `["aws:us-east-1", "aws:ca-central-1"]`). If omitted, Terraform uses the env default. |
| `assertions` | No | List of body assertions (JSONPath) to apply to the GraphQL response. See [Assertions](#assertions). |

## Synthetic data item

Used in `queries[].synthetic_data`:

| Key | Required | Description |
|-----|----------|-------------|
| `key` | Yes | Global variable name (e.g. `DEV_ASSET_ACCOUNT_ID` in dev, `PROD_ASSET_ACCOUNT_ID` in prod). Must not be `(input)` for value collection. |
| `value` | No | Value to inject (string or array). Arrays are JSON-encoded when generating tfvars. Empty string or empty array is skipped (placeholder). |
| `purpose` | No | Short description. |
| `where_to_set` | No | Where the value is consumed (e.g. Terraform global). |
| `format` | No | Hint (e.g. `ID`, `UUID`). |

## Assertions

Each assertion is a **validatesJSONPath**-style check on the response body:

| Key | Required | Description |
|-----|----------|-------------|
| `jsonpath` | Yes | JSONPath expression (e.g. `$.data.assetSystemCheck.message`) |
| `operator` | Yes | Usually `is` (equality). Datadog supports others (e.g. `contains`, `matches`) |
| `targetvalue` | Yes | Expected value (string or number; matches the type at that path) |

These map directly to Datadog’s `assertion { type = "body", operator = "validatesJSONPath", targetjsonpath { ... } }`.

### Deriving assertions from a sample response

Use the script **`scripts/derive-assertions-from-response.ts`** to turn a JSON response (e.g. from a dev GraphQL call) into a list of assertions:

- Input: path to a JSON file (or stdin).
- Optional: `--query <name>` to prefix paths with the typical `data.<queryName>` root.
- Output: YAML snippet of `assertions:` you can paste into **`synthetic-test-config/graphql/dev/<service>.yaml`** (or prod) under the right query.

The script walks the JSON and emits one assertion per leaf (string, number, boolean). You can then trim or relax assertions (e.g. remove flaky paths, change operator).

## Example (dev file fragment)

**File:** `synthetic-test-config/graphql/dev/asset-service.yaml`

```yaml
scope: graphql
environment: dev
service: Asset inventory service
graph: Dev-AssetService
terraform_file: environments/dev/graphql_asset_service.tf

queries:
  - name: assetSystemCheck
    synthetic_data: []
    notes: No extra data.
    implemented: true
    locations:
      - aws:us-east-1
      - aws:ca-central-1
    assertions:
      - jsonpath: "$.data.assetSystemCheck.message"
        operator: is
        targetvalue: "Asset Service is Running!"
      - jsonpath: "$.data.assetSystemCheck.launchDarklyStatus"
        operator: is
        targetvalue: "OK"

  - name: getAssetImportUploadPresignedUrl
    synthetic_data:
      - key: DEV_ASSET_ACCOUNT_ID
        value: "dfb43473-e136-4ede-971f-3238b18d1f8b"
        purpose: Account ID for presigned upload URL
        where_to_set: Terraform global DEV_ASSET_ACCOUNT_ID
        format: ID
    implemented: true
    locations:
      - aws:ca-central-1
```

**File:** `synthetic-test-config/graphql/prod/asset-service.yaml` — same structure, prod-specific keys and values (e.g. `PROD_ASSET_ACCOUNT_ID`, different IDs or empty until configured).

## Relationship to Terraform

- **Values:** `npm run tfvars:from-synthetic-test-config` reads `synthetic-test-config/graphql/<env>/*.yaml` for each env, collects all `synthetic_data[].key`/`value` (skipping empty placeholders), and writes `environments/<env>/synthetic-test-config.auto.tfvars.json`. Terraform in that env uses `var.synthetic_data_values` and creates Datadog globals. Use `--env dev` or `--env prod` to generate only one env.
- **Implemented / locations:** Today Terraform still defines tests and locations in HCL. The YAML is the source of truth for *what* should be on and *where*; future work can drive Terraform test creation and `locations` from these files (e.g. codegen or a provider).
- **Assertions:** Assertions in YAML can be copy-pasted into Terraform `locals` or a future codegen step can emit Terraform assertion blocks from the YAML.
