// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

data "aws_caller_identity" "current" {}

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
}

module "sns_topic_policy" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/sns_topic_policy/aws"
  version = "~> 1.0"

  arn    = module.sns_topic.arn
  policy = data.aws_iam_policy_document.sns_publish.json
}

locals {
  example_event_source = "collection.rules-only"
  example_detail_type  = "rulesOnly.Detail"

  only_rules = [{
    name               = "only"
    description        = "Single rule example without schedules, pipes, or API destinations"
    state              = "ENABLED"
    event_pattern_json = jsonencode({ source = [local.example_event_source], "detail-type" = [local.example_detail_type] })
    targets = [{
      name        = "sns"
      arn         = module.sns_topic.arn
      type        = "sns"
      create_role = false
    }]
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

  rules            = local.only_rules
  archives         = []
  schedules        = []
  schedule_groups  = {}
  pipes            = []
  api_destinations = []

  depends_on = [module.sns_topic_policy]
}
