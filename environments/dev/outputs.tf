output "example_health_check_test_id" {
  description = "Datadog test ID for the example health check."
  value       = module.example_health_check.test_id
}

output "example_health_check_monitor_id" {
  description = "Monitor ID for the example health check."
  value       = module.example_health_check.test_monitor_id
}

output "railway_health_check_test_id" {
  description = "Datadog test ID for the Railway router health check."
  value       = module.railway_health_check.test_id
}
