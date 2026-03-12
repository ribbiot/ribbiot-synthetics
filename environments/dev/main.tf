# ------------------------------------------------------------------------------
# Dev environment: Datadog provider and synthetic API tests.
# Credentials via env: DD_API_KEY, DD_APP_KEY. Optional: DD_API_URL (Datadog site).
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }

  # Uncomment and configure for remote state when using CI/CD.
  # backend "s3" {}
}

provider "datadog" {
  # Prefer TF_VAR_*; if empty, use DD_API_KEY / DD_APP_KEY (so .env with DD_* works after sourcing).
  api_key = var.dd_api_key != "" ? var.dd_api_key : try(env("DD_API_KEY"), "")
  app_key = var.dd_app_key != "" ? var.dd_app_key : try(env("DD_APP_KEY"), "")
  # DD_API_URL overrides var (e.g. set to https://api.datadoghq.eu for EU orgs; 403 often = wrong site).
  api_url = try(env("DD_API_URL"), "") != "" ? env("DD_API_URL") : var.dd_api_url
}

# ------------------------------------------------------------------------------
# Shared defaults for all tests in this environment
# ------------------------------------------------------------------------------

locals {
  env_name   = "dev"
  base_tags  = ["env:${local.env_name}", "managed_by:terraform", "project:railway"]
  locations  = var.default_locations
  frequency  = var.default_frequency
}

# ------------------------------------------------------------------------------
# Synthetic API tests (add new tests here or in tests.tf)
# ------------------------------------------------------------------------------

module "example_health_check" {
  source = "../../modules/synthetic-api-test"

  name      = "Example API health check (${local.env_name})"
  status    = var.example_test_status
  message   = "Example health check failed in ${local.env_name}. Check service availability."
  locations = local.locations
  frequency = local.frequency
  tags      = concat(local.base_tags, ["test:example-health"])

  request_url    = var.example_health_url
  request_method = "GET"
  request_headers = {
    "Accept" = "application/json"
  }
  assertions = [
    { type = "statusCode", operator = "is", target = "200" },
    { type = "responseTime", operator = "lessThan", target = "5000" }
  ]
}

# ------------------------------------------------------------------------------
# Railway router health check (matches Datadog UI config)
# ------------------------------------------------------------------------------

locals {
  # 11 Americas managed locations (must match Datadog API allowed list)
  railway_test_locations = [
    "aws:ca-central-1",
    "gcp:us-south1",
    "gcp:us-west2",
    "aws:us-west-1",
    "aws:us-east-1",
    "aws:us-east-2",
    "aws:us-west-2",
    "gcp:us-west1",
    "aws:sa-east-1",
    "azure:eastus",
    "gcp:us-east4"
  ]

  railway_alert_message = <<-EOT
    @slack-Ribbiot-synthetic-alerts
    {{#is_alert}}
    Railway health check failed in {{synthetics.attributes.location.privateLocation}} location {{synthetics.attributes.location.id}}.
    Duration: {{eval "synthetics.attributes.result.duration/1000" }}s
    {{#if synthetics.attributes.result.failure.code}}
    Failure: {{synthetics.attributes.result.failure.code}}
    {{/if}}
    {{#each synthetics.attributes.result.assertions}}{{#unless valid}}
    Failed assertion: {{this}}
    {{/unless}}{{/each}}
    {{/is_alert}}
    {{^is_alert}}
    Railway health check recovered in {{synthetics.attributes.location.id}}.
    {{/is_alert}}
  EOT
}

module "railway_health_check" {
  source = "../../modules/synthetic-api-test"

  name      = "railway health check"
  status    = "live"
  message   = local.railway_alert_message
  locations = local.railway_test_locations
  frequency = 60 # 1 minute
  tags      = concat(local.base_tags, ["railway", "env:dev"])

  request_url    = "https://ribbiot-router-dev.up.railway.app/health"
  request_method = "GET"
  request_headers = {}

  assertions = [
    { type = "responseTime", operator = "lessThan", target = "2000" },
    { type = "statusCode", operator = "is", target = "200" },
    { type = "header", operator = "is", target = "text/plain; charset=utf-8", property = "content-type" },
    {
      type     = "body"
      operator = "validatesJSONPath"
      targetjsonpath = {
        jsonpath    = "$.status"
        operator    = "is"
        targetvalue = "UP"
      }
    }
  ]

  retry_count      = 2
  retry_interval_ms = 300
}
