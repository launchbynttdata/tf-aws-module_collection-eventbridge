# Custom schedule group name must match schedules[*].group_name (module variable validation).
schedule_groups = {
  grp = { name = "review-plan-custom-sg" }
}

schedules = [
  {
    name                = "sched_in_custom_group"
    group_name          = "review-plan-custom-sg"
    schedule_expression = "rate(24 hours)"
    target_arn          = "arn:aws:sns:REGION_PLACEHOLDER:123456789012:review-plan-fake-sns"
    create_role         = true
  }
]
