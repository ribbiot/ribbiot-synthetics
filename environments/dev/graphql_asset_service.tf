# ------------------------------------------------------------------------------
# GraphQL Asset Service tests (dev): Auth0 → GraphQL.
# First 3 queries: assetSystemCheck, getAssetImportUploadPresignedUrl, listMeasureUnits.
# New queries (getAssetImportUploadPresignedUrl, listMeasureUnits) are not enabled in any
# geos initially; set locations and dev_asset_account_id when tuning is done.
# ------------------------------------------------------------------------------

# Optional: used by getAssetImportUploadPresignedUrl (and other account-scoped Asset queries).
resource "datadog_synthetics_global_variable" "dev_asset_account_id" {
  name  = "DEV_ASSET_ACCOUNT_ID"
  value = var.dev_asset_account_id
}

locals {
  graphql_endpoint = "https://ribbiot-router-dev.up.railway.app/graphql"

  # 1. assetSystemCheck(input: SystemCheckInput): GqlAssetSystemCheck!
  graphql_body_asset_system_check = "{\"query\":\"query AssetSystemCheck($input: SystemCheckInput) {\\n  assetSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"

  # 2. getAssetImportUploadPresignedUrl(accountId: ID!): String!
  # Uses DEV_ASSET_ACCOUNT_ID; set dev_asset_account_id when enabling this test.
  graphql_body_get_asset_import_upload_presigned_url = "{\"query\":\"query GetAssetImportUploadPresignedUrl($accountId: ID!) {\\n  getAssetImportUploadPresignedUrl(accountId: $accountId)\\n}\",\"variables\":{\"accountId\":\"{{DEV_ASSET_ACCOUNT_ID}}\"}}"

  # 3. listMeasureUnits: [GqlMeasureUnit!]!
  graphql_body_list_measure_units = "{\"query\":\"query ListMeasureUnits {\\n  listMeasureUnits {\\n    name\\n    symbol\\n    type\\n    measureGroup\\n  }\\n}\"}"
}

# ------------------------------------------------------------------------------
# GraphQL: assetSystemCheck (dev) — enabled in railway_test_locations
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_asset_system_check_dev" {
  name      = "GraphQL: assetSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
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
    name    = "GraphQL assetSystemCheck"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_asset_system_check
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
# GraphQL: getAssetImportUploadPresignedUrl (dev) — not enabled in any geos yet
# Set dev_asset_account_id and add locations when input data is tuned.
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_get_asset_import_upload_presigned_url_dev" {
  name      = "GraphQL: getAssetImportUploadPresignedUrl"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = ["aws:ca-central-1"] # Canada only until accountId is set and test is tuned
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL getAssetImportUploadPresignedUrl step failed in dev."

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
  config_variable {
    name = "DEV_ASSET_ACCOUNT_ID"
    id   = datadog_synthetics_global_variable.dev_asset_account_id.id
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
    name    = "GraphQL getAssetImportUploadPresignedUrl"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_get_asset_import_upload_presigned_url
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
    # Add body assertion (e.g. presigned URL contains "http") when tuning
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
# GraphQL: listMeasureUnits (dev) — not enabled in any geos yet
# Enable by setting locations when ready.
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_list_measure_units_dev" {
  name      = "GraphQL: listMeasureUnits"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = ["aws:ca-central-1"] # Canada only until test is tuned
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL listMeasureUnits step failed in dev."

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
    name    = "GraphQL listMeasureUnits"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_list_measure_units
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
    # Add body assertions (e.g. $.data.listMeasureUnits[0].name) when tuning
  }

  options_list {
    tick_every = 300
    retry {
      count    = 2
      interval = 300
    }
  }
}
