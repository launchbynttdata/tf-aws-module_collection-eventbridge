// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

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
