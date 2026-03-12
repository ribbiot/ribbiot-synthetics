# ------------------------------------------------------------------------------
# Reusable module: Datadog Synthetic API test
# All inputs for defining a single API synthetic test.
# ------------------------------------------------------------------------------

variable "name" {
  description = "Display name of the synthetic test."
  type        = string
}

variable "request_url" {
  description = "URL to send the API request to."
  type        = string
}

variable "request_method" {
  description = "HTTP method (GET, POST, PUT, PATCH, DELETE, etc.)."
  type        = string
  default     = "GET"
}

variable "request_headers" {
  description = "Map of HTTP header names to values."
  type        = map(string)
  default     = {}
}

variable "assertions" {
  description = "List of assertion objects: type, operator, optional target, optional property (e.g. header name), optional targetjsonpath for body."
  type = list(object({
    type     = string
    operator = string
    target   = optional(string)
    # Optional: e.g. header name for type=header, or timingsScope for responseTime
    property = optional(string)
    # Optional: for type=body, operator=validatesJSONPath
    targetjsonpath = optional(object({
      jsonpath    = string
      operator    = string
      targetvalue = optional(string)
    }))
  }))
  default = []
}

variable "locations" {
  description = "List of Datadog synthetic locations (e.g. aws:us-east-1, aws:eu-west-1)."
  type        = list(string)
}

variable "frequency" {
  description = "How often the test runs in seconds (e.g. 300 = every 5 min, 900 = every 15 min)."
  type        = number
  default     = 300
}

variable "tags" {
  description = "List of tags to attach to the test."
  type        = list(string)
  default     = []
}

variable "status" {
  description = "Test status: live or paused."
  type        = string
  default     = "live"
}

variable "message" {
  description = "Custom message to include in alerts when the test fails."
  type        = string
  default     = ""
}

variable "retry_count" {
  description = "Number of retries before the test is marked as failed."
  type        = number
  default     = 1
}

variable "retry_interval_ms" {
  description = "Wait time in milliseconds between retries."
  type        = number
  default     = 300
}

variable "follow_redirects" {
  description = "Whether to follow HTTP redirects."
  type        = bool
  default     = true
}
