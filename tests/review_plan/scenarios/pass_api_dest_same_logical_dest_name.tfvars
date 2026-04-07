# Same destination_name under two connection_name values — planned AWS names must differ (locals include connection in slug).
api_destinations = [
  {
    connection_name    = "conn-a"
    authorization_type = "API_KEY"
    auth_parameters = {
      api_key = { key = "k", value = "v" }
    }
    destination_name    = "shared-dest"
    invocation_endpoint = "https://example.invalid/a"
    http_method         = "POST"
  },
  {
    connection_name    = "conn-b"
    authorization_type = "API_KEY"
    auth_parameters = {
      api_key = { key = "k", value = "v" }
    }
    destination_name    = "shared-dest"
    invocation_endpoint = "https://example.invalid/b"
    http_method         = "POST"
  }
]
