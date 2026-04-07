# create_role false and empty role_arn — expect variable validation error at plan time.
pipes = [
  {
    name        = "pipe_missing_role"
    source_arn  = "arn:aws:sqs:REGION_PLACEHOLDER:123456789012:review-plan-fake-sqs"
    target_arn  = "arn:aws:sns:REGION_PLACEHOLDER:123456789012:review-plan-fake-sns"
    create_role = false
  }
]
