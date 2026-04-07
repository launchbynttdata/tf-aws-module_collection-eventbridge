// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

package testimpl

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// RunningInCI is true when the environment sets CI (GitHub Actions, GitLab CI, CircleCI, etc.).
func RunningInCI() bool {
	v := strings.ToLower(strings.TrimSpace(os.Getenv("CI")))
	return v == "true" || v == "1"
}

// LogPostDeployFunctionalScope explains what runs in CI vs locally (long SNS/SQS E2E is subtest-skipped in CI only).
func LogPostDeployFunctionalScope(t *testing.T) {
	t.Helper()
	if RunningInCI() {
		t.Logf("=== post_deploy_functional (CI): Terraform apply/destroy + SDK checks run; long PutEvents→SNS→SQS sink subtest is skipped ===")
		return
	}
	t.Logf("=== post_deploy_functional (local): full suite including long SNS/SQS E2E ===")
	t.Logf("=== Terraform logs stream to stdout; SQS drain / long-poll log progress ===")
	t.Logf("=== Run: go test -v -timeout 30m ./tests/post_deploy_functional/... ===")
}

// LogPostDeployReadOnlyHints prints how to run read-only tests locally (expects examples/complete already applied).
func LogPostDeployReadOnlyHints(t *testing.T) {
	t.Helper()
	if RunningInCI() {
		return
	}
	t.Logf("=== post_deploy_functional_readonly: expects examples/complete with .terraform (already applied) ===")
	t.Logf("=== Run: go test -v -timeout 15m ./tests/post_deploy_functional_readonly/... ===")
}

// ConfigureLocalE2ETerraformLogging sends Terraform/Terratest logs to stdout immediately (avoids silent long applies).
func ConfigureLocalE2ETerraformLogging(t *testing.T, opts *terraform.Options) {
	if RunningInCI() || opts == nil {
		return
	}
	opts.Logger = logger.Terratest
}
