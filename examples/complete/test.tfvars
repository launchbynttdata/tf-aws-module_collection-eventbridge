# Terratest / shared-account runs: random_id.example_isolation (see main.tf) suffixes logical_product_service
# for the collection module and SNS/SQS names so EventBridge resources do not collide across states or partial teardowns.
#
# AWS region comes from the provider supplied by the test fixture (AWS_REGION / profile). post_deploy_functional
# sets AWS_REGION/AWS_DEFAULT_REGION on the Terraform subprocess to match the SDK default chain.
#
# rules, archives, schedules, pipes: omit or use [] so main.tf coalescelist() keeps the built-in integration
# lists (multiple rules, schedules including a custom schedule group, SQS pipe with filter, archive with pattern).
# api_destinations is set here so HCL object typing matches the module variable (auth_parameters as object).
tags = {
  Environment = "test"
  Owner       = "terratest"
}

required_tag_keys = ["Environment", "Owner"]

sns_topic_name = "eb-collection-complete-test"

bus = {
  create   = true
  policies = []
}

api_destinations = [
  {
    connection_name    = "httpbin"
    authorization_type = "API_KEY"
    auth_parameters = {
      api_key = {
        key   = "X-Example-Key"
        value = "example-not-secret"
      }
    }
    destination_name    = "httpbin_post"
    invocation_endpoint = "https://httpbin.org/post"
    http_method         = "POST"
  }
]
