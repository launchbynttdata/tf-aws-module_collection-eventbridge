# Default event bus + generated target role — trust policy SourceArn must use rule/<RuleName> (no rule/default/).
bus = {
  create            = false
  existing_bus_name = "default"
}

rules = [
  {
    name               = "review_plan_default_bus_rule"
    event_pattern_json = "{\"source\":[\"review-plan\"]}"
    targets = [{
      name        = "t1"
      arn         = "arn:aws:sqs:REGION_PLACEHOLDER:123456789012:review-plan-fake-queue"
      type        = "sqs"
      create_role = true
    }]
  }
]
