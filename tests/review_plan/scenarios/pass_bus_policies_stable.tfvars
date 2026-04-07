# Two bus policy JSON strings — for_each keys must be content hashes (stable under reorder).
bus = {
  create = true
  policies = [
    "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::123456789012:root\"},\"Action\":\"events:PutEvents\",\"Resource\":\"arn:aws:events:REGION_PLACEHOLDER:123456789012:event-bus/default\"}]}",
    "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"events:PutEvents\",\"Resource\":\"*\"}]}"
  ]
}
