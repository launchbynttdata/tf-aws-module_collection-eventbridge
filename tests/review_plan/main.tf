// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

// Plan-only fixture for regressions from the 2026-03-24 module review (schedule groups, pipe IAM contract,
// API destination naming). See scenarios/*.tfvars and main_test.go.

module "collection" {
  source = "../.."

  tags              = var.tags
  required_tag_keys = var.required_tag_keys
  bus               = var.bus
  rules             = var.rules
  archives          = var.archives
  schedules         = var.schedules
  schedule_groups   = var.schedule_groups
  pipes             = var.pipes
  api_destinations  = var.api_destinations
  advanced_config   = var.advanced_config
}

// This provider is added here to support the non-standard test configuration for these review plan tests.
// The functional tests use the default provider configuration, but the review plan tests need to set the region
// explicitly.
provider "aws" {
  region = var.aws_region
}
