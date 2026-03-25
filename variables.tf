// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

variable "logical_product_family" {
  description = "Product family name used by the resource naming module."
  type        = string
  default     = "launch"
}

variable "logical_product_service" {
  description = "Product service name used by the resource naming module."
  type        = string
  default     = "eventbridge"
}

variable "class_env" {
  description = "Environment class (e.g. dev, qa, prod) for resource naming."
  type        = string
  default     = "dev"
}

variable "instance_env" {
  description = "Numeric instance of the environment for resource naming."
  type        = number
  default     = 0
}

variable "instance_resource" {
  description = "Numeric instance of the resource for resource naming."
  type        = number
  default     = 0
}

variable "resource_names_map" {
  description = "Map consumed by the resource naming module (for_each key -> { name, max_length })."
  type = map(object({
    name       = string
    max_length = optional(number, 60)
  }))
  default = {
    event_bus = {
      name       = "ebus"
      max_length = 256
    }
    event_rule = {
      name       = "rule"
      max_length = 64
    }
    event_archive = {
      name       = "arc"
      max_length = 48
    }
    schedule = {
      name       = "sched"
      max_length = 64
    }
    schedule_group = {
      name       = "sgrp"
      max_length = 64
    }
    pipe = {
      name       = "pipe"
      max_length = 64
    }
    event_connection = {
      name       = "conn"
      max_length = 64
    }
    api_destination = {
      name       = "apid"
      max_length = 64
    }
  }
}

variable "tags" {
  description = "Required organizational tags applied to all taggable resources."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.tags) > 0
    error_message = "tags must be a non-empty map."
  }
}

variable "required_tag_keys" {
  description = "If non-empty, every key listed here must exist in tags."
  type        = list(string)
  default     = []
}

variable "bus" {
  description = "Event bus configuration: create a custom bus or use an existing bus."
  type = object({
    create            = bool
    name              = optional(string)
    existing_bus_name = optional(string)
    existing_bus_arn  = optional(string)
    policies          = optional(list(string), [])
  })

  validation {
    condition = (
      !var.bus.create || (
        (try(var.bus.existing_bus_name, null) == null || var.bus.existing_bus_name == "") &&
        (try(var.bus.existing_bus_arn, null) == null || var.bus.existing_bus_arn == "")
      )
    )
    error_message = "When bus.create is true, do not set existing_bus_name or existing_bus_arn."
  }

  validation {
    condition = (
      var.bus.create || (
        (try(var.bus.existing_bus_name, null) != null && var.bus.existing_bus_name != "") ||
        (try(var.bus.existing_bus_arn, null) != null && var.bus.existing_bus_arn != "")
      )
    )
    error_message = "When bus.create is false, set existing_bus_name or existing_bus_arn."
  }
}

variable "rules" {
  description = "EventBridge rules and targets on the effective event bus."
  type = list(object({
    name               = string
    description        = optional(string)
    state              = optional(string, "ENABLED")
    event_pattern_json = string
    targets = list(object({
      name                       = string
      arn                        = string
      type                       = string
      role_arn                   = optional(string)
      create_role                = optional(bool, false)
      dlq_arn                    = optional(string)
      retry_policy               = optional(any)
      input_json                 = optional(string)
      input_path                 = optional(string)
      input_transformer          = optional(any)
      service_specific_overrides = optional(any)
    }))
  }))
  default = []

  validation {
    condition = alltrue(flatten([
      for r in var.rules : [
        for t in r.targets : try(t.service_specific_overrides, null) == null
      ]
    ]))
    error_message = "service_specific_overrides is not supported by this module yet; omit it or leave it null."
  }

  validation {
    condition = alltrue(flatten([
      for r in var.rules : [
        for t in r.targets :
        !coalesce(t.create_role, false) || (try(t.role_arn, null) == null || try(t.role_arn, "") == "")
      ]
    ]))
    error_message = "When a rule target sets create_role = true, omit role_arn so the module can create the role. When create_role = false, role_arn is optional (omit for targets that use resource policies only, e.g. SNS)."
  }
}

