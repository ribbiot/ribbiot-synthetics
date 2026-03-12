# ------------------------------------------------------------------------------
# GraphQL User Service tests (dev): Auth0 → GraphQL.
# ------------------------------------------------------------------------------

locals {
  graphql_endpoint_user = "https://ribbiot-router-dev.up.railway.app/graphql"
  graphql_body_user_system_check = "{\"query\":\"query UserSystemCheck($input: SystemCheckInput) {\\n  userSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n    minimumAndroidVersion\\n    minimumIOSVersion\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"
}

resource "datadog_synthetics_test" "auth0_graphql_user_system_check_dev" {
  name      = "GraphQL: userSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:user-management-service"])
  message   = "Auth0 or GraphQL userSystemCheck step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL userSystemCheck"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_user
      body      = local.graphql_body_user_system_check
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

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.userSystemCheck.message"
        operator    = "is"
        targetvalue = "User Service is Running!"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.userSystemCheck.launchDarklyStatus"
        operator    = "is"
        targetvalue = "OK"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.userSystemCheck.sqlStatus"
        operator    = "is"
        targetvalue = "OK"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.userSystemCheck.minimumAndroidVersion"
        operator    = "is"
        targetvalue = "0.0.2"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.userSystemCheck.minimumIOSVersion"
        operator    = "is"
        targetvalue = "1.1.18"
      }
    }
  }

  options_list {
    tick_every = 300
    retry {
      count    = 2
      interval = 300
    }
  }
}
