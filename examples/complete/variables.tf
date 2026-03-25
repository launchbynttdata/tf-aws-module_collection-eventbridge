// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

variable "logical_product_family" {
  type    = string
  default = "launch"
}

variable "logical_product_service" {
  type    = string
  default = "eventbridge"
}

variable "class_env" {
  type    = string
  default = "dev"
}

variable "instance_env" {
  type    = number
  default = 0
}

variable "instance_resource" {
  type    = number
  default = 0
}

variable "resource_names_map" {
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
  type = map(string)
}

variable "required_tag_keys" {
  type    = list(string)
  default = []
}

variable "bus" {
  type = object({
    create            = bool
    name              = optional(string)
    existing_bus_name = optional(string)
    existing_bus_arn  = optional(string)
    policies          = optional(list(string), [])
  })
}

variable "rules" {
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
}

variable "archives" {
  type = list(object({
    name               = string
    event_pattern_json = optional(string)
    retention_days     = optional(number)
  }))
  default = []
}

variable "schedule_groups" {
  type = map(object({
    name = string
  }))
  default = {}
}

variable "schedules" {
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
}

variable "pipes" {
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
}

variable "api_destinations" {
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
}

variable "advanced_config" {
  type    = any
  default = null
}

variable "sns_topic_name" {
  description = "SNS topic name used by rule, schedule, and pipe targets in this example."
  type        = string
}

variable "sqs_queue_name_prefix" {
  description = "Name prefix for the SQS queue used as a pipe source."
  type        = string
  default     = "eb-collection-pipe-src"
}
