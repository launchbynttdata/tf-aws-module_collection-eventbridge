// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

variable "aws_region" {
  description = "AWS region for the provider (Terratest sets this from the environment)."
  type        = string
  default     = "us-east-2"
}

variable "tags" {
  type    = map(string)
  default = { Environment = "test", Owner = "review-plan" }
}

variable "required_tag_keys" {
  type    = list(string)
  default = []
}

variable "bus" {
  type    = any
  default = { create = true, policies = [] }
}

variable "rules" {
  type    = any
  default = []
}

variable "archives" {
  type    = any
  default = []
}

variable "schedules" {
  type    = any
  default = []
}

variable "schedule_groups" {
  type    = any
  default = {}
}

variable "pipes" {
  type    = any
  default = []
}

variable "api_destinations" {
  type    = any
  default = []
}

variable "advanced_config" {
  type    = any
  default = null
}
