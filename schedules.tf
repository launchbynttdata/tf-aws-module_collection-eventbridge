// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

module "scheduler_schedule_group" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/scheduler_schedule_group/aws"
  version  = "~> 0.0"
  for_each = var.schedule_groups

  name = each.value.name
  tags = local.merged_tags
}

module "scheduler_schedule" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/scheduler_schedule/aws"
  version  = "~> 0.0"
  for_each = local.schedules_by_name

  name                         = local.scheduler_schedule_full_names[each.key]
  group_name                   = coalesce(each.value.group_name, "default")
  schedule_expression          = each.value.schedule_expression
  schedule_expression_timezone = coalesce(try(each.value.schedule_expression_timezone, null), "UTC")
  start_date                   = try(each.value.start_date, null)
  end_date                     = try(each.value.end_date, null)

  flexible_time_window = try(each.value.flexible_time_window, null) != null ? each.value.flexible_time_window : { mode = "OFF" }

  schedule_target = {
    arn = each.value.target_arn
    role_arn = try(coalesce(
      try(each.value.role_arn, null),
      try(local.scheduler_role_arns[each.key], null),
    ), null)
    input = try(each.value.target_input_json, null)
    dead_letter_config = (
      try(each.value.dead_letter_arn, null) != null && try(each.value.dead_letter_arn, "") != ""
    ) ? { arn = each.value.dead_letter_arn } : null
    retry_policy = try(each.value.retry_policy, null)
  }

  depends_on = [module.scheduler_schedule_group]
}
