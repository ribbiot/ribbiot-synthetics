# ------------------------------------------------------------------------------
# GraphQL Job Service tests (dev): Auth0 → GraphQL.
# Tests here must match synthetic-test-config: only queries without excluded: true get a resource.
# Implemented: jobSystemCheck, complexJob, priceBookItems, color, colors, complexJobs, complexTask, complexTasks, complexInvoices, complexTasksForUser, complexTaskEntries. Config: synthetic-test-config/graphql/dev/job-service.yaml.
# Note: "assertion.target is not valid for validatesJSONPath" warning is a known
# provider bug (terraform-provider-datadog#3362); safe to ignore.
# ------------------------------------------------------------------------------

locals {
  graphql_endpoint_job          = "https://ribbiot-router-dev.up.railway.app/graphql"
  graphql_body_job_system_check = "{\"query\":\"query JobSystemCheck($input: SystemCheckInput) {\\n  jobSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"

  # complexJob(input: ComplexJobInput!); uses DEV_COMPLEX_JOB_ID from synthetic-test-config.
  graphql_body_complex_job = "{\"query\":\"query ComplexJob($input: ComplexJobInput!) {\\n  complexJob(input: $input) {\\n    id\\n    name\\n    status\\n    customer { name }\\n    tasks { id name }\\n  }\\n}\",\"variables\":{\"input\":{\"id\":\"{{DEV_COMPLEX_JOB_ID}}\"}}}"

  # priceBookItems(filters: ListPriceBookItemsInput!); empty filters.
  graphql_body_price_book_items = "{\"query\":\"query PriceBookItems($filters: ListPriceBookItemsInput!) {\\n  priceBookItems(filters: $filters) {\\n    id\\n    accountId\\n    name\\n    description\\n    rate\\n    unit\\n    category\\n    status\\n    active\\n  }\\n}\",\"variables\":{\"filters\":{}}}"

  # color(id: ID!); uses DEV_JOB_COLOR_ID from synthetic-test-config.
  graphql_body_color = "{\"query\":\"query Color($colorId: ID!) {\\n  color(id: $colorId) {\\n    id\\n    accountId\\n    name\\n    code\\n    createdAt\\n    updatedAt\\n  }\\n}\",\"variables\":{\"colorId\":\"{{DEV_JOB_COLOR_ID}}\"}}"

  # colors(filters: ListColorsInput!); uses DEV_JOB_COLORS_ACCOUNT_ID for filters.accountId.
  graphql_body_colors = "{\"query\":\"query Colors($filters: ListColorsInput!) {\\n  colors(filters: $filters) {\\n    id\\n    accountId\\n    name\\n    code\\n    createdAt\\n    updatedAt\\n  }\\n}\",\"variables\":{\"filters\":{\"accountId\":\"{{DEV_JOB_COLORS_ACCOUNT_ID}}\"}}}"

  # complexJobs(filters: ListComplexJobsInput!); uses DEV_COMPLEX_JOBS_START_DATE, DEV_COMPLEX_JOBS_END_DATE.
  graphql_body_complex_jobs = "{\"query\":\"query ComplexJobs($filters: ListComplexJobsInput!) {\\n  complexJobs(filters: $filters) {\\n    items {\\n      id\\n      name\\n      number\\n      customer { name }\\n      startDate\\n      endDate\\n      tasks { id name }\\n    }\\n    pageInfo { nextPageKey hasNextPage totalCount }\\n  }\\n}\",\"variables\":{\"filters\":{\"branchIds\":[],\"divisionIds\":[],\"startDate\":\"{{DEV_COMPLEX_JOBS_START_DATE}}\",\"endDate\":\"{{DEV_COMPLEX_JOBS_END_DATE}}\",\"pageInfo\":{\"nextPageKey\":\"\"}}}}"

  # complexTask(id: ID!); uses DEV_JOB_COMPLEX_TASK_ID from synthetic-test-config.
  graphql_body_complex_task = "{\"query\":\"query ComplexTask($complexTaskId: ID!) {\\n  complexTask(id: $complexTaskId) {\\n    id\\n    name\\n    status\\n    startDate\\n    endDate\\n    timezone\\n    startDateTime\\n    endDateTime\\n    job { id name status number }\\n  }\\n}\",\"variables\":{\"complexTaskId\":\"{{DEV_JOB_COMPLEX_TASK_ID}}\"}}"

  # complexTasks(filters: ListComplexTasksInput!); uses DEV_COMPLEX_TASKS_AFTER_DATE, DEV_COMPLEX_TASKS_BEFORE_DATE.
  graphql_body_complex_tasks = "{\"query\":\"query ComplexTasks($filters: ListComplexTasksInput!) {\\n  complexTasks(filters: $filters) {\\n    id\\n    name\\n    startDateTime\\n    endDateTime\\n    timezone\\n    startDate\\n    endDate\\n    job { id name number status }\\n  }\\n}\",\"variables\":{\"filters\":{\"afterDate\":\"{{DEV_COMPLEX_TASKS_AFTER_DATE}}\",\"beforeDate\":\"{{DEV_COMPLEX_TASKS_BEFORE_DATE}}\"}}}"

  # complexInvoices(filters: ListComplexInvoicesInput!); uses DEV_COMPLEX_JOB_ID for filters.complexJobId.
  graphql_body_complex_invoices = "{\"query\":\"query ComplexInvoices($filters: ListComplexInvoicesInput!) {\\n  complexInvoices(filters: $filters) {\\n    id\\n    accountId\\n    status\\n    amountCents\\n    cycleStartDate\\n    cycleEndDate\\n    job { id name customer { name } }\\n  }\\n}\",\"variables\":{\"filters\":{\"complexJobId\":\"{{DEV_COMPLEX_JOB_ID}}\"}}}"

  # complexTasksForUser(filters: ListComplexTasksForUserInput!); uses DEV_COMPLEX_TASKS_FOR_USER_START_DATE, DEV_COMPLEX_TASKS_FOR_USER_END_DATE.
  graphql_body_complex_tasks_for_user = "{\"query\":\"query ComplexTasksForUser($filters: ListComplexTasksForUserInput!) {\\n  complexTasksForUser(filters: $filters) {\\n    id\\n    name\\n    status\\n    accountId\\n    startDate\\n    endDate\\n    timezone\\n    startDateTime\\n    endDateTime\\n  }\\n}\",\"variables\":{\"filters\":{\"startDate\":\"{{DEV_COMPLEX_TASKS_FOR_USER_START_DATE}}\",\"endDate\":\"{{DEV_COMPLEX_TASKS_FOR_USER_END_DATE}}\"}}}"

  # complexTaskEntries(filters: ListComplexTaskEntriesInput!); uses DEV_COMPLEX_TASK_ENTRIES_ACCOUNT_ID. Short selection set.
  graphql_body_complex_task_entries = "{\"query\":\"query ComplexTaskEntries($filters: ListComplexTaskEntriesInput!) {\\n  complexTaskEntries(filters: $filters) {\\n    id\\n    accountId\\n    complexTaskId\\n    entryDate\\n    timezone\\n  }\\n}\",\"variables\":{\"filters\":{\"accountId\":\"{{DEV_COMPLEX_TASK_ENTRIES_ACCOUNT_ID}}\"}}}"

  # validatesJSONPath assertions (mirror synthetic-test-config/graphql/dev/job-service.yaml)
  job_system_check_jsonpath_assertions = [
    { jsonpath = "$.data.jobSystemCheck.message", operator = "is", targetvalue = "Job Service is Running!" },
    { jsonpath = "$.data.jobSystemCheck.launchDarklyStatus", operator = "is", targetvalue = "OK" },
    { jsonpath = "$.data.jobSystemCheck.sqlStatus", operator = "is", targetvalue = "OK" },
  ]
  complex_job_jsonpath_assertions = [
    { jsonpath = "$.data.complexJob.id", operator = "is", targetvalue = "d3484afb-b2cd-455b-b353-f745c5fa4d21" },
    { jsonpath = "$.data.complexJob.name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexJob.status", operator = "is", targetvalue = "SCHEDULED" },
    { jsonpath = "$.data.complexJob.customer.name", operator = "is", targetvalue = "Datadog" },
    { jsonpath = "$.data.complexJob.tasks[0].id", operator = "is", targetvalue = "0468532f-bc99-42b9-9fa6-f1b0cd87789d" },
  ]
  price_book_items_jsonpath_assertions = [
    { jsonpath = "$.data.priceBookItems[0].accountId", operator = "is", targetvalue = "dfb43473-e136-4ede-971f-3238b18d1f8b" },
    { jsonpath = "$.data.priceBookItems[0].status", operator = "is", targetvalue = "active" },
    { jsonpath = "$.data.priceBookItems[1].name", operator = "is", targetvalue = "Datadog Pricebook Item 1" },
  ]
  color_jsonpath_assertions = [
    { jsonpath = "$.data.color.id", operator = "is", targetvalue = "d3f41c6e-afa8-41b4-9666-3ac2aa188b05" },
    { jsonpath = "$.data.color.accountId", operator = "is", targetvalue = "dfb43473-e136-4ede-971f-3238b18d1f8b" },
    { jsonpath = "$.data.color.name", operator = "is", targetvalue = "Sienna" },
    { jsonpath = "$.data.color.code", operator = "is", targetvalue = "#A5243D" },
  ]
  colors_jsonpath_assertions = [
    { jsonpath = "$.data.colors[0].accountId", operator = "is", targetvalue = "dfb43473-e136-4ede-971f-3238b18d1f8b" },
    { jsonpath = "$.data.colors[0].name", operator = "is", targetvalue = "Blue" },
    { jsonpath = "$.data.colors[0].code", operator = "is", targetvalue = "#2F5FC1" },
  ]
  complex_jobs_jsonpath_assertions = [
    { jsonpath = "$.data.complexJobs.items[2].id", operator = "is", targetvalue = "d3484afb-b2cd-455b-b353-f745c5fa4d21" },
    { jsonpath = "$.data.complexJobs.items[2].name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexJobs.items[2].customer.name", operator = "is", targetvalue = "Datadog" },
    { jsonpath = "$.data.complexJobs.pageInfo.hasNextPage", operator = "is", targetvalue = "false" },
    { jsonpath = "$.data.complexJobs.pageInfo.totalCount", operator = "is", targetvalue = "3" },
  ]
  complex_task_jsonpath_assertions = [
    { jsonpath = "$.data.complexTask.id", operator = "is", targetvalue = "0468532f-bc99-42b9-9fa6-f1b0cd87789d" },
    { jsonpath = "$.data.complexTask.name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexTask.status", operator = "is", targetvalue = "SCHEDULED" },
    { jsonpath = "$.data.complexTask.job.id", operator = "is", targetvalue = "d3484afb-b2cd-455b-b353-f745c5fa4d21" },
    { jsonpath = "$.data.complexTask.job.name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexTask.job.status", operator = "is", targetvalue = "SCHEDULED" },
  ]
  complex_tasks_jsonpath_assertions = [
    { jsonpath = "$.data.complexTasks[0].id", operator = "is", targetvalue = "0468532f-bc99-42b9-9fa6-f1b0cd87789d" },
    { jsonpath = "$.data.complexTasks[0].name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexTasks[0].job.id", operator = "is", targetvalue = "d3484afb-b2cd-455b-b353-f745c5fa4d21" },
    { jsonpath = "$.data.complexTasks[0].job.name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexTasks[0].job.status", operator = "is", targetvalue = "SCHEDULED" },
  ]
  complex_invoices_jsonpath_assertions = [
    { jsonpath = "$.data.complexInvoices[0].id", operator = "is", targetvalue = "32662958-039f-4f36-90bb-5a4364e9c807" },
    { jsonpath = "$.data.complexInvoices[0].accountId", operator = "is", targetvalue = "dfb43473-e136-4ede-971f-3238b18d1f8b" },
    { jsonpath = "$.data.complexInvoices[0].status", operator = "is", targetvalue = "READY_TO_APPROVE" },
    { jsonpath = "$.data.complexInvoices[0].job.id", operator = "is", targetvalue = "d3484afb-b2cd-455b-b353-f745c5fa4d21" },
    { jsonpath = "$.data.complexInvoices[0].job.name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexInvoices[0].job.customer.name", operator = "is", targetvalue = "Datadog" },
  ]
  complex_tasks_for_user_jsonpath_assertions = [
    { jsonpath = "$.data.complexTasksForUser[0].id", operator = "is", targetvalue = "0468532f-bc99-42b9-9fa6-f1b0cd87789d" },
    { jsonpath = "$.data.complexTasksForUser[0].name", operator = "is", targetvalue = "Datadog Synthetic Data (DON'T DELETE)" },
    { jsonpath = "$.data.complexTasksForUser[0].status", operator = "is", targetvalue = "SCHEDULED" },
    { jsonpath = "$.data.complexTasksForUser[0].accountId", operator = "is", targetvalue = "dfb43473-e136-4ede-971f-3238b18d1f8b" },
  ]
  complex_task_entries_jsonpath_assertions = [
    { jsonpath = "$.data.complexTaskEntries[0].accountId", operator = "is", targetvalue = "dfb43473-e136-4ede-971f-3238b18d1f8b" },
    { jsonpath = "$.data.complexTaskEntries[0].complexTaskId", operator = "is", targetvalue = "6522c383-36cc-4f4d-9089-19b4dcad70f5" },
    { jsonpath = "$.data.complexTaskEntries[0].entryDate", operator = "is", targetvalue = "2026-08-20" },
    { jsonpath = "$.data.complexTaskEntries[0].timezone", operator = "is", targetvalue = "America/Chicago" },
  ]
}

