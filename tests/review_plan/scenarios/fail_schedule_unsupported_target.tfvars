# Unsupported Scheduler target ARN when create_role is true.
schedules = [
  {
    name                = "bad_target"
    schedule_expression = "rate(24 hours)"
    target_arn          = "arn:aws:rds:REGION_PLACEHOLDER:123456789012:db:review-plan-fake"
    create_role         = true
  }
]
