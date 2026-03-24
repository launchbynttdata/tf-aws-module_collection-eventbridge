// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

output "aws_region" {
  description = "Region where this example is deployed (Terratest uses this to configure the AWS SDK)."
  value       = data.aws_region.current.name
}

output "bus_name" {
  value = module.eventbridge_collection.bus_name
}

output "bus_arn" {
  value = module.eventbridge_collection.bus_arn
}

output "rule_names" {
  value = module.eventbridge_collection.rule_names
}

output "rule_arns" {
  value = module.eventbridge_collection.rule_arns
}

output "sns_topic_arn" {
  value = module.sns_topic.arn
}

output "sqs_pipe_source_queue_url" {
  value = aws_sqs_queue.pipe_source.url
}

output "e2e_sink_queue_url" {
  value       = aws_sqs_queue.e2e_sink.url
  description = "SQS URL subscribed to the example SNS topic for PutEvents end-to-end tests."
}

output "integration_event_source" {
  value = "collection.example"
}

output "integration_detail_type" {
  value = "example.Detail"
}

output "scheduler_iam_role_names" {
  value = module.eventbridge_collection.scheduler_iam_role_names
}

output "pipe_iam_role_names" {
  value = module.eventbridge_collection.pipe_iam_role_names
}

output "archive_arns" {
  value = module.eventbridge_collection.archive_arns
}

output "schedule_arns" {
  value = module.eventbridge_collection.schedule_arns
}

output "pipe_arns" {
  value = module.eventbridge_collection.pipe_arns
}

output "api_destination_arns" {
  value = module.eventbridge_collection.api_destination_arns
}

output "connection_arns" {
  value = module.eventbridge_collection.connection_arns
}
