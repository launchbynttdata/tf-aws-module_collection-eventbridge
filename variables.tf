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

  validation {
    condition = alltrue([
      for k in var.required_tag_keys : contains(keys(var.tags), k)
    ])
    error_message = "All required_tag_keys must be present in tags."
  }
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

  validation {
    condition     = length([for r in var.rules : r.name]) == length(distinct([for r in var.rules : r.name]))
    error_message = "rules[*].name values must be unique."
  }

  validation {
    condition = alltrue([
      for r in var.rules : can(jsondecode(r.event_pattern_json))
    ])
    error_message = "Each rules[*].event_pattern_json must be valid JSON."
  }

  validation {
    condition     = alltrue([for r in var.rules : length(r.targets) > 0])
    error_message = "Each rule must declare at least one target in rules[*].targets."
  }

  validation {
    condition = alltrue(flatten([
      for r in var.rules : [
        for t in r.targets :
        !coalesce(t.create_role, false) || contains(
          ["sqs", "lambda", "sns", "stepfunctions", "sfn", "firehose", "events", "eventbus", "events_api_destination", "api_destination"],
          lower(t.type)
        )
      ]
    ]))
    error_message = "When create_role is true, rule target type must be one of: sqs, lambda, sns, stepfunctions, sfn, firehose, events, eventbus, events_api_destination, api_destination."
  }
}

