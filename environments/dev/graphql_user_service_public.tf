# ------------------------------------------------------------------------------
# GraphQL User Service (Public) tests (dev): single-step, no Auth0.
# Public endpoints do not require authentication.
# Note: "assertion.target is not valid for validatesJSONPath" warning is a known
# provider bug (terraform-provider-datadog#3362); safe to ignore.
# ------------------------------------------------------------------------------

locals {
  graphql_endpoint_user_public = "https://ribbiot-router-dev.up.railway.app/graphql"
  graphql_body_public_user_settings = "{\"query\":\"query PublicUserServiceSettings {\\n  publicUserServiceSettings {\\n    minimumAndroidVersion\\n    minimumIOSVersion\\n  }\\n}\"}"

  public_user_settings_jsonpath_assertions = [
    { jsonpath = "$.data.publicUserServiceSettings.minimumAndroidVersion", operator = "is", targetvalue = "0.0.2" },
    { jsonpath = "$.data.publicUserServiceSettings.minimumIOSVersion", operator = "is", targetvalue = "1.1.18" },
  ]
}

resource "datadog_synthetics_test" "graphql_public_user_service_settings_dev" {
  name      = "GraphQL (public): publicUserServiceSettings"
  type      = "api"
  subtype   = "http"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:user-management-service", "visibility:public"])
  message   = "GraphQL public user service publicUserServiceSettings failed in dev. Check router/User Service public schema."

  request_definition {
    method    = "POST"
    url       = local.graphql_endpoint_user_public
    body      = local.graphql_body_public_user_settings
    body_type = "application/json"
  }

  request_headers = {
    "Content-Type" = "application/json"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  dynamic "assertion" {
    for_each = local.public_user_settings_jsonpath_assertions
    content {
      type     = "body"
      operator = "validatesJSONPath"
      targetjsonpath {
        jsonpath    = assertion.value.jsonpath
        operator    = assertion.value.operator
        targetvalue = assertion.value.targetvalue
      }
    }
  }

  options_list {
    tick_every = var.default_frequency
    retry {
      count    = 2
      interval = 300
    }
  }
}
