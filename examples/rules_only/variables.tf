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

variable "sns_topic_name" {
  type        = string
  description = "SNS topic name for the single rule target."
}
