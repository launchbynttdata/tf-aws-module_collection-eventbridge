// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

package review_plan_test

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	tfjson "github.com/hashicorp/terraform-json"
	"github.com/stretchr/testify/require"
)

const (
	// Variable validation messages from variables.tf (2026-03-24 review follow-ups).
	wantScheduleGroupErr = `schedules[*].group_name other than the built-in "default" must match`
	wantPipeRoleErr      = "Each pipe must either set create_role"
)

func TestPlan_scheduleGroup_matchesDeclaredGroup(t *testing.T) {
	opts := planOpts(t, "pass_schedule_group_match.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)

	sched := findPlannedResource(plan, "aws_scheduler_schedule", `scheduler_schedule["sched_in_custom_group"]`)
	require.NotNil(t, sched, "expected aws_scheduler_schedule for sched_in_custom_group in plan")
	gn, ok := sched.AttributeValues["group_name"].(string)
	require.True(t, ok, "group_name should be a string in planned values")
	require.Equal(t, "review-plan-custom-sg", gn)

	sg := findPlannedResource(plan, "aws_scheduler_schedule_group", `scheduler_schedule_group["grp"]`)
	require.NotNil(t, sg, "expected aws_scheduler_schedule_group in plan")
	sgName, ok := sg.AttributeValues["name"].(string)
	require.True(t, ok)
	require.Equal(t, "review-plan-custom-sg", sgName)
}

func TestPlan_scheduleGroup_orphanGroupName_failsValidation(t *testing.T) {
	opts := planOpts(t, "fail_schedule_group_orphan.tfvars")
	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err)
	require.Contains(t, err.Error(), wantScheduleGroupErr)
}

func TestPlan_pipe_createRoleWithoutRoleArn_succeeds(t *testing.T) {
	opts := planOpts(t, "pass_pipe_create_role.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)

	pipe := findPlannedResource(plan, "aws_pipes_pipe", `pipes_pipe["pipe_with_generated_role"]`)
	require.NotNil(t, pipe, "expected aws_pipes_pipe in plan")

	ch := findPipeResourceChange(plan, `pipes_pipe["pipe_with_generated_role"]`)
	require.NotNil(t, ch, "expected aws_pipes_pipe resource change in plan")
	require.NotNil(t, ch.Change)
	require.True(t, pipePlannedRoleResolved(ch.Change),
		"create_role pipe should expose role_arn as a known ARN or as unknown-until-apply (generated IAM role)")
}

func TestPlan_pipe_externalRoleMissingRoleArn_failsValidation(t *testing.T) {
	opts := planOpts(t, "fail_pipe_no_role.tfvars")
	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err)
	require.Contains(t, err.Error(), wantPipeRoleErr)
}

func TestPlan_apiDestination_sameDestinationNameDistinctConnections_distinctPlannedNames(t *testing.T) {
	opts := planOpts(t, "pass_api_dest_same_logical_dest_name.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)

	names := plannedAPIDestinationNames(plan)
	require.Len(t, names, 2, "expected two aws_cloudwatch_event_api_destination resources in plan")
	var withA, withB string
	for _, n := range names {
		if strings.Contains(n, "conn-a-shared-dest") {
			withA = n
		}
		if strings.Contains(n, "conn-b-shared-dest") {
			withB = n
		}
	}
	require.NotEmpty(t, withA, "one planned name should include slug conn-a-shared-dest")
	require.NotEmpty(t, withB, "one planned name should include slug conn-b-shared-dest")
	require.NotEqual(t, withA, withB, "AWS API destination names must differ when only connection_name differs")
}

func planOpts(t *testing.T, scenarioFile string) *terraform.Options {
	t.Helper()
	dir := fixtureDir(t)
	region := resolvedAWSRegionForPlan()
	varFile := materializeScenarioVarFile(t, filepath.Join(dir, "scenarios", scenarioFile), region)

	opts := &terraform.Options{
		TerraformDir: dir,
		VarFiles:     []string{varFile},
		Vars: map[string]interface{}{
			"aws_region": region,
		},
		NoColor: true,
		Logger:  logger.Discard,
		EnvVars: map[string]string{
			"AWS_REGION":            region,
			"AWS_DEFAULT_REGION":    region,
			"TF_IN_AUTOMATION":      "true",
			"TF_INPUT":              "0",
		},
	}
	return opts
}

// resolvedAWSRegionForPlan matches the functional test intent when credentials exist; otherwise falls back so
// variable-validation-only plans still get a concrete provider region (no call to STS until the plan graph runs).
func resolvedAWSRegionForPlan() string {
	if r := strings.TrimSpace(os.Getenv("AWS_REGION")); r != "" {
		return r
	}
	if r := strings.TrimSpace(os.Getenv("AWS_DEFAULT_REGION")); r != "" {
		return r
	}
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err == nil && strings.TrimSpace(cfg.Region) != "" {
		return cfg.Region
	}
	return "us-east-2"
}

func fixtureDir(t *testing.T) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	require.True(t, ok)
	return filepath.Dir(file)
}

