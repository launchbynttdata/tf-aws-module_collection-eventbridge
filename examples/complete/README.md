# Complete example

This example provisions supporting SNS/SQS resources, then deploys the EventBridge collection module with built-in integration settings (multiple rules, archive with an event pattern, two schedules including a custom schedule group, one SQS→SNS pipe with a filter, and an API destination) whenever `coalescelist()` sees an empty list for that input. A `random_id` suffix is appended to SNS topic and SQS queue name prefixes so repeated applies and shared AWS accounts are less likely to hit name collisions.

## Usage

Configure AWS credentials and run Terraform from this directory after `make configure` has generated `provider.tf` if your workflow requires it.

Inputs are defined in `variables.tf`. The first non-empty list wins per `coalescelist(var.*, local.example_*)` in `main.tf`; supply your own non-empty `rules`, `archives`, `schedules`, `pipes`, or `api_destinations` to replace the corresponding built-ins entirely.

For a smaller footprint without schedules, pipes, archives, or API destinations, see `examples/rules_only` in the repository.

See `test.tfvars` for values used by Terratest.

End-to-end bus checks (`PutEventsDeliversThroughBusToSnsE2E` in Terratest) use an SQS queue subscribed to the example SNS topic (`e2e_sink_queue_url` output). The test drains that queue, calls `PutEvents` on the custom bus with a unique marker, then long-polls until it receives an SNS notification whose inner payload matches the expected `source`, `detail-type`, and marker. The IAM principal running the tests needs `sqs:ReceiveMessage`, `sqs:DeleteMessage`, and (for the drain step) visibility on all messages in that queue; the sink queue uses the same CMK as the pipe-source queue, so the principal also needs `kms:Decrypt` (and typically `kms:DescribeKey`) on that key. `sqs:PurgeQueue` is not used. Because two built-in rules target the same topic, a single `PutEvents` can produce two SNS deliveries (two SQS messages); the test succeeds when any one message matches.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eventbridge_collection"></a> [eventbridge\_collection](#module\_eventbridge\_collection) | ../.. | n/a |
| <a name="module_sns_topic"></a> [sns\_topic](#module\_sns\_topic) | terraform.registry.launch.nttdata.com/module_primitive/sns_topic/aws | ~> 0.0 |
| <a name="module_sns_topic_policy"></a> [sns\_topic\_policy](#module\_sns\_topic\_policy) | terraform.registry.launch.nttdata.com/module_primitive/sns_topic_policy/aws | ~> 1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_kms_key.pipe_source_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_sns_topic_subscription.e2e_sink](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sqs_queue.e2e_sink](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.pipe_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.e2e_sink](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.pipe_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [random_id.example_isolation](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.e2e_sink_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sns_publish](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sqs_pipe_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_destinations"></a> [api\_destinations](#input\_api\_destinations) | n/a | <pre>list(object({<br/>    connection_name       = string<br/>    authorization_type    = string<br/>    auth_parameters       = any<br/>    destination_name      = string<br/>    invocation_endpoint   = string<br/>    http_method           = string<br/>    rate_limit_per_second = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_archives"></a> [archives](#input\_archives) | n/a | <pre>list(object({<br/>    name               = string<br/>    event_pattern_json = optional(string)<br/>    retention_days     = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_bus"></a> [bus](#input\_bus) | n/a | <pre>object({<br/>    create            = bool<br/>    name              = optional(string)<br/>    existing_bus_name = optional(string)<br/>    existing_bus_arn  = optional(string)<br/>    policies          = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_class_env"></a> [class\_env](#input\_class\_env) | n/a | `string` | `"dev"` | no |
| <a name="input_instance_env"></a> [instance\_env](#input\_instance\_env) | n/a | `number` | `0` | no |
| <a name="input_instance_resource"></a> [instance\_resource](#input\_instance\_resource) | n/a | `number` | `0` | no |
| <a name="input_logical_product_family"></a> [logical\_product\_family](#input\_logical\_product\_family) | n/a | `string` | `"launch"` | no |
| <a name="input_logical_product_service"></a> [logical\_product\_service](#input\_logical\_product\_service) | n/a | `string` | `"eventbridge"` | no |
| <a name="input_pipes"></a> [pipes](#input\_pipes) | n/a | <pre>list(object({<br/>    name                  = string<br/>    source_arn            = string<br/>    source_parameters     = optional(any)<br/>    filter_criteria       = optional(any)<br/>    enrichment_arn        = optional(string)<br/>    enrichment_parameters = optional(any)<br/>    target_arn            = string<br/>    target_parameters     = optional(any)<br/>    role_arn              = optional(string)<br/>    create_role           = optional(bool, false)<br/>    source_kms_key_arn    = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_required_tag_keys"></a> [required\_tag\_keys](#input\_required\_tag\_keys) | n/a | `list(string)` | `[]` | no |
| <a name="input_resource_names_map"></a> [resource\_names\_map](#input\_resource\_names\_map) | n/a | <pre>map(object({<br/>    name       = string<br/>    max_length = optional(number, 60)<br/>  }))</pre> | <pre>{<br/>  "api_destination": {<br/>    "max_length": 64,<br/>    "name": "apid"<br/>  },<br/>  "event_archive": {<br/>    "max_length": 48,<br/>    "name": "arc"<br/>  },<br/>  "event_bus": {<br/>    "max_length": 256,<br/>    "name": "ebus"<br/>  },<br/>  "event_connection": {<br/>    "max_length": 64,<br/>    "name": "conn"<br/>  },<br/>  "event_rule": {<br/>    "max_length": 64,<br/>    "name": "rule"<br/>  },<br/>  "pipe": {<br/>    "max_length": 64,<br/>    "name": "pipe"<br/>  },<br/>  "schedule": {<br/>    "max_length": 64,<br/>    "name": "sched"<br/>  },<br/>  "schedule_group": {<br/>    "max_length": 64,<br/>    "name": "sgrp"<br/>  }<br/>}</pre> | no |
| <a name="input_rules"></a> [rules](#input\_rules) | n/a | <pre>list(object({<br/>    name               = string<br/>    description        = optional(string)<br/>    state              = optional(string, "ENABLED")<br/>    event_pattern_json = string<br/>    targets = list(object({<br/>      name                       = string<br/>      arn                        = string<br/>      type                       = string<br/>      role_arn                   = optional(string)<br/>      create_role                = optional(bool, false)<br/>      dlq_arn                    = optional(string)<br/>      retry_policy               = optional(any)<br/>      input_json                 = optional(string)<br/>      input_path                 = optional(string)<br/>      input_transformer          = optional(any)<br/>      service_specific_overrides = optional(any)<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_schedule_groups"></a> [schedule\_groups](#input\_schedule\_groups) | n/a | <pre>map(object({<br/>    name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | n/a | <pre>list(object({<br/>    name                         = string<br/>    group_name                   = optional(string)<br/>    schedule_expression          = string<br/>    schedule_expression_timezone = optional(string)<br/>    start_date                   = optional(string)<br/>    end_date                     = optional(string)<br/>    flexible_time_window         = optional(any)<br/>    target_arn                   = string<br/>    target_input_json            = optional(string)<br/>    retry_policy                 = optional(any)<br/>    dead_letter_arn              = optional(string)<br/>    role_arn                     = optional(string)<br/>    create_role                  = optional(bool, false)<br/>    ecs_parameters               = optional(any)<br/>  }))</pre> | `[]` | no |
| <a name="input_sns_topic_name"></a> [sns\_topic\_name](#input\_sns\_topic\_name) | SNS topic name used by rule, schedule, and pipe targets in this example. | `string` | n/a | yes |
| <a name="input_sqs_queue_name_prefix"></a> [sqs\_queue\_name\_prefix](#input\_sqs\_queue\_name\_prefix) | Name prefix for the SQS queue used as a pipe source. | `string` | `"eb-collection-pipe-src"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_destination_arns"></a> [api\_destination\_arns](#output\_api\_destination\_arns) | n/a |
| <a name="output_archive_arns"></a> [archive\_arns](#output\_archive\_arns) | n/a |
| <a name="output_aws_region"></a> [aws\_region](#output\_aws\_region) | Region where this example is deployed (Terratest uses this to configure the AWS SDK). |
| <a name="output_bus_arn"></a> [bus\_arn](#output\_bus\_arn) | n/a |
| <a name="output_bus_name"></a> [bus\_name](#output\_bus\_name) | n/a |
| <a name="output_connection_arns"></a> [connection\_arns](#output\_connection\_arns) | n/a |
| <a name="output_e2e_sink_queue_url"></a> [e2e\_sink\_queue\_url](#output\_e2e\_sink\_queue\_url) | SQS URL subscribed to the example SNS topic for PutEvents end-to-end tests. |
| <a name="output_integration_detail_type"></a> [integration\_detail\_type](#output\_integration\_detail\_type) | Detail-type used by the integration rule pattern (audit rule matches on source only). |
| <a name="output_integration_event_source"></a> [integration\_event\_source](#output\_integration\_event\_source) | Event source string used by integration rules and Terratest PutEvents (matches module rule patterns). |
| <a name="output_pipe_arns"></a> [pipe\_arns](#output\_pipe\_arns) | n/a |
| <a name="output_pipe_iam_role_names"></a> [pipe\_iam\_role\_names](#output\_pipe\_iam\_role\_names) | n/a |
| <a name="output_required_tag_keys"></a> [required\_tag\_keys](#output\_required\_tag\_keys) | Pass-through from the collection module. |
| <a name="output_rule_arns"></a> [rule\_arns](#output\_rule\_arns) | n/a |
| <a name="output_rule_names"></a> [rule\_names](#output\_rule\_names) | n/a |
| <a name="output_schedule_arns"></a> [schedule\_arns](#output\_schedule\_arns) | n/a |
| <a name="output_scheduler_iam_role_names"></a> [scheduler\_iam\_role\_names](#output\_scheduler\_iam\_role\_names) | n/a |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | n/a |
| <a name="output_sqs_pipe_source_queue_url"></a> [sqs\_pipe\_source\_queue\_url](#output\_sqs\_pipe\_source\_queue\_url) | n/a |
<!-- END_TF_DOCS -->
