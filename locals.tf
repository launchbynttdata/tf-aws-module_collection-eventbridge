// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

locals {
  merged_tags = var.tags

  # Echoed in outputs for composition and policy tooling; validation lives on var.required_tag_keys.
  required_tag_keys_resolved = var.required_tag_keys

  bus_name_from_arn = (
    try(var.bus.existing_bus_arn, null) != null && var.bus.existing_bus_arn != "" ?
    regex("^arn:aws:events:[^:]+:[^:]+:event-bus/(.+)$", var.bus.existing_bus_arn)[0] :
    null
  )

  existing_bus_lookup_name = var.bus.create ? null : try(coalesce(
    try(var.bus.existing_bus_name, null) != "" ? var.bus.existing_bus_name : null,
    local.bus_name_from_arn
  ), null)

  generated_bus_name = coalesce(
    try(var.bus.name, null),
    module.resource_names["event_bus"].standard
  )

  effective_event_bus_name = var.bus.create ? module.event_bus[0].name : data.aws_cloudwatch_event_bus.existing[0].name
  effective_event_bus_arn  = var.bus.create ? module.event_bus[0].arn : data.aws_cloudwatch_event_bus.existing[0].arn

  rules_by_name = { for r in var.rules : r.name => r }

  event_rule_full_names = {
    for k, _ in local.rules_by_name : k => (
      length("${module.resource_names["event_rule"].standard}-${k}") <= 64 ?
      "${module.resource_names["event_rule"].standard}-${k}" :
      (
        64 - length(k) - 1 >= 1 ?
        "${substr(module.resource_names["event_rule"].standard, 0, 64 - length(k) - 1)}-${k}" :
        substr(sha256("${module.resource_names["event_rule"].standard}-${k}"), 0, 64)
      )
    )
  }

  rule_target_entries = flatten([
    for rule_name, rule in local.rules_by_name : [
      for target in rule.targets : {
        key       = "${rule_name}:${target.name}"
        rule_name = rule_name
        rule      = rule
        target    = target
      }
    ]
  ])

  targets_by_key = {
    for e in local.rule_target_entries : e.key => e
  }

  archives_by_name = { for a in var.archives : a.name => a }

  schedules_by_name = { for s in var.schedules : s.name => s }

  pipes_by_name = { for p in var.pipes : p.name => p }

  # var.pipes is any with heterogeneous shapes; use try() — tomap(v) fails when nested attribute types differ across pipes.
  pipe_name_override_by_key      = { for k, v in local.pipes_by_name : k => try(v.name_override, null) }
  pipe_enrichment_arn_by_key     = { for k, v in local.pipes_by_name : k => try(v.enrichment_arn, null) }
  pipe_source_kms_key_arn_by_key = { for k, v in local.pipes_by_name : k => try(v.source_kms_key_arn, null) }

  api_destinations_by_key = {
    for i, a in var.api_destinations : "${a.connection_name}:${a.destination_name}" => merge(a, { _index = i })
  }

  # One EventBridge connection per connection_name; destinations may share it.
  api_connections_by_name = {
    for name in toset([for a in var.api_destinations : a.connection_name]) : name => [
      for a in var.api_destinations : a if a.connection_name == name
    ][0]
  }

  # Normalize caller `auth_parameters` (any) to the cloudwatch_event_connection primitive object shape.
  api_connection_auth_parameters = {
    for k, v in local.api_connections_by_name : k => (
      try(v.auth_parameters.oauth, null) != null ? {
        api_key = null
        basic   = null
        oauth = {
          authorization_endpoint = v.auth_parameters.oauth.authorization_endpoint
          http_method            = v.auth_parameters.oauth.http_method
          client_parameters      = try(v.auth_parameters.oauth.client_parameters, null)
          oauth_http_parameters = {
            body         = try(v.auth_parameters.oauth.oauth_http_parameters.body, [])
            header       = try(v.auth_parameters.oauth.oauth_http_parameters.header, [])
            query_string = try(v.auth_parameters.oauth.oauth_http_parameters.query_string, [])
          }
        }
        invocation_http_parameters = try(v.auth_parameters.invocation_http_parameters, null)
        } : try(v.auth_parameters.basic, null) != null ? {
        api_key                    = null
        basic                      = v.auth_parameters.basic
        oauth                      = null
        invocation_http_parameters = try(v.auth_parameters.invocation_http_parameters, null)
        } : {
        api_key                    = try(v.auth_parameters.api_key, null)
        basic                      = null
        oauth                      = null
        invocation_http_parameters = try(v.auth_parameters.invocation_http_parameters, null)
      }
    )
  }

  api_connection_authorization_type = {
    for k, v in local.api_connections_by_name : k => (
      contains(["OAUTH", "OAUTH_CLIENT_CREDENTIALS"], upper(v.authorization_type)) ? "OAUTH_CLIENT_CREDENTIALS" : upper(v.authorization_type)
    )
  }

  # "${resource_names.standard}-${suffix}" can exceed AWS limits when the naming prefix grows (e.g. longer
  # logical_product_service). Truncate the prefix; keep "-${suffix}" unless the suffix alone is too long.
  event_archive_full_names = {
    for k, _ in local.archives_by_name : k => (
      length("${module.resource_names["event_archive"].standard}-${k}") <= 48 ?
      "${module.resource_names["event_archive"].standard}-${k}" :
      (
        48 - length(k) - 1 >= 1 ?
        "${substr(module.resource_names["event_archive"].standard, 0, 48 - length(k) - 1)}-${k}" :
        substr(sha256("${module.resource_names["event_archive"].standard}-${k}"), 0, 48)
      )
    )
  }

  event_connection_full_names = {
    for k, _ in local.api_connections_by_name : k => (
      length("${module.resource_names["event_connection"].standard}-${k}") <= 64 ?
      "${module.resource_names["event_connection"].standard}-${k}" :
      (
        64 - length(k) - 1 >= 1 ?
        "${substr(module.resource_names["event_connection"].standard, 0, 64 - length(k) - 1)}-${k}" :
        substr(sha256("${module.resource_names["event_connection"].standard}-${k}"), 0, 64)
      )
    )
  }

  api_destination_name_slugs = {
    for k, a in local.api_destinations_by_key : k => "${a.connection_name}-${a.destination_name}"
  }

  # Include connection_name so two entries with the same destination_name under different connections get distinct AWS names.
  event_api_destination_full_names = {
    for k, a in local.api_destinations_by_key : k => (
      length("${module.resource_names["api_destination"].standard}-${local.api_destination_name_slugs[k]}") <= 64 ?
      "${module.resource_names["api_destination"].standard}-${local.api_destination_name_slugs[k]}" :
      (
        64 - length(local.api_destination_name_slugs[k]) - 1 >= 1 ?
        "${substr(module.resource_names["api_destination"].standard, 0, 64 - length(local.api_destination_name_slugs[k]) - 1)}-${local.api_destination_name_slugs[k]}" :
        substr(sha256("${module.resource_names["api_destination"].standard}-${k}"), 0, 64)
      )
    )
  }

  pipes_pipe_full_names = {
    for k, v in local.pipes_by_name : k => (
      local.pipe_name_override_by_key[k] != null && local.pipe_name_override_by_key[k] != "" ? local.pipe_name_override_by_key[k] : (
        length("${module.resource_names["pipe"].standard}-${k}") <= 64 ?
        "${module.resource_names["pipe"].standard}-${k}" :
        (
          64 - length(k) - 1 >= 1 ?
          "${substr(module.resource_names["pipe"].standard, 0, 64 - length(k) - 1)}-${k}" :
          substr(sha256("${module.resource_names["pipe"].standard}-${k}"), 0, 64)
        )
      )
    )
  }

  scheduler_schedule_full_names = {
    for k, v in local.schedules_by_name : k => (
      try(v.name_override, null) != null && v.name_override != "" ? v.name_override : (
        length("${module.resource_names["schedule"].standard}-${k}") <= 64 ?
        "${module.resource_names["schedule"].standard}-${k}" :
        (
          64 - length(k) - 1 >= 1 ?
          "${substr(module.resource_names["schedule"].standard, 0, 64 - length(k) - 1)}-${k}" :
          substr(sha256("${module.resource_names["schedule"].standard}-${k}"), 0, 64)
        )
      )
    )
  }

  # IAM uses module_primitive iam_role, iam_policy, and iam_role_policy_attachment.
  # No statement uses Resource = "*" in this module. If a future change requires a wildcard,
  # document it beside the statement and in README.md with an AWS docs link.
  event_targets_needing_role = {
    for k, v in local.targets_by_key : k => v
    if coalesce(v.target.create_role, false)
  }

  # Default event bus rule ARNs use arn:aws:events:region:account:rule/<RuleName> (no "default/" segment).
  # Custom buses use arn:aws:events:region:account:rule/<EventBusName>/<RuleName>.
  eventbridge_rule_arn_for_event_target_trust = {
    for k, v in local.event_targets_needing_role : k => (
      local.effective_event_bus_name == "default" ?
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${local.event_rule_full_names[v.rule_name]}" :
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${local.effective_event_bus_name}/${local.event_rule_full_names[v.rule_name]}"
    )
  }

  schedules_needing_role = {
    for k, v in local.schedules_by_name : k => v
    if coalesce(v.create_role, false)
  }

  pipes_needing_role = {
    for k, v in local.pipes_by_name : k => v
    if coalesce(v.create_role, false)
  }

  # Managed CloudWatch log group for pipe execution logs (optional per pipe).
  pipes_with_managed_execution_logging = {
    for k, v in local.pipes_by_name : k => {
      pipe           = v
      log_group_name = trimspace(try(v.managed_execution_logging.name_override, "")) != "" ? trimspace(v.managed_execution_logging.name_override) : "/aws/vendedlogs/pipes/${local.pipes_pipe_full_names[k]}"
    }
    if try(v.managed_execution_logging, null) != null
  }

  pipe_execution_logs_kms_key_arn = {
    for k, v in local.pipes_by_name : k =>
    try(coalesce(nullif(try(v.execution_logs_kms_key_arn, ""), ""), nullif(try(v.managed_execution_logging.kms_key_id, ""), "")), null)
  }

  pipe_effective_log_configuration = {
    for k, v in local.pipes_by_name : k => (
      try(v.managed_execution_logging, null) != null ? {
        level                           = coalesce(try(v.managed_execution_logging.level, null), try(v.log_configuration.level, null), "INFO")
        include_execution_data          = try(coalesce(try(v.managed_execution_logging.include_execution_data, null), try(v.log_configuration.include_execution_data, null)), null)
        cloudwatch_logs_log_destination = { log_group_arn = module.pipe_execution_log_group[k].log_group_arn }
        firehose_log_destination        = try(v.log_configuration.firehose_log_destination, null)
        s3_log_destination              = try(v.log_configuration.s3_log_destination, null)
      } : try(v.log_configuration, null)
    )
  }

  pipe_log_active = {
    for k, v in local.pipes_by_name : k =>
    local.pipe_effective_log_configuration[k] != null && try(local.pipe_effective_log_configuration[k].level, "OFF") != "OFF"
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
      local.pipe_enrichment_arn_by_key[k] == null || local.pipe_enrichment_arn_by_key[k] == "" ? [] : (
        startswith(local.pipe_enrichment_arn_by_key[k], "arn:aws:lambda:") ? ["lambda:InvokeFunction"] : []
      ),
      local.pipe_enrichment_arn_by_key[k] == null || local.pipe_enrichment_arn_by_key[k] == "" ? [] : (
        startswith(local.pipe_enrichment_arn_by_key[k], "arn:aws:execute-api:") ? ["execute-api:Invoke"] : []
      ),
      local.pipe_enrichment_arn_by_key[k] == null || local.pipe_enrichment_arn_by_key[k] == "" ? [] : (
        can(regex("^arn:aws:events:[^:]+:[^:]+:api-destination/", local.pipe_enrichment_arn_by_key[k])) ? ["events:InvokeApiDestination"] : []
      ),
      local.pipe_enrichment_arn_by_key[k] == null || local.pipe_enrichment_arn_by_key[k] == "" ? [] : (
        startswith(local.pipe_enrichment_arn_by_key[k], "arn:aws:states:") ? ["states:StartSyncExecution", "states:StartExecution"] : []
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
      local.pipe_enrichment_arn_by_key[k] != null && local.pipe_enrichment_arn_by_key[k] != "" && length(local.pipe_enrichment_actions[k]) > 0 ? {
        PipeInvokeEnrichment = {
          sid       = "PipeInvokeEnrichment"
          actions   = local.pipe_enrichment_actions[k]
          resources = [local.pipe_enrichment_arn_by_key[k]]
        }
      } : {},
      local.pipe_source_kms_key_arn_by_key[k] != null && local.pipe_source_kms_key_arn_by_key[k] != "" ? {
        PipeKmsDecryptSource = {
          sid       = "PipeKmsDecryptSource"
          actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
          resources = [local.pipe_source_kms_key_arn_by_key[k]]
        }
      } : {},
      local.pipe_log_active[k] && try(local.pipe_effective_log_configuration[k].cloudwatch_logs_log_destination.log_group_arn, null) != null ? {
        PipeCloudWatchLogs = {
          sid       = "PipeCloudWatchLogs"
          actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          resources = ["${local.pipe_effective_log_configuration[k].cloudwatch_logs_log_destination.log_group_arn}:*"]
        }
      } : {},
      local.pipe_log_active[k] && try(local.pipe_effective_log_configuration[k].firehose_log_destination.delivery_stream_arn, null) != null ? {
        PipeFirehoseLogs = {
          sid       = "PipeFirehoseLogs"
          actions   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
          resources = [local.pipe_effective_log_configuration[k].firehose_log_destination.delivery_stream_arn]
        }
      } : {},
      local.pipe_log_active[k] && try(local.pipe_effective_log_configuration[k].s3_log_destination.bucket_name, null) != null ? {
        PipeS3Logs = {
          sid       = "PipeS3Logs"
          actions   = ["s3:PutObject"]
          resources = ["arn:aws:s3:::${local.pipe_effective_log_configuration[k].s3_log_destination.bucket_name}/*"]
        }
      } : {},
      local.pipe_log_active[k] && local.pipe_execution_logs_kms_key_arn[k] != null ? {
        PipeKmsExecutionLogs = {
          sid       = "PipeKmsExecutionLogs"
          actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
          resources = [local.pipe_execution_logs_kms_key_arn[k]]
        }
      } : {},
    )
  }

  event_target_role_arns = { for k, m in module.iam_role_event_target : k => m.role_arn }
  scheduler_role_arns    = { for k, m in module.iam_role_scheduler : k => m.role_arn }
  pipe_role_arns         = { for k, m in module.iam_role_pipe : k => m.role_arn }
}
