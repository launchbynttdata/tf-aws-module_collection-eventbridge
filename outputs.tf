// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

output "bus_name" {
  description = "Effective event bus name."
  value       = local.effective_event_bus_name
}

output "bus_arn" {
  description = "Effective event bus ARN."
  value       = local.effective_event_bus_arn
}

output "rule_names" {
  description = "Rule names in input order."
  value       = [for r in var.rules : r.name]
}

output "rule_arns" {
  description = "Rule ARNs sorted by rule name for stable ordering."
  value       = [for name in sort(keys(module.event_rule)) : module.event_rule[name].arn]
}

output "archive_names" {
  description = "Archive names sorted by key."
  value       = sort(keys(module.event_archive))
}

output "archive_arns" {
  description = "Archive ARNs sorted by archive key."
  value       = [for name in sort(keys(module.event_archive)) : module.event_archive[name].arn]
}

output "schedule_arns" {
  description = "Schedule ARNs sorted by schedule name."
  value       = [for name in sort(keys(module.scheduler_schedule)) : module.scheduler_schedule[name].arn]
}

output "pipe_arns" {
  description = "Pipe ARNs sorted by pipe name."
  value       = [for name in sort(keys(module.pipes_pipe)) : module.pipes_pipe[name].arn]
}

output "api_destination_arns" {
  description = "API destination ARNs sorted by composite key."
  value       = [for k in sort(keys(module.event_api_destination)) : module.event_api_destination[k].arn]
}

output "connection_arns" {
  description = "Event connection ARNs sorted by connection_name (one connection per distinct name)."
  value       = [for k in sort(keys(module.event_connection)) : module.event_connection[k].arn]
}

output "event_target_iam_role_names" {
  description = "Names of IAM roles created for EventBridge targets (create_role = true), keyed by rule:target."
  value       = { for k, m in module.iam_role_event_target : k => m.role_name }
}

output "scheduler_iam_role_names" {
  description = "Names of IAM roles created for Scheduler targets (create_role = true)."
  value       = { for k, m in module.iam_role_scheduler : k => m.role_name }
}

output "pipe_iam_role_names" {
  description = "Names of IAM roles created for Pipes (create_role = true)."
  value       = { for k, m in module.iam_role_pipe : k => m.role_name }
}
