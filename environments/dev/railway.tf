# ------------------------------------------------------------------------------
# Railway router health checks (single-step API tests).
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
  frequency = var.default_frequency
  tags      = local.base_tags

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