variable "archives" {
  description = "Event archives on the effective event bus."
  type = list(object({
    name               = string
    event_pattern_json = optional(string)
    retention_days     = optional(number)
    kms_key_arn        = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for a in var.archives : try(a.kms_key_arn, null) == null || try(a.kms_key_arn, "") == ""
    ])
    error_message = "archives.kms_key_arn is not supported until the cloudwatch_event_archive primitive exposes a KMS argument; remove kms_key_arn or leave it unset."
  }
}

variable "schedule_groups" {
  description = <<-EOT
    Scheduler schedule groups to create. Map keys must be static strings in configuration (Terraform for_each keys).
    Values.name is the AWS group name and may depend on apply-time values (e.g. random_id). Schedules that use a
    custom group must set group_name to the same name string; schedules using only the built-in "default" group
    can omit group_name.
  EOT
  type = map(object({
    name = string
  }))
  default = {}
}

variable "schedules" {
  description = "EventBridge Scheduler schedules."
  type = list(object({
    name                         = string
    group_name                   = optional(string)
    schedule_expression          = string
    schedule_expression_timezone = optional(string)
    start_date                   = optional(string)
    end_date                     = optional(string)
    flexible_time_window         = optional(any)
    target_arn                   = string
    target_input_json            = optional(string)
    retry_policy                 = optional(any)
    dead_letter_arn              = optional(string)
    role_arn                     = optional(string)
    create_role                  = optional(bool, false)
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.schedules : (
        coalesce(s.create_role, false) && (try(s.role_arn, null) == null || try(s.role_arn, "") == "")
        ) || (
        !coalesce(s.create_role, false) && try(s.role_arn, null) != null && try(s.role_arn, "") != ""
      )
    ])
    error_message = "Each schedule must either set create_role = true (and omit role_arn) or set create_role = false with a non-empty role_arn."
  }

  validation {
    condition = alltrue([
      for s in var.schedules : (
        coalesce(s.group_name, "default") == "default" ||
        contains([for g in values(var.schedule_groups) : g.name], coalesce(s.group_name, "default"))
      )
    ])
    error_message = "Every schedules[*].group_name other than the built-in \"default\" must match a schedule_groups[*].name value."
  }
}

variable "pipes" {
  description = "EventBridge Pipes."
  type = list(object({
    name                  = string
    source_arn            = string
    source_parameters     = optional(any)
    filter_criteria       = optional(any)
    enrichment_arn        = optional(string)
    enrichment_parameters = optional(any)
    target_arn            = string
    target_parameters     = optional(any)
    role_arn              = optional(string)
    create_role           = optional(bool, false)
    source_kms_key_arn    = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for p in var.pipes : (
        coalesce(p.create_role, false) && (try(p.role_arn, null) == null || try(p.role_arn, "") == "")
        ) || (
        !coalesce(p.create_role, false) && try(p.role_arn, null) != null && try(p.role_arn, "") != ""
      )
    ])
    error_message = "Each pipe must either set create_role = true (and omit role_arn) or set create_role = false with a non-empty role_arn."
  }
}

variable "api_destinations" {
  description = "API destinations (connection + destination)."
  type = list(object({
    connection_name       = string
    authorization_type    = string
    auth_parameters       = any
    destination_name      = string
    invocation_endpoint   = string
    http_method           = string
    rate_limit_per_second = optional(number)
  }))
  default = []

  validation {
    condition = alltrue([
      for cn in toset([for a in var.api_destinations : a.connection_name]) : length(distinct([
        for a in var.api_destinations : "${a.authorization_type}:${jsonencode(a.auth_parameters)}" if a.connection_name == cn
      ])) <= 1
    ])
    error_message = "All api_destinations entries sharing a connection_name must use the same authorization_type and auth_parameters."
  }
}

variable "advanced_config" {
  description = "Reserved escape hatch for future passthrough of provider-native settings. Must not be used to bypass tagging or IAM controls."
  type        = any
  default     = null
}
