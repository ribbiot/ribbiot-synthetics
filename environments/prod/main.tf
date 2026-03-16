# ------------------------------------------------------------------------------
# Prod environment: Datadog provider and synthetic API tests.
# Credentials via env: TF_VAR_dd_api_key, TF_VAR_dd_app_key. Optional: DD_API_URL (Datadog site).
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
  api_url = try(env("DD_API_URL"), "") != "" ? env("DD_API_URL") : var.dd_api_url
}

# ------------------------------------------------------------------------------
# Shared defaults for all tests in this environment
# ------------------------------------------------------------------------------

locals {
  env_name  = "prod"
  base_tags = ["env:${local.env_name}", "managed_by:terraform", "project:railway"]
  locations = var.default_locations
  frequency = var.default_frequency
}
