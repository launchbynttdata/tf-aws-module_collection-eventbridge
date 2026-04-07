// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

package review_plan_test

import (
	"context"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
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
	wantScheduleGroupErr      = `schedules[*].group_name other than the built-in "default" must match`
	wantPipeRoleErr           = "Each pipe must either set create_role"
	wantDuplicateRuleNamesErr = "rules[*].name values must be unique"
	// Terraform CLI wraps error_message across lines between "supported" and "Scheduler target".
	wantScheduleTargetClassErr  = "When schedules[*].create_role is true, target_arn must be a supported"
	wantScheduleGroupsUniqueErr = "schedule_groups map entries must use distinct"
	wantScheduleEcsParamsErr    = "ecs_parameters must be set"
)

var (
	eventBusPolicyForEachKeyRe = regexp.MustCompile(`module\.collection\.module\.event_bus_policy\["([a-f0-9]{64})"\]`)
	eventBridgeRuleARNRE       = regexp.MustCompile(`arn:aws:events:[a-z0-9-]+:[0-9]{12}:rule/[^"]+`)
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

func TestPlan_pipe_nameOverride_usesProvidedName(t *testing.T) {
	opts := planOpts(t, "pass_pipe_schedule_name_override.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)

	pipe := findPlannedResource(plan, "aws_pipes_pipe", `pipes_pipe["logical-pipe-name"]`)
	require.NotNil(t, pipe, "expected aws_pipes_pipe for logical-pipe-name in plan")
	name, ok := pipe.AttributeValues["name"].(string)
	require.True(t, ok, "pipe name should be a string in planned values")
	require.Equal(t, "my-exact-aws-pipe-name", name,
		"name_override must be used as the deployed AWS pipe name verbatim, ignoring the Launch naming prefix")
}

func TestPlan_schedule_nameOverride_usesProvidedName(t *testing.T) {
	opts := planOpts(t, "pass_pipe_schedule_name_override.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)

	sched := findPlannedResource(plan, "aws_scheduler_schedule", `scheduler_schedule["logical-schedule-name"]`)
	require.NotNil(t, sched, "expected aws_scheduler_schedule for logical-schedule-name in plan")
	name, ok := sched.AttributeValues["name"].(string)
	require.True(t, ok, "schedule name should be a string in planned values")
	require.Equal(t, "my-exact-aws-schedule-name", name,
		"name_override must be used as the deployed AWS schedule name verbatim, ignoring the Launch naming prefix")
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

func TestPlan_scheduler_firehoseCreateRole_policyIncludesFirehoseActions(t *testing.T) {
	opts := planOpts(t, "pass_scheduler_firehose.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)
	found := plannedIAMPolicyDocumentsContaining(plan, "firehose:PutRecord")
	require.NotEmpty(t, found, "expected at least one planned IAM policy document to grant firehose:PutRecord for Firehose scheduler target")
}

func TestPlan_duplicateRuleNames_failsValidation(t *testing.T) {
	opts := planOpts(t, "fail_duplicate_rule_names.tfvars")
	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err)
	require.Contains(t, err.Error(), wantDuplicateRuleNamesErr)
}

func TestPlan_scheduleUnsupportedTarget_failsValidation(t *testing.T) {
	opts := planOpts(t, "fail_schedule_unsupported_target.tfvars")
	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err)
	require.Contains(t, err.Error(), wantScheduleTargetClassErr)
}

func TestPlan_busPolicy_forEachKeysAreContentHashes(t *testing.T) {
	opts := planOpts(t, "pass_bus_policies_stable.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)
	keys := plannedEventBusPolicyForEachKeys(plan)
	require.Len(t, keys, 2, "expected two event bus policy module instances")
	for _, k := range keys {
		require.Regexp(t, "^[a-f0-9]{64}$", k, "for_each key should be sha256(policy) hex")
	}
}

func TestTerraformValidate_fixtureSucceeds(t *testing.T) {
	dir := fixtureDir(t)
	opts := &terraform.Options{
		TerraformDir: dir,
		NoColor:      true,
		Logger:       logger.Discard,
		EnvVars: map[string]string{
			"TF_IN_AUTOMATION": "true",
			"TF_INPUT":         "0",
		},
	}
	terraform.Init(t, opts)
	terraform.Validate(t, opts)
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

func TestPlan_defaultBus_ruleTargetCreateRole_trustPolicyUsesDefaultBusRuleArnShape(t *testing.T) {
	opts := planOpts(t, "pass_default_bus_rule_target_create_role.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)

	policies := plannedEventTargetAssumeRolePolicies(plan)
	require.NotEmpty(t, policies, "expected planned IAM roles for event targets with create_role")
	for _, doc := range policies {
		for _, arn := range eventBridgeRuleARNsInString(doc) {
			require.Equal(t, 1, eventBridgeRulePathSegmentCount(arn),
				"default event bus rule ARN must be arn:aws:events:region:account:rule/<RuleName> (single path segment after :rule/), got %q", arn)
			require.NotContains(t, arn, "rule/default/",
				"must not use a named-bus style SourceArn with literal default/ for the account default bus; got %q", arn)
		}
	}
}

func TestPlan_customBus_ruleTargetCreateRole_trustPolicyUsesNamedBusRuleArnShape(t *testing.T) {
	opts := planOpts(t, "pass_custom_bus_rule_target_create_role.tfvars")
	plan := initPlanShowStructOrSkip(t, opts)

	policies := plannedEventTargetAssumeRolePolicies(plan)
	require.NotEmpty(t, policies, "expected planned IAM roles for event targets with create_role")
	for _, doc := range policies {
		for _, arn := range eventBridgeRuleARNsInString(doc) {
			require.Equal(t, 2, eventBridgeRulePathSegmentCount(arn),
				"custom event bus rule ARN must be arn:aws:events:region:account:rule/<BusName>/<RuleName>; got %q", arn)
		}
	}
}

func TestPlan_validation_scheduleGroups_duplicateNames(t *testing.T) {
	opts := planOpts(t, "fail_schedule_groups_duplicate_names.tfvars")
	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err)
	require.Contains(t, err.Error(), wantScheduleGroupsUniqueErr)
}

func TestPlan_validation_schedule_ecsMissingParameters(t *testing.T) {
	opts := planOpts(t, "fail_schedule_ecs_missing_parameters.tfvars")
	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err)
	require.Contains(t, err.Error(), wantScheduleEcsParamsErr)
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
			"AWS_REGION":         region,
			"AWS_DEFAULT_REGION": region,
			"TF_IN_AUTOMATION":   "true",
			"TF_INPUT":           "0",
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
		if strict := os.Getenv("REVIEW_PLAN_REQUIRE_AWS"); strict == "1" || strict == "true" {
			require.NoError(t, err, "REVIEW_PLAN_REQUIRE_AWS is set but plan failed (working AWS credentials required)")
			return nil
		}
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

func eventBridgeRulePathSegmentCount(arn string) int {
	const mark = ":rule/"
	i := strings.Index(arn, mark)
	if i < 0 {
		return 0
	}
	tail := arn[i+len(mark):]
	if tail == "" {
		return 0
	}
	return strings.Count(tail, "/") + 1
}

func eventBridgeRuleARNsInString(s string) []string {
	return eventBridgeRuleARNRE.FindAllString(s, -1)
}

func plannedEventTargetAssumeRolePolicies(plan *terraform.PlanStruct) []string {
	var out []string
	for addr, res := range plan.ResourcePlannedValuesMap {
		if res.Type != "aws_iam_role" || !strings.Contains(addr, "iam_role_event_target") {
			continue
		}
		raw, ok := res.AttributeValues["assume_role_policy"].(string)
		if !ok || raw == "" {
			continue
		}
		out = append(out, raw)
	}
	return out
}

func plannedIAMPolicyDocumentsContaining(plan *terraform.PlanStruct, needle string) []string {
	var out []string
	for _, res := range plan.ResourcePlannedValuesMap {
		if res.Type != "aws_iam_policy" {
			continue
		}
		raw, ok := res.AttributeValues["policy"].(string)
		if !ok || raw == "" {
			continue
		}
		if strings.Contains(raw, needle) {
			out = append(out, raw)
		}
	}
	return out
}

func plannedEventBusPolicyForEachKeys(plan *terraform.PlanStruct) []string {
	seen := map[string]bool{}
	var keys []string
	for addr := range plan.ResourceChangesMap {
		m := eventBusPolicyForEachKeyRe.FindStringSubmatch(addr)
		if len(m) < 2 || seen[m[1]] {
			continue
		}
		seen[m[1]] = true
		keys = append(keys, m[1])
	}
	sort.Strings(keys)
	return keys
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
