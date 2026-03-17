# ------------------------------------------------------------------------------
# GraphQL Asset Service tests (dev): Auth0 → GraphQL.
# Note: "assertion.target is not valid for validatesJSONPath" warning is a known
# provider bug (terraform-provider-datadog#3362); safe to ignore.
#
# Tests here must match synthetic-test-config: only queries without excluded: true get a resource.
# Implemented (not excluded): assetSystemCheck, getAssetImportUploadPresignedUrl, listMeasureUnits,
#   scheduledAssetsForTasks, getAvailableAssetScheduleForTask. Excluded in config: assetTemplates, baseAssetTemplates,
#   assets, assetTemplate, baseAssetTemplate, asset, getAvailableAssetSchedule, scheduledAssetsForJobs.
# ------------------------------------------------------------------------------

# Synthetic data globals (e.g. DEV_ASSET_ACCOUNT_ID) come from var.synthetic_data_values in graphql.tf.
# Asset tests use framework default: var.default_locations (3 geos), var.default_frequency (2 hours).
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
  # Uses DEV_ASSET_ACCOUNT_ID (from synthetic_data_values, see synthetic-test-config/graphql/dev/asset-service.yaml).
  graphql_body_get_asset_import_upload_presigned_url = "{\"query\":\"query GetAssetImportUploadPresignedUrl($accountId: ID!) {\\n  getAssetImportUploadPresignedUrl(accountId: $accountId)\\n}\",\"variables\":{\"accountId\":\"{{DEV_ASSET_ACCOUNT_ID}}\"}}"
  get_asset_import_upload_presigned_url_jsonpath_assertions = [
    { jsonpath = "$.data.getAssetImportUploadPresignedUrl", operator = "contains", targetvalue = "https://" },
  ]

  # 3. listMeasureUnits: [GqlMeasureUnit!]!
  graphql_body_list_measure_units = "{\"query\":\"query ListMeasureUnits {\\n  listMeasureUnits {\\n    name\\n    symbol\\n    type\\n    measureGroup\\n  }\\n}\"}"
  list_measure_units_jsonpath_assertions = [
    { jsonpath = "$.data.listMeasureUnits[0].name", operator = "is", targetvalue = "Litre" },
    { jsonpath = "$.data.listMeasureUnits[0].symbol", operator = "is", targetvalue = "litre" },
    { jsonpath = "$.data.listMeasureUnits[0].type", operator = "is", targetvalue = "VOLUME" },
    { jsonpath = "$.data.listMeasureUnits[0].measureGroup", operator = "is", targetvalue = "METRIC" },
  ]

  # 4. scheduledAssetsForTasks(input: ScheduledAssetsForTasksInput!): [ScheduledAssetsForTask!]!
  # Uses DEV_SCHEDULED_ASSETS_TASK_IDS (from synthetic-test-config). Body uses {{DEV_SCHEDULED_ASSETS_TASK_IDS}} unquoted so it injects a JSON array.
  graphql_body_scheduled_assets_for_tasks = "{\"query\":\"query ScheduledAssetsForTasks($input: ScheduledAssetsForTasksInput!) {\\n  scheduledAssetsForTasks(input: $input) {\\n    taskId\\n    scheduledAssets {\\n      asset {\\n        id\\n        name\\n        category\\n        latitude\\n        longitude\\n        type\\n        imageUrl\\n        lastSeen\\n      }\\n    }\\n    overbookedAssets {\\n      complexTaskId\\n      asset {\\n        id\\n        name\\n      }\\n      complexJob {\\n        id\\n        name\\n        status\\n        salesPerson\\n        earliestTaskTimezone\\n        latestTaskTimezone\\n        startDateTime\\n        endDateTime\\n        location { name }\\n        customer { name }\\n        color { code }\\n      }\\n    }\\n  }\\n}\",\"variables\":{\"input\":{\"taskIds\":{{DEV_SCHEDULED_ASSETS_TASK_IDS}}}}}"
  scheduled_assets_for_tasks_jsonpath_assertions = [
    { jsonpath = "$.data.scheduledAssetsForTasks[0].taskId", operator = "is", targetvalue = "0468532f-bc99-42b9-9fa6-f1b0cd87789d" },
    { jsonpath = "$.data.scheduledAssetsForTasks[0].scheduledAssets[0].asset.name", operator = "is", targetvalue = "Chris' Engine Hour Pod 1" },
    { jsonpath = "$.data.scheduledAssetsForTasks[0].scheduledAssets[0].asset.category", operator = "is", targetvalue = "Engine Hours Hardware" },
  ]

  # 5. getAvailableAssetScheduleForTask(input: AvailableAssetScheduleForTaskInput!): availability + pageInfo
  # Uses DEV_AVAILABLE_ASSET_SCHEDULE_FOR_TASK_* (startDate, endDate, timezone) from synthetic-test-config.
  graphql_body_get_available_asset_schedule_for_task = "{\"query\":\"query AvailableAssetScheduleForTask($input: AvailableAssetScheduleForTaskInput!) {\\n  getAvailableAssetScheduleForTask(input: $input) {\\n    availability {\\n      asset { assetName assetStatus id attachments { primary url } address { formattedAddress name } }\\n      block { name status startDateTime endDateTime timezone complexJobs { startDateTime endDateTime name id status color { code } customer { name } salesPerson location { name } tasks { id name startDateTime endDateTime location { name } } } }\\n    }\\n    pageInfo { hasNextPage limit nextPageKey totalCount }\\n  }\\n}\",\"variables\":{\"input\":{\"startDate\":\"{{DEV_AVAILABLE_ASSET_SCHEDULE_FOR_TASK_START_DATE}}\",\"endDate\":\"{{DEV_AVAILABLE_ASSET_SCHEDULE_FOR_TASK_END_DATE}}\",\"timezone\":\"{{DEV_AVAILABLE_ASSET_SCHEDULE_FOR_TASK_TIMEZONE}}\"}}}"
  get_available_asset_schedule_for_task_jsonpath_assertions = [
    { jsonpath = "$.data.getAvailableAssetScheduleForTask.availability[0].asset.assetName", operator = "is", targetvalue = "Chris' Engine Hour Pod 1" },
    { jsonpath = "$.data.getAvailableAssetScheduleForTask.availability[0].asset.assetStatus", operator = "is", targetvalue = "Available" },
    { jsonpath = "$.data.getAvailableAssetScheduleForTask.availability[0].asset.id", operator = "is", targetvalue = "0a2bf935-0a43-4ad7-b529-c2452e37c0a2" },
    { jsonpath = "$.data.getAvailableAssetScheduleForTask.pageInfo.hasNextPage", operator = "is", targetvalue = "true" },
  ]
}

