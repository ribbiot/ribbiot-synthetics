# Synthetic data

This folder is the **source of truth** for GraphQL synthetic tests: input data to inject, which geos each test runs in, and assertions on responses. **Dev and prod are in separate files** so the data you supply for dev (e.g. dev account IDs, task IDs) stays distinct from prod.

## Scope and layout

- **GraphQL:** Config lives under **`graphql/<env>/`** — one set of files for **dev** and one for **prod**.
- **Per environment:** Each file is for a single environment. You edit `graphql/dev/asset-service.yaml` for dev data and `graphql/prod/asset-service.yaml` for prod data; no shared file with both.
- **Schema:** Full field reference is in [docs/synthetic-test-config-schema.md](../docs/synthetic-test-config-schema.md).

## Purpose

- **Input data** — Set `key` and `value` in `synthetic_data` per env. `npm run tfvars:from-synthetic-test-config` writes `environments/<env>/synthetic-test-config.auto.tfvars.json` for each env so Terraform doesn’t need variables set by hand.
- **Geos** — `locations` on each query lists Datadog location IDs. **Framework default** (cost control): use `aws:us-east-1`, `aws:us-west-2`, `gcp:us-west1` unless a test needs different geos.
- **Excluded** — Set `excluded: true` on a query to omit it from Terraform test generation only (e.g. endpoint unused or unreliable data). Excluded queries’ synthetic_data is still written to tfvars so existing Datadog globals are not destroyed.
- **Assertions** — `assertions` lists JSONPath checks (jsonpath, operator, targetvalue) to apply to the GraphQL response. You can derive these from a sample response (see below).

## Files (GraphQL, per environment)

| Service   | Dev file | Prod file |
|----------|----------|-----------|
| Asset    | [graphql/dev/asset-service.yaml](graphql/dev/asset-service.yaml) | [graphql/prod/asset-service.yaml](graphql/prod/asset-service.yaml) |
| Job      | graphql/dev/job-service.yaml | graphql/prod/job-service.yaml |
| User     | graphql/dev/user-service.yaml | graphql/prod/user-service.yaml |
| Timecard | graphql/dev/timecard-service.yaml | graphql/prod/timecard-service.yaml |

## Deriving assertions from a sample response

To turn a **real response** from a dev GraphQL call into a list of assertions:

1. Save the JSON response to a file (e.g. `response.json`), or pipe it: `curl ... | npx tsx scripts/derive-assertions-from-response.ts -`.
2. Run:
   ```bash
   npx tsx scripts/derive-assertions-from-response.ts response.json
   ```
   For a response shaped like `{ "data": { "queryName": { ... } } }`, pass the query name so paths are rooted correctly:
   ```bash
   npx tsx scripts/derive-assertions-from-response.ts response.json --query scheduledAssetsForTasks
   ```
3. The script prints a YAML **assertions:** block. Paste it under the right query in **`synthetic-test-config/graphql/dev/<service>.yaml`** (or prod).
4. Optionally trim or relax assertions (e.g. remove flaky paths, change operator). Use `--terraform` to emit Terraform local value format instead of YAML.

See [docs/synthetic-test-config-schema.md](../docs/synthetic-test-config-schema.md#deriving-assertions-from-a-sample-response).

## Injecting values into Terraform

Run:

```bash
npm run tfvars:from-synthetic-test-config
```

This reads **`synthetic-test-config/graphql/dev/*.yaml`** and **`synthetic-test-config/graphql/prod/*.yaml`**, collects all `synthetic_data[].key`/`value` per env (skipping empty placeholders; excluded queries still emit values so globals are kept), and writes:

- `environments/dev/synthetic-test-config.auto.tfvars.json`
- `environments/prod/synthetic-test-config.auto.tfvars.json`

Terraform in each env uses `var.synthetic_data_values` from that file. To generate only one env:

```bash
npx tsx scripts/synthetic-test-config-to-tfvars.ts --env dev
# or --env prod
```

Run after editing synthetic data, then `npm run tf:plan:dev` or `tf:apply:prod` as needed.

## Relationship to Terraform

- **Values** — Driven by this folder via the tfvars script, per environment.
- **Implemented / locations / assertions** — Today Terraform still defines tests and their locations/assertions in HCL. This YAML is the source of truth for *what* should be on, *where*, and *which assertions*; future work can codegen or sync Terraform from it.
