output "railway_health_check_test_id" {
  description = "Datadog test ID for the prod Railway router health check."
  value       = module.railway_health_check.test_id
}
