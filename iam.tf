// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// IAM uses module_primitive iam_role, iam_policy, and iam_role_policy_attachment.
// No statement uses Resource = "*" in this module. If a future change requires a wildcard,
// document it beside the statement and in README.md with an AWS docs link.

locals {
  event_targets_needing_role = {
    for k, v in local.targets_by_key : k => v
    if coalesce(v.target.create_role, false)
  }

  schedules_needing_role = {
    for k, v in local.schedules_by_name : k => v
    if coalesce(v.create_role, false)
  }

  pipes_needing_role = {
    for k, v in local.pipes_by_name : k => v
    if coalesce(v.create_role, false)
  }

  event_target_policy_statements = {
    for k, v in local.event_targets_needing_role : k => merge(
      {
        EventBridgeInvokeTarget = {
          sid = "EventBridgeInvokeTarget"
          actions = compact(concat(
            contains(["sqs"], lower(v.target.type)) ? ["sqs:SendMessage"] : [],
            contains(["lambda"], lower(v.target.type)) ? ["lambda:InvokeFunction"] : [],
            contains(["sns"], lower(v.target.type)) ? ["sns:Publish"] : [],
            contains(["stepfunctions", "sfn"], lower(v.target.type)) ? ["states:StartExecution"] : [],
            contains(["firehose"], lower(v.target.type)) ? ["firehose:PutRecord", "firehose:PutRecordBatch"] : [],
            contains(["events", "eventbus"], lower(v.target.type)) ? ["events:PutEvents"] : [],
            contains(["events_api_destination", "api_destination"], lower(v.target.type)) ? ["events:InvokeApiDestination"] : [],
          ))
          resources = [v.target.arn]
        }
      },
      try(v.target.dlq_arn, null) != null && v.target.dlq_arn != "" ? {
        EventBridgeDeadLetterQueue = {
          sid       = "EventBridgeDeadLetterQueue"
          actions   = ["sqs:SendMessage"]
          resources = [v.target.dlq_arn]
        }
      } : {}
    )
  }

  scheduler_policy_statements = {
    for k, v in local.schedules_needing_role : k => merge(
      {
        SchedulerInvokeTarget = {
          sid = "SchedulerInvokeTarget"
          actions = compact(concat(
            startswith(v.target_arn, "arn:aws:lambda:") ? ["lambda:InvokeFunction"] : [],
            startswith(v.target_arn, "arn:aws:sqs:") ? ["sqs:SendMessage"] : [],
            startswith(v.target_arn, "arn:aws:sns:") ? ["sns:Publish"] : [],
            startswith(v.target_arn, "arn:aws:states:") ? ["states:StartExecution"] : [],
            startswith(v.target_arn, "arn:aws:events:") ? ["events:PutEvents"] : [],
            startswith(v.target_arn, "arn:aws:firehose:") ? ["firehose:PutRecord", "firehose:PutRecordBatch"] : [],
            startswith(v.target_arn, "arn:aws:ecs:") ? ["ecs:RunTask"] : [],
            startswith(v.target_arn, "arn:aws:codebuild:") ? ["codebuild:StartBuild"] : [],
          ))
          resources = [v.target_arn]
        }
      },
      try(v.dead_letter_arn, null) != null && v.dead_letter_arn != "" ? {
        SchedulerDeadLetterQueue = {
          sid       = "SchedulerDeadLetterQueue"
          actions   = ["sqs:SendMessage"]
          resources = [v.dead_letter_arn]
        }
      } : {}
    )
  }

  # Tie inline IAM policy names to the generated event bus name so separate module instances do not collide in one account.
  iam_inline_policy_token = substr(sha256(module.resource_names["event_bus"].standard), 0, 16)

  pipe_enrichment_actions = {
    for k, v in local.pipes_needing_role : k => compact(concat(
      try(v.enrichment_arn, null) == null || try(v.enrichment_arn, null) == "" ? [] : (
        startswith(v.enrichment_arn, "arn:aws:lambda:") ? ["lambda:InvokeFunction"] : []
      ),
      try(v.enrichment_arn, null) == null || try(v.enrichment_arn, null) == "" ? [] : (
        startswith(v.enrichment_arn, "arn:aws:execute-api:") ? ["execute-api:Invoke"] : []
      ),
      try(v.enrichment_arn, null) == null || try(v.enrichment_arn, null) == "" ? [] : (
        can(regex("^arn:aws:events:[^:]+:[^:]+:api-destination/", v.enrichment_arn)) ? ["events:InvokeApiDestination"] : []
      ),
      try(v.enrichment_arn, null) == null || try(v.enrichment_arn, null) == "" ? [] : (
        startswith(v.enrichment_arn, "arn:aws:states:") ? ["states:StartSyncExecution", "states:StartExecution"] : []
      ),
    ))
  }

  pipe_policy_statements = {
    for k, v in local.pipes_needing_role : k => merge(
      {
        PipeReadSource = {
          sid = "PipeReadSource"
          actions = compact(concat(
            startswith(v.source_arn, "arn:aws:sqs:") ? ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"] : [],
            startswith(v.source_arn, "arn:aws:dynamodb:") ? ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"] : [],
            startswith(v.source_arn, "arn:aws:kinesis:") ? ["kinesis:DescribeStream", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:ListShards"] : [],
          ))
          resources = [v.source_arn]
        }
        PipeWriteTarget = {
          sid = "PipeWriteTarget"
          actions = compact(concat(
            startswith(v.target_arn, "arn:aws:sqs:") ? ["sqs:SendMessage"] : [],
            startswith(v.target_arn, "arn:aws:sns:") ? ["sns:Publish"] : [],
            startswith(v.target_arn, "arn:aws:lambda:") ? ["lambda:InvokeFunction"] : [],
            startswith(v.target_arn, "arn:aws:events:") && !can(regex("^arn:aws:events:[^:]+:[^:]+:api-destination/", v.target_arn)) ? ["events:PutEvents"] : [],
            can(regex("^arn:aws:events:[^:]+:[^:]+:api-destination/", v.target_arn)) ? ["events:InvokeApiDestination"] : [],
            startswith(v.target_arn, "arn:aws:states:") ? ["states:StartExecution"] : [],
            startswith(v.target_arn, "arn:aws:firehose:") ? ["firehose:PutRecord", "firehose:PutRecordBatch"] : [],
            startswith(v.target_arn, "arn:aws:execute-api:") ? ["execute-api:Invoke"] : [],
          ))
          resources = [v.target_arn]
        }
      },
      try(v.enrichment_arn, null) != null && v.enrichment_arn != "" && length(local.pipe_enrichment_actions[k]) > 0 ? {
        PipeInvokeEnrichment = {
          sid       = "PipeInvokeEnrichment"
          actions   = local.pipe_enrichment_actions[k]
          resources = [v.enrichment_arn]
        }
      } : {},
      try(v.source_kms_key_arn, null) != null && v.source_kms_key_arn != "" ? {
        PipeKmsDecryptSource = {
          sid       = "PipeKmsDecryptSource"
          actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
          resources = [v.source_kms_key_arn]
        }
      } : {},
    )
  }
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
        values   = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${local.effective_event_bus_name}/${local.event_rule_full_names[regex("^([^:]+):(.+)$", each.key)[0]]}"]
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
