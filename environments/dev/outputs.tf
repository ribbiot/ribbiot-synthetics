output "railway_health_check_test_id" {
  description = "Datadog test ID for the Railway router health check."
  value       = module.railway_health_check.test_id
}

output "auth0_graphql_asset_system_check_test_id" {
  description = "Datadog test ID for GraphQL: assetSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_dev.id
}

output "auth0_graphql_user_system_check_test_id" {
  description = "Datadog test ID for GraphQL: userSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_user_system_check_dev.id
}

output "auth0_graphql_job_system_check_test_id" {
  description = "Datadog test ID for GraphQL: jobSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_job_system_check_dev.id
}

output "auth0_graphql_timecard_system_check_test_id" {
  description = "Datadog test ID for GraphQL: timecardSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_timecard_system_check_dev.id
}
