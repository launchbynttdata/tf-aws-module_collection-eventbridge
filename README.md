# tf-aws-module_collection-eventbridge

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: CC BY-NC-ND 4.0](https://img.shields.io/badge/License-CC_BY--NC--ND_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

## Overview

Terraform collection module for AWS EventBridge: custom or existing event buses, rules and targets, archives, EventBridge Scheduler schedules and groups, Pipes, and API destinations. It composes Launch primitive modules from `terraform.registry.launch.nttdata.com` (pinned versions). Root data sources (`aws_caller_identity`, `aws_region`, `aws_cloudwatch_event_bus`) remain direct provider reads.

- **Provider:** AWS `~> 5.0`, Terraform `~> 1.9`
- **Tags:** `tags` is required (non-empty). Optional `required_tag_keys` enforces organizational keys.
- **Example:** [`examples/complete`](examples/complete) (uses `test.tfvars` for Terratest).

## IAM policies

Roles created when `create_role = true` (EventBridge targets, Scheduler, Pipes) use **`module_primitive/iam_role`**, **`module_primitive/iam_policy`**, and **`module_primitive/iam_role_policy_attachment`** with trust policies scoped to the relevant service principal (`events.amazonaws.com`, `scheduler.amazonaws.com`, `pipes.amazonaws.com`). Permission statements use **specific resource ARNs** (targets, queues, topics, etc.). This module does **not** emit `Resource: "*"` in generated policies.

If a future change requires a wildcard `Resource` for a particular AWS action, that statement must be isolated, commented in Terraform with **why** it is required, and documented here with a link to the relevant **AWS documentation** (for example [IAM policy elements](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html) and the service’s permissions reference).

## API destinations and connections

Connections and API destinations use **`module_primitive/cloudwatch_event_connection`** (1.0.0) and **`module_primitive/cloudwatch_event_api_destination`** (0.1.0). The connection module is called with `description = ""` and `kms_key_identifier = ""` instead of `null` so Terraform does not evaluate `length(null)` in that primitive’s variable validations.

## Tests

- `tests/post_deploy_functional` — deploy, SDK checks, `PutEvents` mutating test
- `tests/post_deploy_functional_readonly` — `RunNonDestructiveTest`, read-only SDK checks only

Configure AWS credentials and run from the repo root with `mise`/`asdf` Go and Terraform as appropriate.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_event_api_destination"></a> [event\_api\_destination](#module\_event\_api\_destination) | terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_api_destination/aws | ~> 0.0 |
| <a name="module_event_archive"></a> [event\_archive](#module\_event\_archive) | terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_archive/aws | ~> 0.0 |
| <a name="module_event_bus"></a> [event\_bus](#module\_event\_bus) | terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_bus/aws | ~> 0.0 |
| <a name="module_event_bus_policy"></a> [event\_bus\_policy](#module\_event\_bus\_policy) | terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_bus_policy/aws | ~> 0.0 |
| <a name="module_event_connection"></a> [event\_connection](#module\_event\_connection) | terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_connection/aws | ~> 1.0 |
| <a name="module_event_rule"></a> [event\_rule](#module\_event\_rule) | terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_rule/aws | ~> 0.0 |
| <a name="module_event_target"></a> [event\_target](#module\_event\_target) | terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_target/aws | ~> 0.0 |
| <a name="module_iam_policy_event_target"></a> [iam\_policy\_event\_target](#module\_iam\_policy\_event\_target) | terraform.registry.launch.nttdata.com/module_primitive/iam_policy/aws | ~> 0.0 |
| <a name="module_iam_policy_pipe"></a> [iam\_policy\_pipe](#module\_iam\_policy\_pipe) | terraform.registry.launch.nttdata.com/module_primitive/iam_policy/aws | ~> 0.0 |
| <a name="module_iam_policy_scheduler"></a> [iam\_policy\_scheduler](#module\_iam\_policy\_scheduler) | terraform.registry.launch.nttdata.com/module_primitive/iam_policy/aws | ~> 0.0 |
| <a name="module_iam_role_event_target"></a> [iam\_role\_event\_target](#module\_iam\_role\_event\_target) | terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws | ~> 0.0 |
| <a name="module_iam_role_pipe"></a> [iam\_role\_pipe](#module\_iam\_role\_pipe) | terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws | ~> 0.0 |
| <a name="module_iam_role_policy_attachment_event_target"></a> [iam\_role\_policy\_attachment\_event\_target](#module\_iam\_role\_policy\_attachment\_event\_target) | terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws | ~> 0.0 |
| <a name="module_iam_role_policy_attachment_pipe"></a> [iam\_role\_policy\_attachment\_pipe](#module\_iam\_role\_policy\_attachment\_pipe) | terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws | ~> 0.0 |
| <a name="module_iam_role_policy_attachment_scheduler"></a> [iam\_role\_policy\_attachment\_scheduler](#module\_iam\_role\_policy\_attachment\_scheduler) | terraform.registry.launch.nttdata.com/module_primitive/iam_role_policy_attachment/aws | ~> 0.0 |
| <a name="module_iam_role_scheduler"></a> [iam\_role\_scheduler](#module\_iam\_role\_scheduler) | terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws | ~> 0.0 |
| <a name="module_pipes_pipe"></a> [pipes\_pipe](#module\_pipes\_pipe) | terraform.registry.launch.nttdata.com/module_primitive/pipes_pipe/aws | ~> 0.0 |
| <a name="module_resource_names"></a> [resource\_names](#module\_resource\_names) | terraform.registry.launch.nttdata.com/module_library/resource_name/launch | ~> 2.0 |
| <a name="module_scheduler_schedule"></a> [scheduler\_schedule](#module\_scheduler\_schedule) | terraform.registry.launch.nttdata.com/module_primitive/scheduler_schedule/aws | ~> 0.0 |
| <a name="module_scheduler_schedule_group"></a> [scheduler\_schedule\_group](#module\_scheduler\_schedule\_group) | terraform.registry.launch.nttdata.com/module_primitive/scheduler_schedule_group/aws | ~> 0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudwatch_event_bus.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudwatch_event_bus) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_advanced_config"></a> [advanced\_config](#input\_advanced\_config) | Reserved escape hatch for future passthrough of provider-native settings. Must not be used to bypass tagging or IAM controls. | `any` | `null` | no |
| <a name="input_api_destinations"></a> [api\_destinations](#input\_api\_destinations) | API destinations (connection + destination). | <pre>list(object({<br/>    connection_name       = string<br/>    authorization_type    = string<br/>    auth_parameters       = any<br/>    destination_name      = string<br/>    invocation_endpoint   = string<br/>    http_method           = string<br/>    rate_limit_per_second = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_archives"></a> [archives](#input\_archives) | Event archives on the effective event bus. | <pre>list(object({<br/>    name               = string<br/>    event_pattern_json = optional(string)<br/>    retention_days     = optional(number)<br/>    kms_key_arn        = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_bus"></a> [bus](#input\_bus) | Event bus configuration: create a custom bus or use an existing bus. | <pre>object({<br/>    create            = bool<br/>    name              = optional(string)<br/>    existing_bus_name = optional(string)<br/>    existing_bus_arn  = optional(string)<br/>    policies          = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_class_env"></a> [class\_env](#input\_class\_env) | Environment class (e.g. dev, qa, prod) for resource naming. | `string` | `"dev"` | no |
| <a name="input_instance_env"></a> [instance\_env](#input\_instance\_env) | Numeric instance of the environment for resource naming. | `number` | `0` | no |
| <a name="input_instance_resource"></a> [instance\_resource](#input\_instance\_resource) | Numeric instance of the resource for resource naming. | `number` | `0` | no |
| <a name="input_logical_product_family"></a> [logical\_product\_family](#input\_logical\_product\_family) | Product family name used by the resource naming module. | `string` | `"launch"` | no |
| <a name="input_logical_product_service"></a> [logical\_product\_service](#input\_logical\_product\_service) | Product service name used by the resource naming module. | `string` | `"eventbridge"` | no |
| <a name="input_pipes"></a> [pipes](#input\_pipes) | EventBridge Pipes. | <pre>list(object({<br/>    name                  = string<br/>    source_arn            = string<br/>    source_parameters     = optional(any)<br/>    filter_criteria       = optional(any)<br/>    enrichment_arn        = optional(string)<br/>    enrichment_parameters = optional(any)<br/>    target_arn            = string<br/>    target_parameters     = optional(any)<br/>    role_arn              = optional(string)<br/>    create_role           = optional(bool, false)<br/>    source_kms_key_arn    = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_required_tag_keys"></a> [required\_tag\_keys](#input\_required\_tag\_keys) | If non-empty, every key listed here must exist in tags. | `list(string)` | `[]` | no |
| <a name="input_resource_names_map"></a> [resource\_names\_map](#input\_resource\_names\_map) | Map consumed by the resource naming module (for\_each key -> { name, max\_length }). | <pre>map(object({<br/>    name       = string<br/>    max_length = optional(number, 60)<br/>  }))</pre> | <pre>{<br/>  "api_destination": {<br/>    "max_length": 64,<br/>    "name": "apid"<br/>  },<br/>  "event_archive": {<br/>    "max_length": 48,<br/>    "name": "arc"<br/>  },<br/>  "event_bus": {<br/>    "max_length": 256,<br/>    "name": "ebus"<br/>  },<br/>  "event_connection": {<br/>    "max_length": 64,<br/>    "name": "conn"<br/>  },<br/>  "event_rule": {<br/>    "max_length": 64,<br/>    "name": "rule"<br/>  },<br/>  "pipe": {<br/>    "max_length": 64,<br/>    "name": "pipe"<br/>  },<br/>  "schedule": {<br/>    "max_length": 64,<br/>    "name": "sched"<br/>  },<br/>  "schedule_group": {<br/>    "max_length": 64,<br/>    "name": "sgrp"<br/>  }<br/>}</pre> | no |
| <a name="input_rules"></a> [rules](#input\_rules) | EventBridge rules and targets on the effective event bus. | <pre>list(object({<br/>    name               = string<br/>    description        = optional(string)<br/>    state              = optional(string, "ENABLED")<br/>    event_pattern_json = string<br/>    targets = list(object({<br/>      name                       = string<br/>      arn                        = string<br/>      type                       = string<br/>      role_arn                   = optional(string)<br/>      create_role                = optional(bool, false)<br/>      dlq_arn                    = optional(string)<br/>      retry_policy               = optional(any)<br/>      input_json                 = optional(string)<br/>      input_path                 = optional(string)<br/>      input_transformer          = optional(any)<br/>      service_specific_overrides = optional(any)<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_schedule_groups"></a> [schedule\_groups](#input\_schedule\_groups) | Scheduler schedule groups to create. Map keys must be static strings in configuration (Terraform for\_each keys).<br/>Values.name is the AWS group name and may depend on apply-time values (e.g. random\_id). Schedules that use a<br/>custom group must set group\_name to the same name string; schedules using only the built-in "default" group<br/>can omit group\_name. | <pre>map(object({<br/>    name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | EventBridge Scheduler schedules. | <pre>list(object({<br/>    name                         = string<br/>    group_name                   = optional(string)<br/>    schedule_expression          = string<br/>    schedule_expression_timezone = optional(string)<br/>    start_date                   = optional(string)<br/>    end_date                     = optional(string)<br/>    flexible_time_window         = optional(any)<br/>    target_arn                   = string<br/>    target_input_json            = optional(string)<br/>    retry_policy                 = optional(any)<br/>    dead_letter_arn              = optional(string)<br/>    role_arn                     = optional(string)<br/>    create_role                  = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Required organizational tags applied to all taggable resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_destination_arns"></a> [api\_destination\_arns](#output\_api\_destination\_arns) | API destination ARNs sorted by composite key. |
| <a name="output_archive_arns"></a> [archive\_arns](#output\_archive\_arns) | Archive ARNs sorted by archive key. |
| <a name="output_archive_names"></a> [archive\_names](#output\_archive\_names) | Archive names sorted by key. |
| <a name="output_bus_arn"></a> [bus\_arn](#output\_bus\_arn) | Effective event bus ARN. |
| <a name="output_bus_name"></a> [bus\_name](#output\_bus\_name) | Effective event bus name. |
| <a name="output_connection_arns"></a> [connection\_arns](#output\_connection\_arns) | Event connection ARNs sorted by connection\_name (one connection per distinct name). |
| <a name="output_event_target_iam_role_names"></a> [event\_target\_iam\_role\_names](#output\_event\_target\_iam\_role\_names) | Names of IAM roles created for EventBridge targets (create\_role = true), keyed by rule:target. |
| <a name="output_pipe_arns"></a> [pipe\_arns](#output\_pipe\_arns) | Pipe ARNs sorted by pipe name. |
| <a name="output_pipe_iam_role_names"></a> [pipe\_iam\_role\_names](#output\_pipe\_iam\_role\_names) | Names of IAM roles created for Pipes (create\_role = true). |
| <a name="output_rule_arns"></a> [rule\_arns](#output\_rule\_arns) | Rule ARNs sorted by rule name for stable ordering. |
| <a name="output_rule_names"></a> [rule\_names](#output\_rule\_names) | Rule names in input order. |
| <a name="output_schedule_arns"></a> [schedule\_arns](#output\_schedule\_arns) | Schedule ARNs sorted by schedule name. |
| <a name="output_scheduler_iam_role_names"></a> [scheduler\_iam\_role\_names](#output\_scheduler\_iam\_role\_names) | Names of IAM roles created for Scheduler targets (create\_role = true). |
<!-- END_TF_DOCS -->
