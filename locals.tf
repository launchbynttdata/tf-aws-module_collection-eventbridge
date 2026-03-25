// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

locals {
  merged_tags = var.tags

  bus_name_from_arn = (
    try(var.bus.existing_bus_arn, null) != null && var.bus.existing_bus_arn != "" ?
    regex("^arn:aws:events:[^:]+:[^:]+:event-bus/(.+)$", var.bus.existing_bus_arn)[0] :
    null
  )

  existing_bus_lookup_name = var.bus.create ? null : coalesce(
    try(var.bus.existing_bus_name, null) != "" ? var.bus.existing_bus_name : null,
    local.bus_name_from_arn
  )

  generated_bus_name = coalesce(
    try(var.bus.name, null),
    module.resource_names["event_bus"].standard
  )

  rule_names    = [for r in var.rules : r.name]
  rule_names_ok = length(local.rule_names) == length(distinct(local.rule_names))

  archive_names    = [for a in var.archives : a.name]
  archive_names_ok = length(local.archive_names) == length(distinct(local.archive_names))

  schedule_names    = [for s in var.schedules : s.name]
  schedule_names_ok = length(local.schedule_names) == length(distinct(local.schedule_names))

  pipe_names    = [for p in var.pipes : p.name]
  pipe_names_ok = length(local.pipe_names) == length(distinct(local.pipe_names))

  rules_by_name = { for r in var.rules : r.name => r }

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

  api_destinations_by_key = {
    for i, a in var.api_destinations : "${a.connection_name}:${a.destination_name}" => merge(a, { _index = i })
  }

  # One EventBridge connection per connection_name; destinations may share it.
  api_connections_by_name = {
    for name in toset([for a in var.api_destinations : a.connection_name]) : name => [
      for a in var.api_destinations : a if a.connection_name == name
    ][0]
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
    for k, _ in local.pipes_by_name : k => (
      length("${module.resource_names["pipe"].standard}-${k}") <= 64 ?
      "${module.resource_names["pipe"].standard}-${k}" :
      (
        64 - length(k) - 1 >= 1 ?
        "${substr(module.resource_names["pipe"].standard, 0, 64 - length(k) - 1)}-${k}" :
        substr(sha256("${module.resource_names["pipe"].standard}-${k}"), 0, 64)
      )
    )
  }

  scheduler_schedule_full_names = {
    for k, _ in local.schedules_by_name : k => (
      length("${module.resource_names["schedule"].standard}-${k}") <= 64 ?
      "${module.resource_names["schedule"].standard}-${k}" :
      (
        64 - length(k) - 1 >= 1 ?
        "${substr(module.resource_names["schedule"].standard, 0, 64 - length(k) - 1)}-${k}" :
        substr(sha256("${module.resource_names["schedule"].standard}-${k}"), 0, 64)
      )
    )
  }

  event_target_role_arns = { for k, m in module.iam_role_event_target : k => m.role_arn }
  scheduler_role_arns    = { for k, m in module.iam_role_scheduler : k => m.role_arn }
  pipe_role_arns         = { for k, m in module.iam_role_pipe : k => m.role_arn }
}
