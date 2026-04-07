// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "existing" {
  count = var.bus.create ? 0 : 1
  name  = local.existing_bus_lookup_name
}
