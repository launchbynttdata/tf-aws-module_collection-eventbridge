// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

output "bus_name" {
  value = module.eventbridge_collection.bus_name
}

output "bus_arn" {
  value = module.eventbridge_collection.bus_arn
}

output "rule_names" {
  value = module.eventbridge_collection.rule_names
}

output "sns_topic_arn" {
  value = module.sns_topic.arn
}

output "required_tag_keys" {
  description = "Pass-through from the collection module."
  value       = module.eventbridge_collection.required_tag_keys
}
