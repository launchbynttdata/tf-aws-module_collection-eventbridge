// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

check "required_tag_keys_present" {
  assert {
    condition = alltrue([
      for k in var.required_tag_keys : contains(keys(var.tags), k)
    ])
    error_message = "All required_tag_keys must be present in tags."
  }
}

check "rule_names_unique" {
  assert {
    condition     = local.rule_names_ok
    error_message = "rules[*].name values must be unique."
  }
}

check "archive_names_unique" {
  assert {
    condition     = local.archive_names_ok
    error_message = "archives[*].name values must be unique."
  }
}

check "schedule_names_unique" {
  assert {
    condition     = local.schedule_names_ok
    error_message = "schedules[*].name values must be unique."
  }
}

check "pipe_names_unique" {
  assert {
    condition     = local.pipe_names_ok
    error_message = "pipes[*].name values must be unique."
  }
}

check "rule_event_patterns_json" {
  assert {
    condition = alltrue([
      for r in var.rules : can(jsondecode(r.event_pattern_json))
    ])
    error_message = "Each rules[*].event_pattern_json must be valid JSON."
  }
}

check "archive_patterns_json" {
  assert {
    condition = alltrue([
      for a in var.archives :
      try(a.event_pattern_json, null) == null || a.event_pattern_json == "" ? true : can(jsondecode(a.event_pattern_json))
    ])
    error_message = "When set, archives[*].event_pattern_json must be valid JSON."
  }
}
