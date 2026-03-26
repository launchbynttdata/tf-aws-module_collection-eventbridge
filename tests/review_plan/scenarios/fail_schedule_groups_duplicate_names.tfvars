# Two schedule_groups entries must not share the same AWS group name.
schedule_groups = {
  a = { name = "review-plan-dup-sg" }
  b = { name = "review-plan-dup-sg" }
}
