# Verifies that name_override takes precedence over the Launch naming prefix
# for both pipes and schedules. Uses create_role = false + dummy ARNs so no
# AWS credentials are needed (plan-only test).

tags = {
  Environment = "test"
  Owner       = "terratest"
}

bus = {
  create            = false
  existing_bus_name = "default"
}

pipes = [
  {
    name          = "logical-pipe-name"
    name_override = "my-exact-aws-pipe-name"
    source_arn    = "arn:aws:sqs:REGION_PLACEHOLDER:123456789012:dummy-source-queue"
    target_arn    = "arn:aws:states:REGION_PLACEHOLDER:123456789012:stateMachine:dummy-target"
    create_role   = false
    role_arn      = "arn:aws:iam::123456789012:role/dummy-pipe-role"
  }
]

schedules = [
  {
    name                = "logical-schedule-name"
    name_override       = "my-exact-aws-schedule-name"
    schedule_expression = "rate(1 hour)"
    target_arn          = "arn:aws:lambda:REGION_PLACEHOLDER:123456789012:function:dummy-fn"
    create_role         = false
    role_arn            = "arn:aws:iam::123456789012:role/dummy-sched-role"
  }
]
