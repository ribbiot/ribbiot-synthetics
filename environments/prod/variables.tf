# ------------------------------------------------------------------------------
# Prod environment variables.
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
  description = "Datadog API URL (US5: api.us5.datadoghq.com, US1: api.datadoghq.com, EU: api.datadoghq.eu)."
  type        = string
  default     = "https://api.us5.datadoghq.com"
}

# Default run policy: 3 geos, every 2 hours (same as dev) to prevent runaway spend.
variable "default_locations" {
  description = "Default synthetic test locations. Framework default: 3 geos (us-east-1, us-west-2, gcp us-west1)."
  type        = list(string)
  default     = ["aws:us-east-1", "aws:us-west-2", "gcp:us-west1"]
}

variable "default_frequency" {
  description = "Default test run frequency in seconds. Framework default: 7200 (2 hours)."
  type        = number
  default     = 7200
}