# ------------------------------------------------------------------------------
# GraphQL: assetSystemCheck (dev)
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_asset_system_check_dev" {
  name      = "GraphQL: assetSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
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
    tick_every = var.default_frequency
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
  locations = var.default_locations
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

    dynamic "assertion" {
      for_each = local.get_asset_import_upload_presigned_url_jsonpath_assertions
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

# ------------------------------------------------------------------------------
# GraphQL: listMeasureUnits (dev)
# Enable by setting locations when ready.
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_list_measure_units_dev" {
  name      = "GraphQL: listMeasureUnits"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
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

    dynamic "assertion" {
      for_each = local.list_measure_units_jsonpath_assertions
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

# ------------------------------------------------------------------------------
# GraphQL: scheduledAssetsForTasks (dev) — uses DEV_SCHEDULED_ASSETS_TASK_IDS
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_scheduled_assets_for_tasks_dev" {
  name      = "GraphQL: scheduledAssetsForTasks"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL scheduledAssetsForTasks step failed in dev."

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
    name    = "GraphQL scheduledAssetsForTasks"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_scheduled_assets_for_tasks
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
      for_each = local.scheduled_assets_for_tasks_jsonpath_assertions
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

# ------------------------------------------------------------------------------
# GraphQL: getAvailableAssetScheduleForTask (dev) — uses DEV_AVAILABLE_ASSET_SCHEDULE_FOR_TASK_*
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_get_available_asset_schedule_for_task_dev" {
  name      = "GraphQL: getAvailableAssetScheduleForTask"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:asset-inventory-service"])
  message   = "Auth0 or GraphQL getAvailableAssetScheduleForTask step failed in dev."

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
    name    = "GraphQL getAvailableAssetScheduleForTask"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint
      body      = local.graphql_body_get_available_asset_schedule_for_task
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
      for_each = local.get_available_asset_schedule_for_task_jsonpath_assertions
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
