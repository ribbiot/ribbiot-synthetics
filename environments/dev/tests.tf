# ------------------------------------------------------------------------------
# Additional synthetic API tests for dev.
# Copy this block to add a new test; use a unique module name and pass required variables.
# ------------------------------------------------------------------------------

# Example: second test — uncomment and customize to enable.
# module "my_service_health" {
#   source = "../../modules/synthetic-api-test"
#
#   name      = "My Service health (${local.env_name})"
#   status    = "live"
#   message   = "My Service health check failed in ${local.env_name}."
#   locations = local.locations
#   frequency = local.frequency
#   tags      = concat(local.base_tags, ["service:my-service"])
#
#   request_url    = "https://api.example.com/health"
#   request_method = "GET"
#   request_headers = {
#     "Accept" = "application/json"
#   }
#   assertions = [
#     { type = "statusCode", operator = "is", target = "200" }
#   ]
# }
