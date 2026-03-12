# ------------------------------------------------------------------------------
# Prod environment: Datadog provider and synthetic API tests.
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
  api_key = var.dd_api_key
  app_key = var.dd_app_key
  api_url = var.dd_api_url
}

locals {
  env_name  = "prod"
  base_tags = ["env:${local.env_name}", "managed_by:terraform", "project:railway"]
  locations = var.default_locations
  frequency = var.default_frequency

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
    @slack-synthetic-alerts
    {{! Test result details }}
    Your test {{#is_alert}}failed{{else}}recovered{{/is_alert}} after running for {{eval "synthetics.attributes.result.duration/1000" }}s on the {{#if synthetics.attributes.location.privateLocation}}Private{{else}}Managed{{/if}} Location {{synthetics.attributes.location.id}}.
    {{! If alert, provide details about the failure }}
    {{#is_alert}}{{#is_exact_match "synthetics.attributes.result.failure.code" "INCORRECT_ASSERTION"}}
    Failed assertion(s): check Synthetics test results for details.
    {{/is_exact_match}}{{/is_alert}}
  EOT
}

# ------------------------------------------------------------------------------
# Railway router health check (prod)
# ------------------------------------------------------------------------------

module "railway_health_check" {
  source = "../../modules/synthetic-api-test"

  name      = "railway health check"
  status    = "live"
  message   = local.railway_alert_message
  locations = local.railway_test_locations
  frequency = 60 # 1 minute
  tags      = concat(local.base_tags, ["railway", "env:prod"])

  request_url    = "https://ribbiot-router-prod.up.railway.app/health"
  request_method = "GET"
  request_headers = {}

  assertions = [
    { type = "responseTime", operator = "lessThan", target = "2000" },
    { type = "statusCode", operator = "is", target = "200" }
  ]

  retry_count      = 2
  retry_interval_ms = 300
}
