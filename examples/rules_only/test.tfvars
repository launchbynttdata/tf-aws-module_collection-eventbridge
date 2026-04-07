# Plan/CI: matches the inputs required by variables.tf (see complete example for Terratest-style tags).
tags = {
  Environment = "test"
  Owner       = "terratest"
}

required_tag_keys = ["Environment", "Owner"]

sns_topic_name = "eb-collection-rules-only-test"

bus = {
  create   = true
  policies = []
}
