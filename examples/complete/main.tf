// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "example_isolation" {
  byte_length = 4
}

module "sns_topic" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/sns_topic/aws"
  version = "~> 0.0"

  name = "${var.sns_topic_name}-${random_id.example_isolation.hex}"
  tags = var.tags
}

data "aws_iam_policy_document" "sns_publish" {
  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [module.sns_topic.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowSchedulerPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [module.sns_topic.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowPipesPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [module.sns_topic.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

module "sns_topic_policy" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/sns_topic_policy/aws"
  version = "~> 1.0"

  arn    = module.sns_topic.arn
  policy = data.aws_iam_policy_document.sns_publish.json
}

# SQS sink for Terratest end-to-end validation: EventBridge rules -> SNS -> this queue (not used by the pipe).
# Uses the same CMK as pipe_source (below) so Regula FG_R00070 (SQS KMS) is satisfied without a second key.
resource "aws_sqs_queue" "e2e_sink" {
  name_prefix                       = "eb-e2e-sink-${random_id.example_isolation.hex}-"
  kms_master_key_id                 = aws_kms_key.pipe_source_sqs.arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = var.tags
}

data "aws_iam_policy_document" "e2e_sink_sns" {
  statement {
    sid    = "AllowSnsPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.e2e_sink.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.sns_topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "e2e_sink" {
  queue_url = aws_sqs_queue.e2e_sink.id
  policy    = data.aws_iam_policy_document.e2e_sink_sns.json
}

resource "aws_sns_topic_subscription" "e2e_sink" {
  topic_arn = module.sns_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.e2e_sink.arn

  depends_on = [aws_sqs_queue_policy.e2e_sink]
}

resource "aws_kms_key" "pipe_source_sqs" {
  description             = "KMS key for SQS queues in complete example (pipe source, e2e sink, SNS subscription)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountRoot"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSqsService"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowSnsService"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowPipesService"
        Effect = "Allow"
        Principal = {
          Service = "pipes.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
    ]
  })
}

# TODO: Replace with module_primitive/sqs_queue/aws when available.
resource "aws_sqs_queue" "pipe_source" {
  name_prefix                       = "${var.sqs_queue_name_prefix}-${random_id.example_isolation.hex}-"
  kms_master_key_id                 = aws_kms_key.pipe_source_sqs.arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = var.tags
}

data "aws_iam_policy_document" "sqs_pipe_source" {
  statement {
    sid    = "AllowPipesConsume"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.pipe_source.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "pipe_source" {
  queue_url = aws_sqs_queue.pipe_source.id
  policy    = data.aws_iam_policy_document.sqs_pipe_source.json
}

locals {
  example_event_source = "collection.example"
  example_detail_type  = "example.Detail"

  example_schedule_custom_group_name = "ebce-${random_id.example_isolation.hex}"
  example_schedule_groups = {
    example_ebce = { name = local.example_schedule_custom_group_name }
  }

  example_rules = [
    {
      name               = "integration"
      description        = "Example rule for Terratest (PutEvents → SNS)"
      state              = "ENABLED"
      event_pattern_json = jsonencode({ source = [local.example_event_source], "detail-type" = [local.example_detail_type] })
      targets = [{
        name        = "sns"
        arn         = module.sns_topic.arn
        type        = "sns"
        create_role = false
      }]
    },
    {
      name               = "audit"
      description        = "Second rule on the same bus (additional event_target path)"
      state              = "ENABLED"
      event_pattern_json = jsonencode({ source = [local.example_event_source] })
      targets = [{
        name        = "sns"
        arn         = module.sns_topic.arn
        type        = "sns"
        create_role = false
      }]
    },
  ]

  example_archives = [{
    name               = "main"
    retention_days     = 1
    event_pattern_json = jsonencode({ source = [local.example_event_source] })
  }]

  example_schedules = [
    {
      name                = "minute"
      schedule_expression = "rate(5 minutes)"
      target_arn          = module.sns_topic.arn
      create_role         = true
    },
    {
      name                = "daily"
      group_name          = local.example_schedule_custom_group_name
      schedule_expression = "cron(0 14 * * ? *)"
      target_arn          = module.sns_topic.arn
      create_role         = true
    },
  ]

  example_pipes = [{
    name               = "sqs_to_sns"
    source_arn         = aws_sqs_queue.pipe_source.arn
    target_arn         = module.sns_topic.arn
    create_role        = true
    source_kms_key_arn = aws_kms_key.pipe_source_sqs.arn
    # Creates /aws/vendedlogs/pipes/<prefixed pipe name> and enables execution logs on the pipe.
    managed_execution_logging = {
      level             = var.pipe_managed_execution_logging.level
      retention_in_days = var.pipe_managed_execution_logging.retention_in_days
    }
    filter_criteria = {
      filter = [
        { pattern = "{\"pipe\":{\"test\":[\"terratest\"]}}" }
      ]
    }
  }]

  # jsondecode keeps auth_parameters typed as dynamic so this list matches var.api_destinations (auth_parameters = any).
  example_api_destinations = [{
    connection_name       = "httpbin"
    authorization_type    = "API_KEY"
    auth_parameters       = jsondecode("{\"api_key\":{\"key\":\"X-Example-Key\",\"value\":\"example-not-secret\"}}")
    destination_name      = "httpbin_post"
    invocation_endpoint   = "https://httpbin.org/post"
    http_method           = "POST"
    rate_limit_per_second = null
  }]

}

module "eventbridge_collection" {
  source = "../.."

  logical_product_family  = var.logical_product_family
  logical_product_service = "${var.logical_product_service}-${random_id.example_isolation.hex}"
  class_env               = var.class_env
  instance_env            = var.instance_env
  instance_resource       = var.instance_resource
  resource_names_map      = var.resource_names_map
  tags                    = var.tags
  required_tag_keys       = var.required_tag_keys
  bus                     = var.bus
  rules                   = coalescelist(var.rules, local.example_rules)
  archives                = coalescelist(var.archives, local.example_archives)
  schedules               = coalescelist(var.schedules, local.example_schedules)
  schedule_groups         = merge(local.example_schedule_groups, var.schedule_groups)
  pipes                   = coalescelist(var.pipes, local.example_pipes)
  api_destinations        = coalescelist(var.api_destinations, local.example_api_destinations)

  depends_on = [
    module.sns_topic_policy,
    aws_sqs_queue_policy.pipe_source,
  ]
}
