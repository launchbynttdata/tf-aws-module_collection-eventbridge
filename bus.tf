// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

module "event_bus" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_bus/aws"
  version = "~> 0.0"
  count   = var.bus.create ? 1 : 0

  name = local.generated_bus_name
  tags = local.merged_tags
}

data "aws_cloudwatch_event_bus" "existing" {
  count = var.bus.create ? 0 : 1
  name  = local.existing_bus_lookup_name
}

locals {
  effective_event_bus_name = var.bus.create ? module.event_bus[0].name : data.aws_cloudwatch_event_bus.existing[0].name
  effective_event_bus_arn  = var.bus.create ? module.event_bus[0].arn : data.aws_cloudwatch_event_bus.existing[0].arn
}

module "event_bus_policy" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_bus_policy/aws"
  version  = "~> 0.0"
  for_each = length(coalesce(var.bus.policies, [])) > 0 ? { for p in var.bus.policies : sha256(p) => p } : {}

  event_bus_name = local.effective_event_bus_name
  policy         = each.value
}
