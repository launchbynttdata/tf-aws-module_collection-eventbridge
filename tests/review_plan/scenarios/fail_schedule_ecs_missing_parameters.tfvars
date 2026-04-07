# ECS Scheduler targets require ecs_parameters — variable validation must reject when omitted.
schedules = [
  {
    name                = "sched_ecs_no_params"
    schedule_expression = "rate(24 hours)"
    target_arn          = "arn:aws:ecs:REGION_PLACEHOLDER:123456789012:cluster/review-plan-fake"
    create_role         = true
  }
]
