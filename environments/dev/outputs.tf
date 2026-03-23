output "railway_health_check_test_id" {
  description = "Datadog test ID for the Railway router health check."
  value       = module.railway_health_check.test_id
}

output "auth0_graphql_asset_system_check_test_id" {
  description = "Datadog test ID for GraphQL: assetSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_asset_system_check_dev.id
}

output "auth0_graphql_user_system_check_test_id" {
  description = "Datadog test ID for GraphQL: userSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_user_system_check_dev.id
}

output "graphql_public_user_service_settings_test_id" {
  description = "Datadog test ID for GraphQL (public): publicUserServiceSettings."
  value       = datadog_synthetics_test.graphql_public_user_service_settings_dev.id
}

output "auth0_graphql_job_system_check_test_id" {
  description = "Datadog test ID for GraphQL: jobSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_job_system_check_dev.id
}

output "auth0_graphql_complex_job_test_id" {
  description = "Datadog test ID for GraphQL: complexJob."
  value       = datadog_synthetics_test.auth0_graphql_complex_job_dev.id
}

output "auth0_graphql_complex_task_test_id" {
  description = "Datadog test ID for GraphQL: complexTask."
  value       = datadog_synthetics_test.auth0_graphql_complex_task_dev.id
}

output "auth0_graphql_price_book_items_test_id" {
  description = "Datadog test ID for GraphQL: priceBookItems."
  value       = datadog_synthetics_test.auth0_graphql_price_book_items_dev.id
}

output "auth0_graphql_color_test_id" {
  description = "Datadog test ID for GraphQL: color."
  value       = datadog_synthetics_test.auth0_graphql_color_dev.id
}

output "auth0_graphql_colors_test_id" {
  description = "Datadog test ID for GraphQL: colors."
  value       = datadog_synthetics_test.auth0_graphql_colors_dev.id
}

output "auth0_graphql_complex_jobs_test_id" {
  description = "Datadog test ID for GraphQL: complexJobs."
  value       = datadog_synthetics_test.auth0_graphql_complex_jobs_dev.id
}

output "auth0_graphql_complex_tasks_test_id" {
  description = "Datadog test ID for GraphQL: complexTasks."
  value       = datadog_synthetics_test.auth0_graphql_complex_tasks_dev.id
}

output "auth0_graphql_complex_invoices_test_id" {
  description = "Datadog test ID for GraphQL: complexInvoices."
  value       = datadog_synthetics_test.auth0_graphql_complex_invoices_dev.id
}

output "auth0_graphql_complex_tasks_for_user_test_id" {
  description = "Datadog test ID for GraphQL: complexTasksForUser."
  value       = datadog_synthetics_test.auth0_graphql_complex_tasks_for_user_dev.id
}

output "auth0_graphql_timecard_system_check_test_id" {
  description = "Datadog test ID for GraphQL: timecardSystemCheck."
  value       = datadog_synthetics_test.auth0_graphql_timecard_system_check_dev.id
}

output "auth0_graphql_timecard_form_template_test_id" {
  description = "Datadog test ID for GraphQL: formTemplate."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_template_dev.id
}

output "auth0_graphql_timecard_form_templates_test_id" {
  description = "Datadog test ID for GraphQL: formTemplates."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_templates_dev.id
}

output "auth0_graphql_timecard_form_submission_test_id" {
  description = "Datadog test ID for GraphQL: formSubmission."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_submission_dev.id
}

output "auth0_graphql_timecard_form_type_test_id" {
  description = "Datadog test ID for GraphQL: formType."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_type_dev.id
}

output "auth0_graphql_timecard_form_types_test_id" {
  description = "Datadog test ID for GraphQL: formTypes."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_types_dev.id
}

output "auth0_graphql_timecard_form_pdf_config_test_id" {
  description = "Datadog test ID for GraphQL: formPDFConfig."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_pdf_config_dev.id
}

output "auth0_graphql_timecard_form_submissions_test_id" {
  description = "Datadog test ID for GraphQL: formSubmissions."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_submissions_dev.id
}

output "auth0_graphql_timecard_form_submissions_for_invoice_test_id" {
  description = "Datadog test ID for GraphQL: formSubmissionsForInvoice."
  value       = datadog_synthetics_test.auth0_graphql_timecard_form_submissions_for_invoice_dev.id
}
