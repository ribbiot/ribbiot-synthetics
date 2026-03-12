# ------------------------------------------------------------------------------
# Datadog Synthetic API test resource.
# See: https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/synthetics_test
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }
}

resource "datadog_synthetics_test" "api" {
  name      = var.name
  type      = "api"
  subtype   = "http"
  status    = var.status
  message   = var.message != "" ? var.message : "Synthetic API test ${var.name} failed."
  locations = var.locations
  tags      = var.tags

  request_definition {
    method = var.request_method
    url    = var.request_url
  }

  # Request headers as key-value map (optional).
  request_headers = var.request_headers

  dynamic "assertion" {
    for_each = var.assertions
    content {
      type     = assertion.value.type
      operator = assertion.value.operator
      # Omit target for validatesJSONPath; provider uses targetjsonpath instead.
      target   = try(assertion.value.targetjsonpath, null) != null ? null : try(assertion.value.target, null)
      property = try(assertion.value.property, null)

      dynamic "targetjsonpath" {
        for_each = try(assertion.value.targetjsonpath, null) != null ? [assertion.value.targetjsonpath] : []
        content {
          jsonpath    = targetjsonpath.value.jsonpath
          operator    = targetjsonpath.value.operator
          targetvalue = try(targetjsonpath.value.targetvalue, null)
        }
      }
    }
  }

  options_list {
    tick_every       = var.frequency
    follow_redirects = var.follow_redirects

    retry {
      count    = var.retry_count
      interval = var.retry_interval_ms # whole number; provider expects milliseconds
    }
  }
}
