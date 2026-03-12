# ------------------------------------------------------------------------------
# Prod environment variables.
# ------------------------------------------------------------------------------

variable "dd_api_key" {
  description = "Datadog API key. Set via TF_VAR_dd_api_key, DD_API_KEY (e.g. in .env), or enter when prompted."
  type        = string
  sensitive   = true
}

variable "dd_app_key" {
  description = "Datadog application key. Set via TF_VAR_dd_app_key, DD_APP_KEY (e.g. in .env), or enter when prompted."
  type        = string
  sensitive   = true
}

variable "dd_api_url" {
  description = "Datadog API URL (US5: api.us5.datadoghq.com, US1: api.datadoghq.com, EU: api.datadoghq.eu)."
  type        = string
  default     = "https://api.us5.datadoghq.com"
}

variable "default_locations" {
  description = "Default synthetic test locations for prod (consider multiple regions)."
  type        = list(string)
  default     = ["aws:us-east-1", "aws:us-west-2", "aws:eu-west-1"]
}

variable "default_frequency" {
  description = "Default test run frequency in seconds (for future tests using local.frequency)."
  type        = number
  default     = 900
}
