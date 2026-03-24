# group_name does not exist in schedule_groups — expect variable validation error at plan time.
schedule_groups = {}

schedules = [
  {
    name                = "orphan_group"
    group_name          = "no-such-group-defined"
    schedule_expression = "rate(24 hours)"
    target_arn          = "arn:aws:sns:REGION_PLACEHOLDER:123456789012:review-plan-fake-sns"
    create_role         = true
  }
]
