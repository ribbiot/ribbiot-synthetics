# Datadog Synthetic API Tests as Code

This repository defines and manages **Datadog Synthetic API tests** using Terraform. Tests are version-controlled, reviewed via pull requests, and deployed from code instead of the Datadog UI.

## Purpose

- **Single source of truth**: All synthetic API tests live in Terraform.
- **Multi-environment**: Separate `dev` and `prod` (and more) with their own state and config.
- **Reusable module**: Add new tests with minimal duplication via the `synthetic-api-test` module.
- **Secrets-safe**: Credentials are supplied via environment variables or non-committed tfvars; nothing sensitive is stored in git.
- **CI/CD-ready**: Structure supports plan/apply in pipelines (e.g. GitHub Actions, GitLab CI).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- A [Datadog](https://www.datadoghq.com/) account with API and Application keys that can create and manage synthetics

## Required Environment Variables

Set these before running Terraform (or use a non-committed `terraform.tfvars` file):

| Variable | Description | Example |
|----------|-------------|---------|
| `TF_VAR_dd_api_key` or `DD_API_KEY` | Datadog API key | (from Datadog Organization Settings → API Keys) |
| `TF_VAR_dd_app_key` or `DD_APP_KEY` | Datadog Application key | (from Datadog Organization Settings → Application Keys) |

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

**Never commit** `terraform.tfvars` or any file containing real API/app keys or Auth0 credentials. Use `terraform.tfvars.example` as a template only.

## Repository Structure

```
.
├── README.md
├── .gitignore
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
- **Multi-step tests**: Use `datadog_synthetics_test` with `subtype = "multi"` and multiple `api_step` blocks (e.g. Auth0 token then GraphQL). See `environments/dev/graphql.tf` and `.cursor/rules/datadog-graphql-synthetics.mdc` for implementation-derived instructions and how to add more GraphQL queries.

## Quick Start

### 1. Initialize Terraform

From the repo root, initialize the environment you want to use (e.g. dev):

```bash
cd environments/dev
terraform init
```

### 2. Plan Changes

Provide credentials via environment variables (or tfvars), then plan:

```bash
export TF_VAR_dd_api_key="your-api-key"
export TF_VAR_dd_app_key="your-app-key"
# Optional: export TF_VAR_dd_api_url="https://api.datadoghq.eu"

terraform plan
```

Review the plan to see which synthetic tests will be created or updated.

### 3. Apply Changes

When the plan looks correct:

```bash
terraform apply
```

Confirm with `yes` (or use `-auto-approve` in automation only).

### 4. Using a tfvars File (Optional)

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

- **Credentials in CI**: Store `DD_API_KEY` and `DD_APP_KEY` (or `TF_VAR_dd_api_key` / `TF_VAR_dd_app_key`) as secrets in your CI system. Set `TF_VAR_dd_api_url` if you use a non-US1 site.

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
