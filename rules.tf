// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

module "event_rule" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_rule/aws"
  version  = "~> 0.0"
  for_each = local.rules_by_name

  name           = each.value.name
  description    = try(each.value.description, null)
  event_bus_name = local.effective_event_bus_name
  event_pattern  = each.value.event_pattern_json
  state          = coalesce(each.value.state, "ENABLED")
  tags           = local.merged_tags
}

module "event_target" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_target/aws"
  version  = "~> 0.0"
  for_each = local.targets_by_key

  event_bus_name = local.effective_event_bus_name
  rule           = module.event_rule[each.value.rule_name].name
  arn            = each.value.target.arn
  target_id      = each.value.target.name

  role_arn = try(coalesce(
    try(each.value.target.role_arn, null),
    try(local.event_target_role_arns[each.key], null),
  ), null)

  input      = try(each.value.target.input_json, null)
  input_path = try(each.value.target.input_path, null)

  input_transformer = try(each.value.target.input_transformer, null)

  dead_letter_config = (
    try(each.value.target.dlq_arn, null) != null && try(each.value.target.dlq_arn, "") != ""
  ) ? { arn = each.value.target.dlq_arn } : null

  retry_policy = try(each.value.target.retry_policy, null)
}
