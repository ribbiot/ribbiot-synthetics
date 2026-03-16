# Synthetic data

This folder holds **synthetic data per service graph**: which data each query needs and **the actual values to inject** into synthetic tests. One place to set test IDs, account IDs, task IDs, etc., so Terraform (or the pipeline) can read them without hardcoding in test code.

## Purpose

- **One place per service** — Each service (Asset, Job, User, Timecard) has a file that lists its queries and the synthetic data each query uses.
- **Query → data + values** — For every query we implement (or plan to), we record which variables/IDs/inputs it needs and **set the value here** (e.g. task IDs, asset IDs). Those values are what get injected into the synthetics (via Terraform globals or a script that reads this folder).
- **Dev-only** — This is for the dev synthetic suite. Production promotion and prod-specific data are separate.

See [docs/configurable-synthetic-data.md](docs/configurable-synthetic-data.md) for the overall flow (discover → document → supply → consume).

## Files

| File | Service graph | Terraform tests |
|------|----------------|-----------------|
| [asset-service.yaml](asset-service.yaml) | Dev-AssetService | `environments/dev/graphql_asset_service.tf` |
| [job-service.yaml](job-service.yaml) | Dev-JobService | `environments/dev/graphql_job_service.tf` |
| [user-service.yaml](user-service.yaml) | Dev-UserService | `environments/dev/graphql_user_service.tf` |
| [timecard-service.yaml](timecard-service.yaml) | Dev-TimecardService | `environments/dev/graphql_timecard_service.tf` |

## Format

Each service file is YAML with:

- **service** — Human-readable service name.
- **graph** — Schema option ID (matches `config/schema-options.json`), e.g. `Dev-AssetService`.
- **terraform_file** — Path to the Terraform file that defines synthetics for this service.
- **queries** — List of query entries:
  - **name** — GraphQL query name (e.g. `assetSystemCheck`, `assetTemplates`).
  - **implemented** — Whether we have a synthetic test for this query (`true` / `false`).
  - **synthetic_data** — List of data items this query needs. Each item has:
    - **key** — Variable name used in synthetics (e.g. `DEV_ASSET_ACCOUNT_ID`). Matches the Datadog global or Terraform var name.
    - **value** — **Actual value to inject** (string, array, etc.). This is the default/configured value for the synthetic test.
    - **purpose** — Short description.
    - **where_to_set** — Where this value is consumed (e.g. Terraform var → global variable). Values are set in this file; overrides can come from Terraform/vars.
    - **format** — Optional hint (e.g. `ID`, `Date!`, `UUID`).
  - **notes** — Optional (e.g. "Not enabled in all geos until tuned").

When you add a new query synthetic or a new data requirement, update the corresponding service file here (including the **value** to inject) and (if needed) the Terraform variable / global variable in the environment.

**Injecting values into Terraform:** Run `npm run tfvars:from-synthetic-data` to generate `environments/dev/synthetic-data.auto.tfvars.json` from the `value` fields in these YAML files. Terraform (when run from `environments/dev`) auto-loads that file, so you don't set variables by hand. Run the script after editing synthetic data, then `npm run tf:plan:dev` or `tf:apply:dev`.
