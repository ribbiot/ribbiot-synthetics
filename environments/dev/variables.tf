# ------------------------------------------------------------------------------
# Dev environment variables.
# Sensitive values (api_key, app_key) should be set via env vars or a non-committed tfvars file.
# ------------------------------------------------------------------------------

variable "dd_api_key" {
  description = "Datadog API key. Set via TF_VAR_dd_api_key, DD_API_KEY, or enter when prompted."
  type        = string
  sensitive   = true
}

variable "dd_app_key" {
  description = "Datadog application key. Set via TF_VAR_dd_app_key, DD_APP_KEY, or enter when prompted."
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

# Example test configuration
variable "example_health_url" {
  description = "URL for the example health check synthetic test."
  type        = string
  default     = "https://httpbin.org/get"
}

variable "example_test_status" {
  description = "Status of the example test: live or paused."
  type        = string
  default     = "live"
}