variable "archives" {
  description = "Event archives on the effective event bus. KMS encryption on archives is not supported until the cloudwatch_event_archive primitive exposes a KMS argument."
  type = list(object({
    name               = string
    event_pattern_json = optional(string)
    retention_days     = optional(number)
  }))
  default = []

  validation {
    condition     = length([for a in var.archives : a.name]) == length(distinct([for a in var.archives : a.name]))
    error_message = "archives[*].name values must be unique."
  }

  validation {
    condition = alltrue([
      for a in var.archives :
      try(a.event_pattern_json, null) == null || a.event_pattern_json == "" ? true : can(jsondecode(a.event_pattern_json))
    ])
    error_message = "When set, archives[*].event_pattern_json must be valid JSON."
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

  validation {
    condition = length(distinct([for _, g in var.schedule_groups : g.name])) == length([
      for _, g in var.schedule_groups : g.name
    ])
    error_message = "schedule_groups map entries must use distinct name values (each AWS schedule group name must be unique)."
  }
}

variable "schedules" {
  description = "EventBridge Scheduler schedules."
  type = list(object({
    name                         = string
    name_override                = optional(string)
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
    ecs_parameters               = optional(any)
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.schedules :
      !startswith(s.target_arn, "arn:aws:ecs:") || try(s.ecs_parameters, null) != null
    ])
    error_message = "When schedules[*].target_arn is an ECS ARN, ecs_parameters must be set (required by EventBridge Scheduler)."
  }

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

  validation {
    condition     = length([for s in var.schedules : s.name]) == length(distinct([for s in var.schedules : s.name]))
    error_message = "schedules[*].name values must be unique."
  }

  validation {
    condition = alltrue([
      for s in var.schedules :
      !coalesce(s.create_role, false) || (
        startswith(s.target_arn, "arn:aws:lambda:") ||
        startswith(s.target_arn, "arn:aws:sqs:") ||
        startswith(s.target_arn, "arn:aws:sns:") ||
        startswith(s.target_arn, "arn:aws:states:") ||
        startswith(s.target_arn, "arn:aws:events:") ||
        startswith(s.target_arn, "arn:aws:firehose:") ||
        startswith(s.target_arn, "arn:aws:ecs:") ||
        startswith(s.target_arn, "arn:aws:codebuild:")
      )
    ])
    error_message = "When schedules[*].create_role is true, target_arn must be a supported Scheduler target (Lambda, SQS, SNS, Step Functions, EventBridge, Firehose, ECS, CodeBuild)."
  }

  validation {
    condition = alltrue([
      for s in var.schedules :
      try(s.name_override, null) == null || (try(length(s.name_override), 0) >= 1 && try(length(s.name_override), 0) <= 64)
    ])
    error_message = "When set, schedules[*].name_override must be 1–64 characters (AWS Scheduler schedule name limit)."
  }
}

variable "pipes" {
  description = <<-EOT
    EventBridge Pipes. Optional execution logging:
    - log_configuration — passed to the pipes_pipe primitive (level required when set; supports CloudWatch Logs, Firehose, S3 per AWS).
    - managed_execution_logging — create a CloudWatch log group in this module and set log_configuration (mutually exclusive with log_configuration.cloudwatch_logs_log_destination).
    - execution_logs_kms_key_arn — CMK for encrypted execution logs (BYO log group or Firehose/S3); merged with managed_execution_logging.kms_key_id when both apply.
    When create_role is true, generated IAM includes logs (and KMS when a key is specified) for the configured destinations. With create_role false, attach equivalent permissions to role_arn.
  EOT
  # type = any is required so callers can pass a list whose elements have different
  # target_parameters / source_parameters shapes (e.g. step-functions vs. lambda).
  # Terraform cannot find a common base type for a list literal whose object elements
  # differ in attribute sets, even when those attributes are typed optional(any).
  # All validations below use try()/coalesce() and remain fully effective.
  type    = any
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

  validation {
    condition     = length([for p in var.pipes : p.name]) == length(distinct([for p in var.pipes : p.name]))
    error_message = "pipes[*].name values must be unique."
  }

  validation {
    condition = alltrue([
      for p in var.pipes :
      !coalesce(p.create_role, false) || (
        startswith(p.source_arn, "arn:aws:sqs:") ||
        startswith(p.source_arn, "arn:aws:dynamodb:") ||
        startswith(p.source_arn, "arn:aws:kinesis:")
      )
    ])
    error_message = "When pipes[*].create_role is true, source_arn must be SQS, DynamoDB stream, or Kinesis (supported pipe sources for generated IAM)."
  }

  validation {
    condition = alltrue([
      for p in var.pipes :
      !coalesce(p.create_role, false) || (
        startswith(p.target_arn, "arn:aws:sqs:") ||
        startswith(p.target_arn, "arn:aws:sns:") ||
        startswith(p.target_arn, "arn:aws:lambda:") ||
        startswith(p.target_arn, "arn:aws:states:") ||
        startswith(p.target_arn, "arn:aws:firehose:") ||
        startswith(p.target_arn, "arn:aws:execute-api:") ||
        startswith(p.target_arn, "arn:aws:events:")
      )
    ])
    error_message = "When pipes[*].create_role is true, target_arn must be a supported pipe target (SQS, SNS, Lambda, Step Functions, Firehose, API Gateway, or EventBridge)."
  }

  validation {
    # coalesce() rejects empty strings; use explicit null/empty checks and a ternary so startswith/regex never see null.
    condition = alltrue([
      for p in var.pipes :
      !coalesce(p.create_role, false) || (
        try(p.enrichment_arn, null) == null || try(p.enrichment_arn, null) == "" ? true : (
          startswith(p.enrichment_arn, "arn:aws:lambda:") ||
          startswith(p.enrichment_arn, "arn:aws:execute-api:") ||
          can(regex("^arn:aws:events:[^:]+:[^:]+:api-destination/", p.enrichment_arn)) ||
          startswith(p.enrichment_arn, "arn:aws:states:")
        )
      )
    ])
    error_message = "When pipes[*].create_role is true and enrichment_arn is set, enrichment must be Lambda, API Gateway (execute-api), EventBridge API destination, or Step Functions."
  }

  validation {
    condition = alltrue([
      for p in var.pipes :
      try(p.name_override, null) == null || (try(length(p.name_override), 0) >= 1 && try(length(p.name_override), 0) <= 64)
    ])
    error_message = "When set, pipes[*].name_override must be 1–64 characters (AWS EventBridge Pipe name limit)."
  }

  validation {
    condition = alltrue([
      for p in var.pipes :
      !(try(p.managed_execution_logging, null) != null && try(p.log_configuration.cloudwatch_logs_log_destination, null) != null)
    ])
    error_message = "Do not set both pipes[*].managed_execution_logging and pipes[*].log_configuration.cloudwatch_logs_log_destination."
  }

  validation {
    condition = alltrue([
      for p in var.pipes :
      try(p.log_configuration, null) == null || (
        try(p.log_configuration.level, null) != null && contains(["OFF", "ERROR", "INFO", "TRACE"], try(p.log_configuration.level, ""))
      )
    ])
    error_message = "When pipes[*].log_configuration is set, pipes[*].log_configuration.level is required and must be OFF, ERROR, INFO, or TRACE."
  }

  validation {
    condition = alltrue([
      for p in var.pipes :
      try(p.managed_execution_logging, null) == null || (
        try(p.managed_execution_logging.level, null) == null ||
        contains(["ERROR", "INFO", "TRACE"], p.managed_execution_logging.level)
      )
    ])
    error_message = "When set, pipes[*].managed_execution_logging.level must be ERROR, INFO, or TRACE (not OFF; omit managed_execution_logging to disable)."
  }
}

variable "api_destinations" {
  description = "API destinations (connection + destination). When rate_limit_per_second is null, the module uses 300 invocations per second (AWS default-style cap)."
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

  validation {
    condition = alltrue([
      for a in var.api_destinations :
      try(a.auth_parameters.oauth, null) != null ||
      try(a.auth_parameters.basic, null) != null ||
      try(a.auth_parameters.api_key, null) != null
    ])
    error_message = "Each api_destinations[*].auth_parameters must include oauth, basic, or api_key."
  }
}
