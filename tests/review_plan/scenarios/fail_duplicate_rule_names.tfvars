# Two rules with the same logical name — variable validation must reject.
rules = [
  {
    name               = "dup"
    event_pattern_json = "{\"source\":[\"review-plan\"]}"
    targets = [{
      name        = "t1"
      arn         = "arn:aws:sns:REGION_PLACEHOLDER:123456789012:review-plan-fake-sns"
      type        = "sns"
      create_role = false
    }]
  },
  {
    name               = "dup"
    event_pattern_json = "{\"source\":[\"review-plan-other\"]}"
    targets = [{
      name        = "t2"
      arn         = "arn:aws:sns:REGION_PLACEHOLDER:123456789012:review-plan-fake-sns"
      type        = "sns"
      create_role = false
    }]
  }
]
