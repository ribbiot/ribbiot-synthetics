output "test_id" {
  description = "Datadog synthetic test ID."
  value       = datadog_synthetics_test.api.id
}

output "test_monitor_id" {
  description = "Datadog monitor ID created for this synthetic test."
  value       = datadog_synthetics_test.api.monitor_id
}
