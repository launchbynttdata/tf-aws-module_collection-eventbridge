// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

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