resource "datadog_synthetics_test" "auth0_graphql_job_system_check_dev" {
  name      = "GraphQL: jobSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL jobSystemCheck step failed in dev. Check token or GraphQL endpoint."

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

# ------------------------------------------------------------------------------
# GraphQL: complexJob (dev) — uses DEV_COMPLEX_JOB_ID
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_complex_job_dev" {
  name      = "GraphQL: complexJob"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL complexJob step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL complexJob"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_complex_job
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
      for_each = local.complex_job_jsonpath_assertions
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
# GraphQL: priceBookItems (dev) — empty filters
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_price_book_items_dev" {
  name      = "GraphQL: priceBookItems"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL priceBookItems step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL priceBookItems"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_price_book_items
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
      for_each = local.price_book_items_jsonpath_assertions
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
# GraphQL: color (dev) — uses DEV_JOB_COLOR_ID
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_color_dev" {
  name      = "GraphQL: color"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL color step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL color"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_color
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
      for_each = local.color_jsonpath_assertions
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
# GraphQL: colors (dev) — uses DEV_JOB_COLORS_ACCOUNT_ID
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_colors_dev" {
  name      = "GraphQL: colors"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL colors step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL colors"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_colors
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
      for_each = local.colors_jsonpath_assertions
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
# GraphQL: complexJobs (dev) — uses DEV_COMPLEX_JOBS_START_DATE, DEV_COMPLEX_JOBS_END_DATE
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_complex_jobs_dev" {
  name      = "GraphQL: complexJobs"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL complexJobs step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL complexJobs"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_complex_jobs
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
      for_each = local.complex_jobs_jsonpath_assertions
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
# GraphQL: complexTasks (dev) — uses DEV_COMPLEX_TASKS_AFTER_DATE, DEV_COMPLEX_TASKS_BEFORE_DATE
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_complex_tasks_dev" {
  name      = "GraphQL: complexTasks"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL complexTasks step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL complexTasks"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_complex_tasks
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
      for_each = local.complex_tasks_jsonpath_assertions
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
# GraphQL: complexTask (dev) — uses DEV_JOB_COMPLEX_TASK_ID
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_complex_task_dev" {
  name      = "GraphQL: complexTask"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL complexTask step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL complexTask"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_complex_task
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
      for_each = local.complex_task_jsonpath_assertions
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
# GraphQL: complexInvoices (dev) — uses DEV_COMPLEX_JOB_ID for filters.complexJobId
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_complex_invoices_dev" {
  name      = "GraphQL: complexInvoices"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL complexInvoices step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL complexInvoices"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_complex_invoices
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
      for_each = local.complex_invoices_jsonpath_assertions
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
# GraphQL: complexTasksForUser (dev) — uses DEV_COMPLEX_TASKS_FOR_USER_START_DATE, DEV_COMPLEX_TASKS_FOR_USER_END_DATE
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_complex_tasks_for_user_dev" {
  name      = "GraphQL: complexTasksForUser"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL complexTasksForUser step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL complexTasksForUser"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_complex_tasks_for_user
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
      for_each = local.complex_tasks_for_user_jsonpath_assertions
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
# GraphQL: complexTaskEntries (dev) — uses DEV_COMPLEX_TASK_ENTRIES_ACCOUNT_ID; short query
# ------------------------------------------------------------------------------

resource "datadog_synthetics_test" "auth0_graphql_complex_task_entries_dev" {
  name      = "GraphQL: complexTaskEntries"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = var.default_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:jobs-management-service"])
  message   = "Auth0 or GraphQL complexTaskEntries step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL complexTaskEntries"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_job
      body      = local.graphql_body_complex_task_entries
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
      for_each = local.complex_task_entries_jsonpath_assertions
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
