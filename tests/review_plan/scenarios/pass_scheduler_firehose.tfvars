# Scheduler with Firehose target and generated role — IAM must include firehose:PutRecord*.
schedules = [
  {
    name                = "sched_to_firehose"
    schedule_expression = "rate(24 hours)"
    target_arn          = "arn:aws:firehose:REGION_PLACEHOLDER:123456789012:deliverystream/review-plan-fake-stream"
    create_role         = true
  }
]
