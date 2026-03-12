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