func initPlanShowStructOrSkip(t *testing.T, opts *terraform.Options) *terraform.PlanStruct {
	t.Helper()
	oldLogger := opts.Logger
	opts.Logger = logger.Discard
	defer func() { opts.Logger = oldLogger }()

	tmpFile, err := os.CreateTemp("", "terratest-plan-file-")
	require.NoError(t, err)
	require.NoError(t, tmpFile.Close())
	t.Cleanup(func() { _ = os.Remove(tmpFile.Name()) })
	opts.PlanFilePath = tmpFile.Name()

	plan, err := terraform.InitAndPlanAndShowWithStructE(t, opts)
	if err != nil && planFailsOnlyForLiveAWS(err) {
		t.Skipf("skipping: full plan needs working AWS credentials (STS / module data sources): %v", err)
		return nil
	}
	require.NoError(t, err)
	return plan
}

func planFailsOnlyForLiveAWS(err error) bool {
	if err == nil {
		return false
	}
	s := err.Error()
	return strings.Contains(s, "ExpiredToken") ||
		strings.Contains(s, "GetCallerIdentity") ||
		strings.Contains(s, "NoCredentialProviders") ||
		strings.Contains(s, "could not load credentials") ||
		strings.Contains(s, "InvalidClientTokenId") ||
		strings.Contains(s, "failed to refresh cached credentials")
}

func materializeScenarioVarFile(t *testing.T, srcPath, region string) string {
	t.Helper()
	raw, err := os.ReadFile(srcPath)
	require.NoError(t, err)
	out := strings.ReplaceAll(string(raw), "REGION_PLACEHOLDER", region)
	dst := filepath.Join(t.TempDir(), filepath.Base(srcPath))
	require.NoError(t, os.WriteFile(dst, []byte(out), 0o600))
	return dst
}

func findPlannedResource(plan *terraform.PlanStruct, wantType, addrNeedle string) *tfjson.StateResource {
	for addr, res := range plan.ResourcePlannedValuesMap {
		if res.Type == wantType && strings.Contains(addr, addrNeedle) {
			return res
		}
	}
	return nil
}

func findPipeResourceChange(plan *terraform.PlanStruct, addrNeedle string) *tfjson.ResourceChange {
	for addr, ch := range plan.ResourceChangesMap {
		if ch.Type == "aws_pipes_pipe" && strings.Contains(addr, addrNeedle) {
			return ch
		}
	}
	return nil
}

// pipePlannedRoleResolved is true when the plan exposes role_arn (known ARN) or marks it unknown until apply.
func pipePlannedRoleResolved(c *tfjson.Change) bool {
	if c == nil {
		return false
	}
	if arn, ok := pipeRoleArnFromAfter(c.After); ok && arn != "" {
		return true
	}
	return afterUnknownHasTrue(c.AfterUnknown, "role_arn")
}

func pipeRoleArnFromAfter(after interface{}) (string, bool) {
	m, ok := after.(map[string]interface{})
	if !ok {
		return "", false
	}
	raw, ok := m["role_arn"].(string)
	return raw, ok
}

func afterUnknownHasTrue(u interface{}, key string) bool {
	m, ok := u.(map[string]interface{})
	if !ok {
		return false
	}
	if b, ok := m[key].(bool); ok && b {
		return true
	}
	for _, v := range m {
		if afterUnknownHasTrue(v, key) {
			return true
		}
	}
	return false
}

func plannedAPIDestinationNames(plan *terraform.PlanStruct) []string {
	var out []string
	for addr, res := range plan.ResourcePlannedValuesMap {
		if res.Type != "aws_cloudwatch_event_api_destination" {
			continue
		}
		if !strings.Contains(addr, "module.collection") || !strings.Contains(addr, "event_api_destination") {
			continue
		}
		name, ok := res.AttributeValues["name"].(string)
		if !ok || name == "" {
			continue
		}
		out = append(out, name)
	}
	return out
}
