# review_plan

Plan-only fixture for module validation and planned-value assertions. Scenarios live under `scenarios/*.tfvars` (see `main_test.go`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_collection"></a> [collection](#module\_collection) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_advanced_config"></a> [advanced\_config](#input\_advanced\_config) | n/a | `any` | `null` | no |
| <a name="input_api_destinations"></a> [api\_destinations](#input\_api\_destinations) | n/a | `any` | `[]` | no |
| <a name="input_archives"></a> [archives](#input\_archives) | n/a | `any` | `[]` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for the provider (Terratest sets this from the environment). | `string` | `"us-east-2"` | no |
| <a name="input_bus"></a> [bus](#input\_bus) | n/a | `any` | <pre>{<br/>  "create": true,<br/>  "policies": []<br/>}</pre> | no |
| <a name="input_pipes"></a> [pipes](#input\_pipes) | n/a | `any` | `[]` | no |
| <a name="input_required_tag_keys"></a> [required\_tag\_keys](#input\_required\_tag\_keys) | n/a | `list(string)` | `[]` | no |
| <a name="input_rules"></a> [rules](#input\_rules) | n/a | `any` | `[]` | no |
| <a name="input_schedule_groups"></a> [schedule\_groups](#input\_schedule\_groups) | n/a | `any` | `{}` | no |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | n/a | `any` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | <pre>{<br/>  "Environment": "test",<br/>  "Owner": "review-plan"<br/>}</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
