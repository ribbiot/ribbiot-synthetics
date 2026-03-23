# ------------------------------------------------------------------------------
# GraphQL Timecard Service tests (dev): Auth0 → GraphQL.
# Note: "assertion.target is not valid for validatesJSONPath" warning is a known
# provider bug (terraform-provider-datadog#3362); safe to ignore.
# ------------------------------------------------------------------------------

locals {
  graphql_endpoint_timecard          = "https://ribbiot-router-dev.up.railway.app/graphql"
  graphql_body_timecard_system_check = "{\"query\":\"query TimecardSystemCheck($input: SystemCheckInput) {\\n  timecardSystemCheck(input: $input) {\\n    message\\n    environment\\n    featureFlags\\n    launchDarklyStatus\\n    sqlStatus\\n  }\\n}\",\"variables\":{\"input\":{\"checkLaunchDarkly\":true,\"checkSQL\":true}}}"
  graphql_body_form_template         = "{\"query\":\"query FormTemplate($formTemplateId: ID!) {\\n  formTemplate(id: $formTemplateId) {\\n    id\\n    formTypeSlug\\n    name\\n  }\\n}\",\"variables\":{\"formTemplateId\":\"{{DEV_TIMECARD_FORM_TEMPLATE_ID}}\"}}"
  graphql_body_form_templates        = "{\"query\":\"query FormTemplates($accountId: ID!, $filters: ListFormTemplatesInput) {\\n  formTemplates(accountId: $accountId, filters: $filters) {\\n    id\\n    accountId\\n    name\\n    formType { slug displayName }\\n  }\\n}\",\"variables\":{\"accountId\":\"{{DEV_TIMECARD_ACCOUNT_ID}}\"}}"
  graphql_body_form_submission       = "{\"query\":\"query FormSubmission($formSubmissionId: ID!) {\\n  formSubmission(id: $formSubmissionId) {\\n    id\\n    accountId\\n    formId\\n    version\\n    totalHours\\n  }\\n}\",\"variables\":{\"formSubmissionId\":\"{{DEV_TIMECARD_FORM_SUBMISSION_ID}}\"}}"
  graphql_body_form_type             = "{\"query\":\"query FormType($slug: String!) {\\n  formType(slug: $slug) {\\n    slug\\n    displayName\\n    description\\n    createdAt\\n    updatedAt\\n    iconUrl\\n    bgColor\\n    iconType\\n    ordinal\\n    isGlobal\\n  }\\n}\",\"variables\":{\"slug\":\"{{DEV_TIMECARD_FORM_TYPE_SLUG}}\"}}"
  graphql_body_form_types            = "{\"query\":\"query FormTypes {\\n  formTypes {\\n    slug\\n    displayName\\n    description\\n    createdAt\\n    updatedAt\\n    iconUrl\\n    bgColor\\n    iconType\\n    ordinal\\n    isGlobal\\n  }\\n}\",\"variables\":{}}"
  graphql_body_form_pdf_config       = "{\"query\":\"query FormPDFConfig($formId: ID!) {\\n  formPDFConfig(formId: $formId) {\\n    cssTemplate\\n    hbsTemplate\\n    fields {\\n      fieldId\\n      format\\n      label\\n      fields {\\n        fieldId\\n        format\\n        label\\n      }\\n    }\\n  }\\n}\",\"variables\":{\"formId\":\"{{DEV_TIMECARD_FORM_ID_FOR_PDF_CONFIG}}\"}}"
  graphql_body_form_submissions           = "{\"query\":\"query FormSubmissions($filters: ListFormSubmissionsInput!) {\\n  formSubmissions(filters: $filters) {\\n    items { id formId }\\n  }\\n}\",\"variables\":{\"filters\":{\"startDate\":\"{{DEV_TIMECARD_SUBMISSIONS_START_DATE}}\",\"endDate\":\"{{DEV_TIMECARD_SUBMISSIONS_END_DATE}}\",\"formId\":\"{{DEV_TIMECARD_FORM_ID_FOR_SUBMISSIONS}}\"}}}"
  graphql_body_form_submissions_for_invoice = "{\"query\":\"query JobTimecards($filters: ListFormSubmissionsForInvoiceInput!) {\\n  formSubmissionsForInvoice(filters: $filters) {\\n    items {\\n      id\\n      number\\n      userId\\n      formId\\n      createdAt\\n      totalHours\\n      localDateTime\\n      fields {\\n        item {\\n          ... on GqlFieldUsers {\\n            users {\\n              occupationId\\n              userId\\n              userName\\n            }\\n          }\\n        }\\n      }\\n    }\\n    pageInfo {\\n      hasNextPage\\n      limit\\n      nextPageKey\\n      totalCount\\n    }\\n  }\\n}\",\"variables\":{\"filters\":{\"jobNumber\":\"{{DEV_TIMECARD_INVOICE_JOB_NUMBER}}\",\"startDate\":\"{{DEV_TIMECARD_INVOICE_START_DATE}}\",\"pageInfo\":{\"limit\":20,\"nextPageKey\":\"\"}}}}"
  graphql_body_form_template_home_page            = "{\"query\":\"query FormTemplateHomePage($accountId: ID) {\\n  formTemplateHomePage(accountId: $accountId) {\\n    quickLinks {\\n      accountId\\n      formId\\n      formType {\\n        slug\\n        displayName\\n      }\\n      formTemplate {\\n        id\\n      }\\n      divisionIds\\n      displayName\\n      ordinal\\n      createdAt\\n      updatedAt\\n    }\\n  }\\n}\",\"variables\":{\"accountId\":\"{{DEV_TIMECARD_ACCOUNT_ID}}\"}}"
  graphql_body_form_template_notification_config = "{\"query\":\"query FormTemplateNotificationConfig($formTemplateId: ID!) {\\n  formTemplateNotificationConfig(formTemplateId: $formTemplateId) {\\n    formTemplateId\\n    emails\\n    templateId\\n  }\\n}\",\"variables\":{\"formTemplateId\":\"{{DEV_TIMECARD_FORM_TEMPLATE_ID}}\"}}"

  # Assertions from synthetic-test-config (source of truth). Run: npm run tfvars:from-synthetic-test-config
  timecard_system_check_jsonpath_assertions = lookup(var.synthetic_test_assertions, "timecardSystemCheck", [])
  form_template_jsonpath_assertions         = lookup(var.synthetic_test_assertions, "formTemplate", [])
  form_templates_jsonpath_assertions       = lookup(var.synthetic_test_assertions, "formTemplates", [])
  form_submission_jsonpath_assertions     = lookup(var.synthetic_test_assertions, "formSubmission", [])
  form_type_jsonpath_assertions           = lookup(var.synthetic_test_assertions, "formType", [])
  form_types_jsonpath_assertions          = lookup(var.synthetic_test_assertions, "formTypes", [])
  form_pdf_config_jsonpath_assertions     = lookup(var.synthetic_test_assertions, "formPDFConfig", [])
  form_submissions_jsonpath_assertions           = lookup(var.synthetic_test_assertions, "formSubmissions", [])
  form_submissions_for_invoice_jsonpath_assertions = lookup(var.synthetic_test_assertions, "formSubmissionsForInvoice", [])
  form_template_home_page_jsonpath_assertions            = lookup(var.synthetic_test_assertions, "formTemplateHomePage", [])
  form_template_notification_config_jsonpath_assertions = lookup(var.synthetic_test_assertions, "formTemplateNotificationConfig", [])
}

