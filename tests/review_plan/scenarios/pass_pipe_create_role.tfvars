# Pipe with create_role = true and no role_arn — expect plan to succeed (IAM role generated).
pipes = [
  {
    name        = "pipe_with_generated_role"
    source_arn  = "arn:aws:sqs:REGION_PLACEHOLDER:123456789012:review-plan-fake-sqs"
    target_arn  = "arn:aws:sns:REGION_PLACEHOLDER:123456789012:review-plan-fake-sns"
    create_role = true
  }
]
