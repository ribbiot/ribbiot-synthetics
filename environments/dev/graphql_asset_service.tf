# ------------------------------------------------------------------------------
# GraphQL Asset Service tests (dev): Auth0 → GraphQL.
# Note: "assertion.target is not valid for validatesJSONPath" warning is a known
# provider bug (terraform-provider-datadog#3362); safe to ignore.
#
# Implemented query synthetics:
#   assetSystemCheck, getAssetImportUploadPresignedUrl (needs DEV_ASSET_ACCOUNT_ID),
#   listMeasureUnits, assetTemplates, baseAssetTemplates, assets.
# Queries not yet implemented (need IDs or date/input): assetTemplate(id), baseAssetTemplate(id),
#   asset(id), getAvailableAssetSchedule, getAvailableAssetScheduleForTask,
#   scheduledAssetsForJobs, scheduledAssetsForTasks. See docs/required-synthetic-data.md.
# ------------------------------------------------------------------------------

# Synthetic data globals (e.g. DEV_ASSET_ACCOUNT_ID) come from var.synthetic_data_values in graphql.tf.

locals {
  graphql_endpoint = "https://ribbiot-router-dev.up.railway.app/graphql"

  # 1. assetSystemCheck(input: SystemCheckInput): GqlAssetSystemCheck!
  graphql_body_asset_system_check = "{\"query\":\"query AssetSystemCheck($input: SystemCheckInput) {\\n  assetSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"

  # validatesJSONPath assertions without assertion.target (provider warns if target is set)
  asset_system_check_jsonpath_assertions = [
    { jsonpath = "$.data.assetSystemCheck.message", operator = "is", targetvalue = "Asset Service is Running!" },
    { jsonpath = "$.data.assetSystemCheck.launchDarklyStatus", operator = "is", targetvalue = "OK" },
    { jsonpath = "$.data.assetSystemCheck.sqlStatus", operator = "is", targetvalue = "OK" },
  ]

  # 2. getAssetImportUploadPresignedUrl(accountId: ID!): String!
  # Uses DEV_ASSET_ACCOUNT_ID (from synthetic_data_values, see synthetic-data/asset-service.yaml).
  graphql_body_get_asset_import_upload_presigned_url = "{\"query\":\"query GetAssetImportUploadPresignedUrl($accountId: ID!) {\\n  getAssetImportUploadPresignedUrl(accountId: $accountId)\\n}\",\"variables\":{\"accountId\":\"{{DEV_ASSET_ACCOUNT_ID}}\"}}"

  # 3. listMeasureUnits: [GqlMeasureUnit!]!
  graphql_body_list_measure_units = "{\"query\":\"query ListMeasureUnits {\\n  listMeasureUnits {\\n    name\\n    symbol\\n    type\\n    measureGroup\\n  }\\n}\"}"

  # 4. assetTemplates: [GqlAssetTemplate!]!
  graphql_body_asset_templates = "{\"query\":\"query AssetTemplates {\\n  assetTemplates {\\n    id\\n    name\\n    accountId\\n    parentId\\n    createdAt\\n    updatedAt\\n  }\\n}\"}"

  # 5. baseAssetTemplates: [GqlBaseAssetTemplate!]!
  graphql_body_base_asset_templates = "{\"query\":\"query BaseAssetTemplates {\\n  baseAssetTemplates {\\n    id\\n    name\\n  }\\n}\"}"

  # 6. assets: [GqlAsset!]!
  graphql_body_assets = "{\"query\":\"query Assets {\\n  assets {\\n    id\\n    name\\n    accountId\\n    active\\n    source\\n    createdAt\\n    updatedAt\\n  }\\n}\"}"
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

  dynamic "config_variable" {
    for_each = local.graphql_config_variables
    content {
      name = config_variable.value.name
      id   = config_variable.value.id
      type = config_variable.value.type
    }
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

    dynamic "assertion" {
      for_each = local.asset_system_check_jsonpath_assertions
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
    tick_every = 300
    retry {
      count    = 2
      interval = 300
    }
  }
}

# ------------------------------------------------------------------------------
# GraphQL: getAssetImportUploadPresignedUrl (dev) — not enabled in any geos yet
# Add locations when test is tuned; DEV_ASSET_ACCOUNT_ID comes from synthetic_data_values.
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_get_asset_import_upload_presigned_url_dev" {
  name      = "GraphQL: getAssetImportUploadPresignedUrl"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = ["aws:ca-central-1"] # Canada only until accountId is set and test is tuned
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL getAssetImportUploadPresignedUrl step failed in dev."

  dynamic "config_variable" {
    for_each = local.graphql_config_variables
    content {
      name = config_variable.value.name
      id   = config_variable.value.id
      type = config_variable.value.type
    }
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

  dynamic "config_variable" {
    for_each = local.graphql_config_variables
    content {
      name = config_variable.value.name
      id   = config_variable.value.id
      type = config_variable.value.type
    }
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

# ------------------------------------------------------------------------------
# GraphQL: assetTemplates (dev) — list all asset templates
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_asset_templates_dev" {
  name      = "GraphQL: assetTemplates"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = ["aws:ca-central-1"]
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL assetTemplates step failed in dev."

  dynamic "config_variable" {
    for_each = local.graphql_config_variables
    content {
      name = config_variable.value.name
      id   = config_variable.value.id
      type = config_variable.value.type
    }
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
    name    = "GraphQL assetTemplates"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_asset_templates
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
# GraphQL: baseAssetTemplates (dev) — list all base asset templates
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_base_asset_templates_dev" {
  name      = "GraphQL: baseAssetTemplates"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = ["aws:ca-central-1"]
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL baseAssetTemplates step failed in dev."

  dynamic "config_variable" {
    for_each = local.graphql_config_variables
    content {
      name = config_variable.value.name
      id   = config_variable.value.id
      type = config_variable.value.type
    }
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
    name    = "GraphQL baseAssetTemplates"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_base_asset_templates
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
# GraphQL: assets (dev) — list all assets
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_assets_dev" {
  name      = "GraphQL: assets"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = ["aws:ca-central-1"]
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL assets step failed in dev."

  dynamic "config_variable" {
    for_each = local.graphql_config_variables
    content {
      name = config_variable.value.name
      id   = config_variable.value.id
      type = config_variable.value.type
    }
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
    name    = "GraphQL assets"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_assets
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
  }

  options_list {
    tick_every = 300
    retry {
      count    = 2
      interval = 300
    }
  }
}
