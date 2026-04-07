// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

module "resource_names" {
  source  = "terraform.registry.launch.nttdata.com/module_library/resource_name/launch"
  version = "~> 2.0"

  for_each = var.resource_names_map

  logical_product_family  = var.logical_product_family
  logical_product_service = var.logical_product_service
  class_env               = var.class_env
  instance_env            = var.instance_env
  instance_resource       = var.instance_resource
  cloud_resource_type     = each.value.name
  maximum_length          = each.value.max_length
  region                  = join("", split("-", data.aws_region.current.name))
}

module "event_bus" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_bus/aws"
  version = "~> 0.0"
  count   = var.bus.create ? 1 : 0

  name = local.generated_bus_name
  tags = local.merged_tags
}

module "event_bus_policy" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_bus_policy/aws"
  version  = "~> 0.0"
  for_each = length(coalesce(var.bus.policies, [])) > 0 ? { for p in var.bus.policies : sha256(p) => p } : {}

  event_bus_name = local.effective_event_bus_name
  policy         = each.value
}

module "event_archive" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_archive/aws"
  version  = "~> 0.0"
  for_each = local.archives_by_name

  name             = local.event_archive_full_names[each.key]
  event_source_arn = local.effective_event_bus_arn
  event_pattern    = try(each.value.event_pattern_json, null)
  retention_days   = try(each.value.retention_days, null)
  # kms_key_arn: not supported by cloudwatch_event_archive primitive 0.1.0; use a future primitive version or a bare aws_cloudwatch_event_archive with TODO when CMEK is required.
}

module "event_connection" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_connection/aws"
  version  = "~> 1.0"
  for_each = local.api_connections_by_name

  name               = local.event_connection_full_names[each.key]
  authorization_type = local.api_connection_authorization_type[each.key]
  auth_parameters    = local.api_connection_auth_parameters[each.key]
  description        = ""
  kms_key_identifier = ""
}

module "event_api_destination" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_api_destination/aws"
  version  = "~> 0.0"
  for_each = local.api_destinations_by_key

  name                             = local.event_api_destination_full_names[each.key]
  connection_arn                   = module.event_connection[each.value.connection_name].arn
  invocation_endpoint              = each.value.invocation_endpoint
  http_method                      = each.value.http_method
  description                      = null
  invocation_rate_limit_per_second = coalesce(try(each.value.rate_limit_per_second, null), 300)
}

module "event_rule" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_rule/aws"
  version  = "~> 0.0"
  for_each = local.rules_by_name

  name           = local.event_rule_full_names[each.key]
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

module "iam_role_event_target" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws"
  version  = "~> 0.0"
  for_each = local.event_targets_needing_role

  name_prefix = "${substr(replace(each.key, ":", "-"), 0, 32)}-evt-"
  tags        = local.merged_tags

  assume_role_policy = [{
    actions = ["sts:AssumeRole"]
    principals = [{
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }]
    conditions = [
      {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      },
      {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [local.eventbridge_rule_arn_for_event_target_trust[each.key]]
      }
    ]
  }]
}

module "iam_policy_event_target" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_policy/aws"
  version  = "~> 0.0"
  for_each = local.event_targets_needing_role

  policy_name      = substr("${replace(each.key, ":", "-")}-evt-${local.iam_inline_policy_token}", 0, 128)
  policy_statement = local.event_target_policy_statements[each.key]
  tags             = local.merged_tags
}

module "iam_role_policy_attachment_event_target" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws"
  version  = "~> 0.0"
  for_each = local.event_targets_needing_role

  role_name  = module.iam_role_event_target[each.key].role_name
  policy_arn = module.iam_policy_event_target[each.key].policy_arn
}

module "iam_role_scheduler" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws"
  version  = "~> 0.0"
  for_each = local.schedules_needing_role

  name_prefix = "${substr(replace(each.key, ":", "-"), 0, 32)}-sch-"
  tags        = local.merged_tags

  # SourceAccount only: CreateSchedule validates assume-role before the schedule exists; a strict
  # schedule-level aws:SourceArn match often fails that check. See AWS Scheduler execution role docs.
  assume_role_policy = [{
    actions = ["sts:AssumeRole"]
    principals = [{
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }]
    conditions = [
      {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      },
    ]
  }]
}

module "iam_policy_scheduler" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_policy/aws"
  version  = "~> 0.0"
  for_each = local.schedules_needing_role

  policy_name      = substr("${replace(each.key, ":", "-")}-sched-${local.iam_inline_policy_token}", 0, 128)
  policy_statement = local.scheduler_policy_statements[each.key]
  tags             = local.merged_tags
}

module "iam_role_policy_attachment_scheduler" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws"
  version  = "~> 0.0"
  for_each = local.schedules_needing_role

  role_name  = module.iam_role_scheduler[each.key].role_name
  policy_arn = module.iam_policy_scheduler[each.key].policy_arn
}

module "iam_role_pipe" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws"
  version  = "~> 0.0"
  for_each = local.pipes_needing_role

  name_prefix = "${substr(replace(each.key, ":", "-"), 0, 32)}-pipe-"
  tags        = local.merged_tags

  assume_role_policy = [{
    actions = ["sts:AssumeRole"]
    principals = [{
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }]
    conditions = [
      {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      },
      {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = ["arn:aws:pipes:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:pipe/${local.pipes_pipe_full_names[each.key]}"]
      }
    ]
  }]
}

module "iam_policy_pipe" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_policy/aws"
  version  = "~> 0.0"
  for_each = local.pipes_needing_role

  policy_name      = substr("${replace(each.key, ":", "-")}-pipe-${local.iam_inline_policy_token}", 0, 128)
  policy_statement = local.pipe_policy_statements[each.key]
  tags             = local.merged_tags
}

module "iam_role_policy_attachment_pipe" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws"
  version  = "~> 0.0"
  for_each = local.pipes_needing_role

  role_name  = module.iam_role_pipe[each.key].role_name
  policy_arn = module.iam_policy_pipe[each.key].policy_arn
}

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

  schedule_target = merge(
    {
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
    },
    try(each.value.ecs_parameters, null) != null ? { ecs_parameters = each.value.ecs_parameters } : {},
  )

  depends_on = [module.scheduler_schedule_group]
}

module "pipes_pipe" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/pipes_pipe/aws"
  version  = "~> 0.0"
  for_each = local.pipes_by_name

  name = local.pipes_pipe_full_names[each.key]

  role_arn = try(coalesce(
    try(each.value.role_arn, null),
    try(local.pipe_role_arns[each.key], null),
  ), null)

  source_arn = each.value.source_arn
  target_arn = each.value.target_arn

  source_parameters = (
    try(each.value.source_parameters, null) == null && try(each.value.filter_criteria, null) == null
    ) ? null : merge(
    try(each.value.source_parameters, {}),
    try(each.value.filter_criteria, null) != null ? { filter_criteria = each.value.filter_criteria } : {},
  )

  target_parameters     = try(each.value.target_parameters, null)
  enrichment            = try(each.value.enrichment_arn, null)
  enrichment_parameters = try(each.value.enrichment_parameters, null)
  tags                  = local.merged_tags
}