resource "datadog_synthetics_test" "auth0_graphql_timecard_system_check_dev" {
  name      = "GraphQL: timecardSystemCheck"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL timecardSystemCheck step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL timecardSystemCheck"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
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

    dynamic "assertion" {
      for_each = local.timecard_system_check_jsonpath_assertions
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
# GraphQL formTemplate (Timecard): Auth0 → formTemplate(id).
# Uses DEV_TIMECARD_FORM_TEMPLATE_ID from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_template_dev" {
  name      = "GraphQL: formTemplate"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formTemplate step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formTemplate"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_template
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
      for_each = local.form_template_jsonpath_assertions
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
# GraphQL formTemplates (Timecard): Auth0 → formTemplates(accountId, filters?).
# Uses DEV_TIMECARD_ACCOUNT_ID from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_templates_dev" {
  name      = "GraphQL: formTemplates"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formTemplates step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formTemplates"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_templates
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
      for_each = local.form_templates_jsonpath_assertions
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
# GraphQL formSubmission (Timecard): Auth0 → formSubmission(id).
# Uses DEV_TIMECARD_FORM_SUBMISSION_ID from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_submission_dev" {
  name      = "GraphQL: formSubmission"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formSubmission step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formSubmission"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_submission
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
      for_each = local.form_submission_jsonpath_assertions
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
# GraphQL formType (Timecard): Auth0 → formType(slug).
# Uses DEV_TIMECARD_FORM_TYPE_SLUG from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_type_dev" {
  name      = "GraphQL: formType"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formType step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formType"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_type
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
      for_each = local.form_type_jsonpath_assertions
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
# GraphQL formTypes (Timecard): Auth0 → formTypes (no args).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_types_dev" {
  name      = "GraphQL: formTypes"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formTypes step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formTypes"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_types
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
      for_each = local.form_types_jsonpath_assertions
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
# GraphQL formPDFConfig (Timecard): Auth0 → formPDFConfig(formId).
# Uses DEV_TIMECARD_FORM_ID_FOR_PDF_CONFIG from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_pdf_config_dev" {
  name      = "GraphQL: formPDFConfig"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formPDFConfig step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formPDFConfig"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_pdf_config
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
      for_each = local.form_pdf_config_jsonpath_assertions
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
# GraphQL formSubmissions (Timecard): Auth0 → formSubmissions(filters).
# Uses DEV_TIMECARD_FORM_ID_FOR_SUBMISSIONS, DEV_TIMECARD_SUBMISSIONS_START_DATE,
# DEV_TIMECARD_SUBMISSIONS_END_DATE from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_submissions_dev" {
  name      = "GraphQL: formSubmissions"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formSubmissions step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formSubmissions"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_submissions
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
      for_each = local.form_submissions_jsonpath_assertions
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
# GraphQL formSubmissionsForInvoice (Timecard): Auth0 → formSubmissionsForInvoice(filters).
# Uses DEV_TIMECARD_INVOICE_JOB_NUMBER, DEV_TIMECARD_INVOICE_START_DATE from synthetic-test-config.
# Request pageInfo uses limit 20 and empty nextPageKey (fixed in local graphql_body).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_submissions_for_invoice_dev" {
  name      = "GraphQL: formSubmissionsForInvoice"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formSubmissionsForInvoice step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formSubmissionsForInvoice"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_submissions_for_invoice
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
      for_each = local.form_submissions_for_invoice_jsonpath_assertions
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
# GraphQL formTemplateHomePage (Timecard): Auth0 → formTemplateHomePage(accountId?).
# Uses DEV_TIMECARD_ACCOUNT_ID from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_template_home_page_dev" {
  name      = "GraphQL: formTemplateHomePage"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formTemplateHomePage step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formTemplateHomePage"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_template_home_page
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
      for_each = local.form_template_home_page_jsonpath_assertions
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
# GraphQL formTemplateNotificationConfig (Timecard): Auth0 → formTemplateNotificationConfig(formTemplateId).
# Uses DEV_TIMECARD_FORM_TEMPLATE_ID from synthetic-test-config (timecard-service.yaml).
# ------------------------------------------------------------------------------
resource "datadog_synthetics_test" "auth0_graphql_timecard_form_template_notification_config_dev" {
  name      = "GraphQL: formTemplateNotificationConfig"
  type      = "api"
  subtype   = "multi"
  status    = "live"
  locations = local.railway_test_locations
  tags      = concat([for t in local.base_tags : t if t != "project:railway"], ["project:graphql", "service:time-card-service"])
  message   = "Auth0 or GraphQL formTemplateNotificationConfig step failed in dev. Check token or GraphQL endpoint."

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
    name    = "GraphQL formTemplateNotificationConfig"
    subtype = "http"

    request_definition {
      method    = "POST"
      url       = local.graphql_endpoint_timecard
      body      = local.graphql_body_form_template_notification_config
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
      for_each = local.form_template_notification_config_jsonpath_assertions
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
