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

  # Assertions from synthetic-test-config (source of truth). Key = query name in YAML. Run: npm run tfvars:from-synthetic-test-config
  job_system_check_jsonpath_assertions       = lookup(var.synthetic_test_assertions, "jobSystemCheck", [])
  complex_job_jsonpath_assertions            = lookup(var.synthetic_test_assertions, "complexJob", [])
  price_book_items_jsonpath_assertions       = lookup(var.synthetic_test_assertions, "priceBookItems", [])
  color_jsonpath_assertions                  = lookup(var.synthetic_test_assertions, "color", [])
  colors_jsonpath_assertions                 = lookup(var.synthetic_test_assertions, "colors", [])
  complex_jobs_jsonpath_assertions           = lookup(var.synthetic_test_assertions, "complexJobs", [])
  complex_task_jsonpath_assertions           = lookup(var.synthetic_test_assertions, "complexTask", [])
  complex_tasks_jsonpath_assertions          = lookup(var.synthetic_test_assertions, "complexTasks", [])
  complex_invoices_jsonpath_assertions       = lookup(var.synthetic_test_assertions, "complexInvoices", [])
  complex_tasks_for_user_jsonpath_assertions = lookup(var.synthetic_test_assertions, "complexTasksForUser", [])
  complex_task_entries_jsonpath_assertions   = lookup(var.synthetic_test_assertions, "complexTaskEntries", [])
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
