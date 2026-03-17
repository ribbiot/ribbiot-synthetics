# ------------------------------------------------------------------------------
# Shared config for GraphQL multi-step tests: Auth0 token → GraphQL (dev).
# Requires: TF_VAR_dev_username, TF_VAR_dev_password, TF_VAR_dev_client_secret
# (or set in .env and source before terraform apply).
# Service-specific tests live in: graphql_asset_service.tf, graphql_job_service.tf,
# graphql_timecard_service.tf, graphql_user_service.tf.
# ------------------------------------------------------------------------------

# Global variables stored in Datadog; secrets passed via Terraform vars (never commit).
# Store raw values in .env / tfvars; we URL-encode here so the Auth0 form body is valid.
resource "datadog_synthetics_global_variable" "dev_auth0_domain" {
  name  = "DEV_AUTH0_DOMAIN"
  value = var.dev_auth0_domain
}

resource "datadog_synthetics_global_variable" "dev_username" {
  name  = "DEV_USERNAME"
  value = urlencode(var.dev_username)
}

resource "datadog_synthetics_global_variable" "dev_password" {
  name   = "DEV_PASSWORD"
  secure = true
  value  = urlencode(var.dev_password)
}

resource "datadog_synthetics_global_variable" "dev_client_secret" {
  name   = "DEV_CLIENT_SECRET"
  secure = true
  value  = urlencode(var.dev_client_secret)
}

# Synthetic test config globals: one per key in synthetic_data_values (from synthetic-test-config/graphql/<env>/*.yaml).
# Values are always strings (script JSON-encodes arrays).
resource "datadog_synthetics_global_variable" "synthetic_data" {
  for_each = var.synthetic_data_values
  name     = each.key
  value    = each.value
}

# Migrate existing DEV_ASSET_ACCOUNT_ID from the old resource to the new for_each (avoids destroy+recreate).
moved {
  from = datadog_synthetics_global_variable.dev_asset_account_id
  to   = datadog_synthetics_global_variable.synthetic_data["DEV_ASSET_ACCOUNT_ID"]
}

# Reusable config_variable lists so tests can concat auth + synthetic data without repeating blocks.
locals {
  auth_config_vars = [
    { name = "DEV_AUTH0_DOMAIN", id = datadog_synthetics_global_variable.dev_auth0_domain.id, type = "global" },
    { name = "DEV_USERNAME", id = datadog_synthetics_global_variable.dev_username.id, type = "global" },
    { name = "DEV_PASSWORD", id = datadog_synthetics_global_variable.dev_password.id, type = "global" },
    { name = "DEV_CLIENT_SECRET", id = datadog_synthetics_global_variable.dev_client_secret.id, type = "global" },
  ]
  synthetic_data_config_vars = [
    for k, v in datadog_synthetics_global_variable.synthetic_data : { name = k, id = v.id, type = "global" }
  ]
  graphql_config_variables = concat(local.auth_config_vars, local.synthetic_data_config_vars)
}

# Auth0 token request body (form-urlencoded). Audience must be valid for password grant.
# Scopes: general:tracker, mobileassets:user, mobilehome:user, mobile:provisioning, mobile:user,
#         mobile:vtrackers, ribbiot:admin, timecard:admin, timecard:user, web:assetcrud, web:assetmap,
#         web:invoice, web:quoting, web:schedule, web:settings, web:usercrud
locals {
  auth0_body = "username={{DEV_USERNAME}}&password={{DEV_PASSWORD}}&client_id=1jA5AOlVzwDksR9YXX7u71tVVWa2tDFo&client_secret={{DEV_CLIENT_SECRET}}&grant_type=password&audience=https%3A%2F%2Fv656y9o6s7.execute-api.us-east-1.amazonaws.com%2Fdev&redirect_uri=https%3A%2F%2Fgoogle.com&scope=general%3Atracker%20mobileassets%3Auser%20mobilehome%3Auser%20mobile%3Aprovisioning%20mobile%3Auser%20mobile%3Avtrackers%20ribbiot%3Aadmin%20timecard%3Aadmin%20timecard%3Auser%20web%3Aassetcrud%20web%3Aassetmap%20web%3Ainvoice%20web%3Aquoting%20web%3Aschedule%20web%3Asettings%20web%3Ausercrud"
}
