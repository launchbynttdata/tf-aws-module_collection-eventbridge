# Custom event bus + generated target role — trust policy SourceArn must use rule/<BusName>/<RuleName>.
bus = {
  create   = true
  policies = []
}

rules = [
  {
    name               = "review_plan_custom_bus_rule"
    event_pattern_json = "{\"source\":[\"review-plan\"]}"
    targets = [{
      name        = "t1"
      arn         = "arn:aws:sqs:REGION_PLACEHOLDER:123456789012:review-plan-fake-queue"
      type        = "sqs"
      create_role = true
    }]
  }
]
