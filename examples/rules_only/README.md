# rules_only

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
| [random_id.example_isolation](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.sns_publish](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bus"></a> [bus](#input\_bus) | n/a | <pre>object({<br/>    create            = bool<br/>    name              = optional(string)<br/>    existing_bus_name = optional(string)<br/>    existing_bus_arn  = optional(string)<br/>    policies          = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_class_env"></a> [class\_env](#input\_class\_env) | n/a | `string` | `"dev"` | no |
| <a name="input_instance_env"></a> [instance\_env](#input\_instance\_env) | n/a | `number` | `0` | no |
| <a name="input_instance_resource"></a> [instance\_resource](#input\_instance\_resource) | n/a | `number` | `0` | no |
| <a name="input_logical_product_family"></a> [logical\_product\_family](#input\_logical\_product\_family) | n/a | `string` | `"launch"` | no |
| <a name="input_logical_product_service"></a> [logical\_product\_service](#input\_logical\_product\_service) | n/a | `string` | `"eventbridge"` | no |
| <a name="input_required_tag_keys"></a> [required\_tag\_keys](#input\_required\_tag\_keys) | n/a | `list(string)` | `[]` | no |
| <a name="input_resource_names_map"></a> [resource\_names\_map](#input\_resource\_names\_map) | n/a | <pre>map(object({<br/>    name       = string<br/>    max_length = optional(number, 60)<br/>  }))</pre> | <pre>{<br/>  "api_destination": {<br/>    "max_length": 64,<br/>    "name": "apid"<br/>  },<br/>  "event_archive": {<br/>    "max_length": 48,<br/>    "name": "arc"<br/>  },<br/>  "event_bus": {<br/>    "max_length": 256,<br/>    "name": "ebus"<br/>  },<br/>  "event_connection": {<br/>    "max_length": 64,<br/>    "name": "conn"<br/>  },<br/>  "event_rule": {<br/>    "max_length": 64,<br/>    "name": "rule"<br/>  },<br/>  "pipe": {<br/>    "max_length": 64,<br/>    "name": "pipe"<br/>  },<br/>  "schedule": {<br/>    "max_length": 64,<br/>    "name": "sched"<br/>  },<br/>  "schedule_group": {<br/>    "max_length": 64,<br/>    "name": "sgrp"<br/>  }<br/>}</pre> | no |
| <a name="input_sns_topic_name"></a> [sns\_topic\_name](#input\_sns\_topic\_name) | SNS topic name for the single rule target. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bus_arn"></a> [bus\_arn](#output\_bus\_arn) | n/a |
| <a name="output_bus_name"></a> [bus\_name](#output\_bus\_name) | n/a |
| <a name="output_rule_names"></a> [rule\_names](#output\_rule\_names) | n/a |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | n/a |
<!-- END_TF_DOCS -->
