# ------------------------------------------------------------------------------
# GraphQL Job Service tests (dev): Auth0 → GraphQL.
# Note: "assertion.target is not valid for validatesJSONPath" warning is a known
# provider bug (terraform-provider-datadog#3362); safe to ignore.
# ------------------------------------------------------------------------------

locals {
  graphql_endpoint_job          = "https://ribbiot-router-dev.up.railway.app/graphql"
  graphql_body_job_system_check = "{\"query\":\"query JobSystemCheck($input: SystemCheckInput) {\\n  jobSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"

  # validatesJSONPath assertions without assertion.target (provider warns if target is set)
  job_system_check_jsonpath_assertions = [
    { jsonpath = "$.data.jobSystemCheck.message", operator = "is", targetvalue = "Job Service is Running!" },
    { jsonpath = "$.data.jobSystemCheck.launchDarklyStatus", operator = "is", targetvalue = "OK" },
    { jsonpath = "$.data.jobSystemCheck.sqlStatus", operator = "is", targetvalue = "OK" },
  ]
}

resource "datadog_synthetics_test" "auth0_graphql_job_system_check_dev" {
  name      = "GraphQL: jobSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL jobSystemCheck step failed in dev. Check token or GraphQL endpoint."

  config_variable {
    name = "DEV_AUTH0_DOMAIN"
    id   = datadog_synthetics_global_variable.dev_auth0_domain.id
    type = "global"
  }
  config_variable {
    name = "DEV_USERNAME"
    id   = datadog_synthetics_global_variable.dev_username.id
    type = "global"
  }
  config_variable {
    name = "DEV_PASSWORD"
    id   = datadog_synthetics_global_variable.dev_password.id
    type = "global"
  }
  config_variable {
    name = "DEV_CLIENT_SECRET"
    id   = datadog_synthetics_global_variable.dev_client_secret.id
    type = "global"
  }

  api_step {
    name    = "Request token from Dev Auth0"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = "https://{{ DEV_AUTH0_DOMAIN }}/oauth/token"
      body      = local.auth0_body
      body_type = "application/x-www-form-urlencoded"
    }

    request_headers = {
      "Content-Type" = "application/x-www-form-urlencoded"
    }

    extracted_value {
      name = "BEARER_TOKEN"
      type = "http_body"
      parser {
        type  = "json_path"
        value = "$.access_token"
      }
    }

    assertion {
      type     = "statusCode"
      operator = "is"
      target   = "200"
    }
  }

  api_step {
    name    = "GraphQL jobSystemCheck"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_job_system_check
      body_type = "application/json"
    }

    request_headers = {
      "Content-Type"  = "application/json"
      "Authorization" = "Bearer {{BEARER_TOKEN}}"
    }

    assertion {
      type     = "statusCode"
      operator = "is"
      target   = "200"
    }

    dynamic "assertion" {
      for_each = local.job_system_check_jsonpath_assertions
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
  }

  options_list {
    tick_every = var.default_frequency
    retry {
      count    = 2
      interval = 300
    }
  }
}
