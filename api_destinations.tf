// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

locals {
  # Normalize caller `auth_parameters` (any) to the cloudwatch_event_connection primitive object shape.
  api_connection_auth_parameters = {
    for k, v in local.api_connections_by_name : k => (
      try(v.auth_parameters.oauth, null) != null ? {
        api_key = null
        basic   = null
        oauth = {
          authorization_endpoint = v.auth_parameters.oauth.authorization_endpoint
          http_method            = v.auth_parameters.oauth.http_method
          client_parameters      = try(v.auth_parameters.oauth.client_parameters, null)
          oauth_http_parameters = {
            body         = try(v.auth_parameters.oauth.oauth_http_parameters.body, [])
            header       = try(v.auth_parameters.oauth.oauth_http_parameters.header, [])
            query_string = try(v.auth_parameters.oauth.oauth_http_parameters.query_string, [])
          }
        }
        invocation_http_parameters = try(v.auth_parameters.invocation_http_parameters, null)
        } : try(v.auth_parameters.basic, null) != null ? {
        api_key                    = null
        basic                      = v.auth_parameters.basic
        oauth                      = null
        invocation_http_parameters = try(v.auth_parameters.invocation_http_parameters, null)
        } : {
        api_key                    = v.auth_parameters.api_key
        basic                      = null
        oauth                      = null
        invocation_http_parameters = try(v.auth_parameters.invocation_http_parameters, null)
      }
    )
  }

  api_connection_authorization_type = {
    for k, v in local.api_connections_by_name : k => (
      contains(["OAUTH", "OAUTH_CLIENT_CREDENTIALS"], upper(v.authorization_type)) ? "OAUTH_CLIENT_CREDENTIALS" : upper(v.authorization_type)
    )
  }
}

module "event_connection" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_connection/aws"
  version  = "~> 1.0"
  for_each = local.api_connections_by_name

  name               = local.event_connection_full_names[each.key]
  authorization_type = local.api_connection_authorization_type[each.key]
  auth_parameters    = local.api_connection_auth_parameters[each.key]
  description        = ""
  kms_key_identifier = ""
}

module "event_api_destination" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_event_api_destination/aws"
  version  = "~> 0.0"
  for_each = local.api_destinations_by_key

  name                             = local.event_api_destination_full_names[each.key]
  connection_arn                   = module.event_connection[each.value.connection_name].arn
  invocation_endpoint              = each.value.invocation_endpoint
  http_method                      = each.value.http_method
  description                      = null
  invocation_rate_limit_per_second = coalesce(try(each.value.rate_limit_per_second, null), 300)
}
