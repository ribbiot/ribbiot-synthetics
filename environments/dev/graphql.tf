# ------------------------------------------------------------------------------
# Shared config for GraphQL multi-step tests: Auth0 token → GraphQL (dev).
# Requires: TF_VAR_dev_username, TF_VAR_dev_password, TF_VAR_dev_client_secret
# (or set in .env and source before terraform apply).
# Service-specific tests live in: graphql_asset_service.tf, graphql_job_service.tf,
# graphql_timecard_service.tf, graphql_user_service.tf.
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
}
