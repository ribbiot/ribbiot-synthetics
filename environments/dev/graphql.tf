# ------------------------------------------------------------------------------
# GraphQL multi-step tests: Auth0 token → GraphQL (dev).
# Requires: TF_VAR_dev_username, TF_VAR_dev_password, TF_VAR_dev_client_secret
# (or set in .env and source before terraform apply).
# ------------------------------------------------------------------------------

# Global variables stored in Datadog; secrets passed via Terraform vars (never commit).
resource "datadog_synthetics_global_variable" "dev_auth0_domain" {
  name  = "DEV_AUTH0_DOMAIN"
  value = var.dev_auth0_domain
}

resource "datadog_synthetics_global_variable" "dev_username" {
  name  = "DEV_USERNAME"
  value = var.dev_username
}

resource "datadog_synthetics_global_variable" "dev_password" {
  name   = "DEV_PASSWORD"
  secure = true
  value  = var.dev_password
}

resource "datadog_synthetics_global_variable" "dev_client_secret" {
  name   = "DEV_CLIENT_SECRET"
  secure = true
  value  = var.dev_client_secret
}

# Auth0 token request body (form-urlencoded). Audience must be valid for password grant.
# Scopes: general:tracker, mobileassets:user, mobilehome:user, mobile:provisioning, mobile:user,
#         mobile:vtrackers, ribbiot:admin, timecard:admin, timecard:user, web:assetcrud, web:assetmap,
#         web:invoice, web:quoting, web:schedule, web:settings, web:usercrud
locals {
  auth0_body = "username={{DEV_USERNAME}}&password={{DEV_PASSWORD}}&client_id=1jA5AOlVzwDksR9YXX7u71tVVWa2tDFo&client_secret={{DEV_CLIENT_SECRET}}&grant_type=password&audience=https%3A%2F%2Fv656y9o6s7.execute-api.us-east-1.amazonaws.com%2Fdev&redirect_uri=https%3A%2F%2Fgoogle.com&scope=general%3Atracker%20mobileassets%3Auser%20mobilehome%3Auser%20mobile%3Aprovisioning%20mobile%3Auser%20mobile%3Avtrackers%20ribbiot%3Aadmin%20timecard%3Aadmin%20timecard%3Auser%20web%3Aassetcrud%20web%3Aassetmap%20web%3Ainvoice%20web%3Aquoting%20web%3Aschedule%20web%3Asettings%20web%3Ausercrud"
  # Shared variables: checkLaunchDarkly and checkSQL true so we assert launchDarklyStatus/sqlStatus "OK"
  # assetSystemCheck
  graphql_body = "{\"query\":\"query AssetSystemCheck($input: SystemCheckInput) {\\n  assetSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"
  # userSystemCheck
  graphql_body_user_system_check = "{\"query\":\"query UserSystemCheck($input: SystemCheckInput) {\\n  userSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n    minimumAndroidVersion\\n    minimumIOSVersion\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"
  # jobSystemCheck
  graphql_body_job_system_check = "{\"query\":\"query JobSystemCheck($input: SystemCheckInput) {\\n  jobSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"
  # timecardSystemCheck
  graphql_body_timecard_system_check = "{\"query\":\"query TimecardSystemCheck($input: SystemCheckInput) {\\n  timecardSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"
}

resource "datadog_synthetics_test" "auth0_graphql_dev" {
  name      = "GraphQL: assetSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql"])
  message   = "Auth0 or GraphQL assetSystemCheck step failed in dev. Check token or GraphQL endpoint."

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

  # Step 1: Get bearer token from Auth0
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

  # Step 2: GraphQL assetSystemCheck; assert 200 and response body message
  api_step {
    name    = "GraphQL assetSystemCheck"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = "https://ribbiot-router-dev.up.railway.app/graphql"
      body      = local.graphql_body
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
      target   = null # omit for validatesJSONPath; use targetjsonpath only
      targetjsonpath {
        jsonpath    = "$.data.assetSystemCheck.message"
        operator    = "is"
        targetvalue = "Asset Service is Running!"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.assetSystemCheck.launchDarklyStatus"
        operator    = "is"
        targetvalue = "OK"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.assetSystemCheck.sqlStatus"
        operator    = "is"
        targetvalue = "OK"
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

# ------------------------------------------------------------------------------
# GraphQL: userSystemCheck (dev)
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_user_system_check_dev" {
  name      = "GraphQL: userSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql"])
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
      url       = "https://ribbiot-router-dev.up.railway.app/graphql"
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

# ------------------------------------------------------------------------------
# GraphQL: jobSystemCheck (dev)
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_job_system_check_dev" {
  name      = "GraphQL: jobSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql"])
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
      url       = "https://ribbiot-router-dev.up.railway.app/graphql"
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

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.jobSystemCheck.message"
        operator    = "is"
        targetvalue = "Job Service is Running!"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.jobSystemCheck.launchDarklyStatus"
        operator    = "is"
        targetvalue = "OK"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.jobSystemCheck.sqlStatus"
        operator    = "is"
        targetvalue = "OK"
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

# ------------------------------------------------------------------------------
# GraphQL: timecardSystemCheck (dev)
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_timecard_system_check_dev" {
  name      = "GraphQL: timecardSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql"])
  message   = "Auth0 or GraphQL timecardSystemCheck step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL timecardSystemCheck"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = "https://ribbiot-router-dev.up.railway.app/graphql"
      body      = local.graphql_body_timecard_system_check
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
        jsonpath    = "$.data.timecardSystemCheck.message"
        operator    = "is"
        targetvalue = "Timecard system is up and running!"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.timecardSystemCheck.launchDarklyStatus"
        operator    = "is"
        targetvalue = "OK"
      }
    }

    assertion {
      type     = "body"
      operator = "validatesJSONPath"
      target   = null
      targetjsonpath {
        jsonpath    = "$.data.timecardSystemCheck.sqlStatus"
        operator    = "is"
        targetvalue = "OK"
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
