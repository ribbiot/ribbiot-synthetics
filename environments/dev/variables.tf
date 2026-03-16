# ------------------------------------------------------------------------------
# Dev environment variables.
# Sensitive values (api_key, app_key) should be set via env vars or a non-committed tfvars file.
# ------------------------------------------------------------------------------

variable "dd_api_key" {
  description = "Datadog API key. Set via TF_VAR_dd_api_key (e.g. in .env) or enter when prompted."
  type        = string
  sensitive   = true
}

variable "dd_app_key" {
  description = "Datadog application key. Set via TF_VAR_dd_app_key (e.g. in .env) or enter when prompted."
  type        = string
  sensitive   = true
}

variable "dd_api_url" {
  description = "Datadog API URL (US1: api.datadoghq.com, US5: api.us5.datadoghq.com, EU: api.datadoghq.eu)."
  type        = string
  default     = "https://api.us5.datadoghq.com"
}

variable "default_locations" {
  description = "Default list of synthetic test locations (e.g. aws:us-east-1)."
  type        = list(string)
  default     = ["aws:us-east-1"]
}

variable "default_frequency" {
  description = "Default test run frequency in seconds."
  type        = number
  default     = 300
}

# ------------------------------------------------------------------------------
# Auth0 + GraphQL multi-step test (dev). Set via TF_VAR_* or .env; never commit.
# ------------------------------------------------------------------------------

variable "dev_auth0_domain" {
  description = "Auth0 dev domain (e.g. devauth.ribbiot.com). Used in multi-step test."
  type        = string
  default     = "devauth.ribbiot.com"
}

variable "dev_username" {
  description = "Auth0 dev username (email). Set via TF_VAR_dev_username."
  type        = string
  sensitive   = true
}

variable "dev_password" {
  description = "Auth0 dev password. Set via TF_VAR_dev_password; never commit."
  type        = string
  sensitive   = true
}

variable "dev_client_secret" {
  description = "Auth0 dev client secret. Set via TF_VAR_dev_client_secret; never commit."
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Synthetic data: values from synthetic-data/*.yaml, injected by script.
# Run: npm run tfvars:from-synthetic-data (writes synthetic-data.auto.tfvars.json).
# No need to set these by hand unless you override.
# ------------------------------------------------------------------------------
variable "synthetic_data_values" {
  description = "Map of global variable name -> string value (e.g. DEV_ASSET_ACCOUNT_ID, DEV_SCHEDULED_ASSETS_TASK_IDS). Populated from synthetic-data/*.yaml via scripts/synthetic-data-to-tfvars.ts. Arrays in YAML are JSON-encoded as strings."
  type        = map(string)
  default     = {}
}
