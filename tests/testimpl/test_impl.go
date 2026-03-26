package testimpl

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/eventbridge"
	ebtypes "github.com/aws/aws-sdk-go-v2/service/eventbridge/types"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/pipes"
	"github.com/aws/aws-sdk-go-v2/service/resourcegroupstaggingapi"
	"github.com/aws/aws-sdk-go-v2/service/scheduler"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/gruntwork-io/terratest/modules/terraform"
	ttctx "github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestComposableComplete(t *testing.T, ctx ttctx.TestContext) {
	TestComposableCompleteReadOnly(t, ctx)

	t.Run("PutEventsToCustomBus", func(t *testing.T) {
		src := terraform.Output(t, ctx.TerratestTerraformOptions(), "integration_event_source")
		detailType := terraform.Output(t, ctx.TerratestTerraformOptions(), "integration_detail_type")
		busName := terraform.Output(t, ctx.TerratestTerraformOptions(), "bus_name")

		eb := eventbridge.NewFromConfig(awsCfg(t, ctx))
		out, err := eb.PutEvents(context.TODO(), &eventbridge.PutEventsInput{
			Entries: []ebtypes.PutEventsRequestEntry{
				{
					EventBusName: aws.String(busName),
					Source:       aws.String(src),
					DetailType:   aws.String(detailType),
					Detail:       aws.String(`{"msg":"terratest"}`),
				},
			},
		})
		require.NoError(t, err, "PutEvents should succeed")
		require.NotEmpty(t, out.Entries)
		assert.Empty(t, aws.ToString(out.Entries[0].ErrorCode), "PutEvents entry should not report an error code")
	})

	t.Run("PutEventsDeliversThroughBusToSnsE2E", func(t *testing.T) {
		if RunningInCI() {
			t.Skip("Skipping long-running PutEvents→SNS→SQS sink E2E in CI (SQS drain + long-poll). Run locally: go test -v -timeout 30m ./tests/post_deploy_functional/...")
		}
		t.Logf("[local E2E] starting PutEvents→SNS→SQS sink check (may take up to ~90s for drain + long-poll)")
		src := terraform.Output(t, ctx.TerratestTerraformOptions(), "integration_event_source")
		detailType := terraform.Output(t, ctx.TerratestTerraformOptions(), "integration_detail_type")
		busName := terraform.Output(t, ctx.TerratestTerraformOptions(), "bus_name")
		sinkURL := terraform.Output(t, ctx.TerratestTerraformOptions(), "e2e_sink_queue_url")

		markerBytes := make([]byte, 16)
		_, err := rand.Read(markerBytes)
		require.NoError(t, err)
		marker := hex.EncodeToString(markerBytes)
		detailJSON := `{"msg":"terratest-e2e","marker":"` + marker + `"}`

		sqsClient := sqs.NewFromConfig(awsCfg(t, ctx))
		drainSqsQueue(t, sqsClient, sinkURL, "e2e sink (pre-PutEvents)")

		eb := eventbridge.NewFromConfig(awsCfg(t, ctx))
		putOut, err := eb.PutEvents(context.TODO(), &eventbridge.PutEventsInput{
			Entries: []ebtypes.PutEventsRequestEntry{
				{
					EventBusName: aws.String(busName),
					Source:       aws.String(src),
					DetailType:   aws.String(detailType),
					Detail:       aws.String(detailJSON),
				},
			},
		})
		require.NoError(t, err)
		require.NotEmpty(t, putOut.Entries)
		require.Empty(t, aws.ToString(putOut.Entries[0].ErrorCode))

		waitCtx, cancel := context.WithTimeout(context.TODO(), 90*time.Second)
		defer cancel()
		require.True(t, waitForE2EEventOnSink(waitCtx, t, sqsClient, sinkURL, src, detailType, marker),
			"timed out waiting for EventBridge-originated SNS notification on e2e sink (two rules may publish twice; at least one must match)")
	})

	t.Run("SendSqsMatchingPipeFilter", func(t *testing.T) {
		queueURL := terraform.Output(t, ctx.TerratestTerraformOptions(), "sqs_pipe_source_queue_url")
		sqsClient := sqs.NewFromConfig(awsCfg(t, ctx))
		_, err := sqsClient.SendMessage(context.TODO(), &sqs.SendMessageInput{
			QueueUrl:    aws.String(queueURL),
			MessageBody: aws.String(`{"pipe":{"test":"terratest"}}`),
		})
		require.NoError(t, err)
	})
}

func TestComposableCompleteReadOnly(t *testing.T, ctx ttctx.TestContext) {
	busName := terraform.Output(t, ctx.TerratestTerraformOptions(), "bus_name")
	busArn := terraform.Output(t, ctx.TerratestTerraformOptions(), "bus_arn")
	topicArn := terraform.Output(t, ctx.TerratestTerraformOptions(), "sns_topic_arn")
	src := terraform.Output(t, ctx.TerratestTerraformOptions(), "integration_event_source")
	detailType := terraform.Output(t, ctx.TerratestTerraformOptions(), "integration_detail_type")

	t.Run("EventBus", func(t *testing.T) {
		eb := eventbridge.NewFromConfig(awsCfg(t, ctx))
		out, err := eb.DescribeEventBus(context.TODO(), &eventbridge.DescribeEventBusInput{Name: aws.String(busName)})
		require.NoError(t, err)
		assert.Equal(t, busArn, aws.ToString(out.Arn))
		assert.Equal(t, busName, aws.ToString(out.Name))
	})

	t.Run("RulesAndSnsTargets", func(t *testing.T) {
		ruleNames := terraform.OutputList(t, ctx.TerratestTerraformOptions(), "rule_names")
		require.GreaterOrEqual(t, len(ruleNames), 2, "expect built-in integration + audit rules")

		eb := eventbridge.NewFromConfig(awsCfg(t, ctx))
		var sawDetailTypeConstraint bool
		for _, ruleName := range ruleNames {
			desc, err := eb.DescribeRule(context.TODO(), &eventbridge.DescribeRuleInput{
				EventBusName: aws.String(busName),
				Name:         aws.String(ruleName),
			})
			require.NoError(t, err)
			assert.Equal(t, ruleName, aws.ToString(desc.Name))
			assert.Equal(t, "ENABLED", string(desc.State))

			pat := aws.ToString(desc.EventPattern)
			require.NotEmpty(t, pat)
			var m map[string]any
			require.NoError(t, json.Unmarshal([]byte(pat), &m))
			assert.Equal(t, []any{src}, m["source"])
			if dt, ok := m["detail-type"]; ok {
				assert.Equal(t, []any{detailType}, dt)
				sawDetailTypeConstraint = true
			}

			tgts, err := eb.ListTargetsByRule(context.TODO(), &eventbridge.ListTargetsByRuleInput{
				EventBusName: aws.String(busName),
				Rule:         aws.String(ruleName),
			})
			require.NoError(t, err)
			require.NotEmpty(t, tgts.Targets)
			assert.Equal(t, topicArn, aws.ToString(tgts.Targets[0].Arn))
		}
		require.True(t, sawDetailTypeConstraint, "expected at least one rule whose pattern constrains detail-type (integration rule)")
	})

	t.Run("SnsTopicTags", func(t *testing.T) {
		rgta := resourcegroupstaggingapi.NewFromConfig(awsCfg(t, ctx))
		out, err := rgta.GetResources(context.TODO(), &resourcegroupstaggingapi.GetResourcesInput{
			ResourceARNList: []string{topicArn},
		})
		require.NoError(t, err)
		require.NotEmpty(t, out.ResourceTagMappingList)
		tags := out.ResourceTagMappingList[0].Tags
		require.NotEmpty(t, tags)
		tagMap := map[string]string{}
		for _, tag := range tags {
			if tag.Key != nil && tag.Value != nil {
				tagMap[*tag.Key] = *tag.Value
			}
		}
		assert.Equal(t, "test", tagMap["Environment"])
		assert.Equal(t, "terratest", tagMap["Owner"])
	})

	t.Run("SchedulerRoleAttachedPolicyNoStarResource", func(t *testing.T) {
		rolesJSON := terraform.OutputMap(t, ctx.TerratestTerraformOptions(), "scheduler_iam_role_names")
		require.GreaterOrEqual(t, len(rolesJSON), 2, "expect one role per schedule with create_role = true")
		iamc := iam.NewFromConfig(awsCfg(t, ctx))
		for _, roleName := range rolesJSON {
			require.NotEmpty(t, roleName)
			doc := getFirstAttachedPolicyDocument(t, iamc, roleName)
			assertPolicyResourcesScoped(t, doc, topicArn)
		}
	})

	t.Run("PipeDescribe", func(t *testing.T) {
		arns := terraform.OutputList(t, ctx.TerratestTerraformOptions(), "pipe_arns")
		require.NotEmpty(t, arns)
		pipeName := resourceSuffixFromArn(arns[0], "pipe/")
		pc := pipes.NewFromConfig(awsCfg(t, ctx))
		out, err := pc.DescribePipe(context.TODO(), &pipes.DescribePipeInput{Name: aws.String(pipeName)})
		require.NoError(t, err)
		assert.Equal(t, "RUNNING", string(out.CurrentState))
		require.NotNil(t, out.SourceParameters)
		require.NotNil(t, out.SourceParameters.FilterCriteria)
		require.NotEmpty(t, out.SourceParameters.FilterCriteria.Filters)
		pat := aws.ToString(out.SourceParameters.FilterCriteria.Filters[0].Pattern)
		require.NotEmpty(t, pat)
		assert.Contains(t, pat, "terratest")
	})

	t.Run("SchedulesAndGroup", func(t *testing.T) {
		arns := terraform.OutputList(t, ctx.TerratestTerraformOptions(), "schedule_arns")
		require.GreaterOrEqual(t, len(arns), 2, "expect default-group rate schedule and custom-group cron schedule")
		sc := scheduler.NewFromConfig(awsCfg(t, ctx))
		var sawRate, sawCron bool
		var customGroup string
		for _, arn := range arns {
			group, name := scheduleGroupAndNameFromArn(arn)
			out, err := sc.GetSchedule(context.TODO(), &scheduler.GetScheduleInput{
				Name:      aws.String(name),
				GroupName: aws.String(group),
			})
			require.NoError(t, err)
			assert.Equal(t, "ENABLED", string(out.State))
			expr := aws.ToString(out.ScheduleExpression)
			if strings.Contains(expr, "rate(") {
				sawRate = true
			}
			if strings.Contains(expr, "cron(") {
				sawCron = true
			}
			if group != "default" {
				customGroup = group
			}
		}
		assert.True(t, sawRate, "expected a rate() schedule expression")
		assert.True(t, sawCron, "expected a cron() schedule expression")
		require.NotEmpty(t, customGroup, "expected a schedule in a non-default group")
		_, err := sc.GetScheduleGroup(context.TODO(), &scheduler.GetScheduleGroupInput{
			Name: aws.String(customGroup),
		})
		require.NoError(t, err)
	})

	t.Run("ArchiveDescribe", func(t *testing.T) {
		archiveArns := terraform.OutputList(t, ctx.TerratestTerraformOptions(), "archive_arns")
		require.NotEmpty(t, archiveArns)
		archiveName := resourceSuffixFromArn(archiveArns[0], "archive/")
		eb := eventbridge.NewFromConfig(awsCfg(t, ctx))
		out, err := eb.DescribeArchive(context.TODO(), &eventbridge.DescribeArchiveInput{
			ArchiveName: aws.String(archiveName),
		})
		require.NoError(t, err)
		assert.Equal(t, "ENABLED", string(out.State))
		pat := aws.ToString(out.EventPattern)
		require.NotEmpty(t, pat)
		var m map[string]any
		require.NoError(t, json.Unmarshal([]byte(pat), &m))
		assert.Equal(t, []any{src}, m["source"])
	})

	t.Run("ApiDestination", func(t *testing.T) {
		arns := terraform.OutputList(t, ctx.TerratestTerraformOptions(), "api_destination_arns")
		require.NotEmpty(t, arns)
		destName := apiDestinationNameFromArn(arns[0])
		eb := eventbridge.NewFromConfig(awsCfg(t, ctx))
		out, err := eb.DescribeApiDestination(context.TODO(), &eventbridge.DescribeApiDestinationInput{
			Name: aws.String(destName),
		})
		require.NoError(t, err)
		assert.Contains(t, aws.ToString(out.ApiDestinationArn), "arn:aws:events:")
	})

	t.Run("SnsTopicAttributes", func(t *testing.T) {
		snsc := sns.NewFromConfig(awsCfg(t, ctx))
		out, err := snsc.GetTopicAttributes(context.TODO(), &sns.GetTopicAttributesInput{
			TopicArn: aws.String(topicArn),
		})
		require.NoError(t, err)
		assert.Equal(t, topicArn, out.Attributes["TopicArn"])
	})
}

func drainSqsQueue(t *testing.T, client *sqs.Client, queueURL string, label string) {
	t.Helper()
	start := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	for i := 0; i < 100; i++ {
		if err := ctx.Err(); err != nil {
			require.Fail(t, "drainSqsQueue exceeded context deadline", err.Error())
		}
		if !RunningInCI() && (i == 0 || (i+1)%10 == 0) {
			t.Logf("[local E2E] draining %s: batch loop %d, elapsed %s", label, i+1, time.Since(start).Round(time.Second))
		}
		recvCtx, recvCancel := context.WithTimeout(ctx, 25*time.Second)
		out, err := client.ReceiveMessage(recvCtx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     2,
		})
		recvCancel()
		require.NoError(t, err)
		if len(out.Messages) == 0 {
			return
		}
		for _, m := range out.Messages {
			_, err := client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(queueURL),
				ReceiptHandle: m.ReceiptHandle,
			})
			require.NoError(t, err)
		}
	}
}

func waitForE2EEventOnSink(ctx context.Context, t *testing.T, client *sqs.Client, queueURL, wantSrc, wantDetailType, marker string) bool {
	t.Helper()
	start := time.Now()
	poll := 0
	for {
		if err := ctx.Err(); err != nil {
			return false
		}
		poll++
		if !RunningInCI() {
			t.Logf("[local E2E] long-poll e2e sink for matching SNS notification (poll #%d, elapsed %s, up to 20s this wait)...", poll, time.Since(start).Round(time.Second))
		}
		out, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     20,
		})
		if err != nil {
			if ctx.Err() != nil {
				return false
			}
			require.NoError(t, err)
		}
		for _, m := range out.Messages {
			body := aws.ToString(m.Body)
			if e2eBusEventInSnsSqsBodyMatches(body, wantSrc, wantDetailType, marker) {
				_, delErr := client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
					QueueUrl:      aws.String(queueURL),
					ReceiptHandle: m.ReceiptHandle,
				})
				require.NoError(t, delErr)
				return true
			}
			_, _ = client.DeleteMessage(context.Background(), &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(queueURL),
				ReceiptHandle: m.ReceiptHandle,
			})
		}
	}
}

func e2eBusEventInSnsSqsBodyMatches(body, wantSrc, wantDetailType, marker string) bool {
	var snsWrap struct {
		Type    string `json:"Type"`
		Message string `json:"Message"`
	}
	if err := json.Unmarshal([]byte(body), &snsWrap); err != nil {
		return false
	}
	if snsWrap.Type != "Notification" || snsWrap.Message == "" {
		return false
	}
	var ev struct {
		Source     string          `json:"source"`
		DetailType string          `json:"detail-type"`
		Detail     json.RawMessage `json:"detail"`
	}
	if err := json.Unmarshal([]byte(snsWrap.Message), &ev); err != nil {
		return false
	}
	if ev.Source != wantSrc || ev.DetailType != wantDetailType {
		return false
	}
	return strings.Contains(string(ev.Detail), marker)
}

func resourceSuffixFromArn(arn, marker string) string {
	idx := strings.Index(arn, marker)
	if idx < 0 {
		return arn
	}
	return arn[idx+len(marker):]
}

// apiDestinationNameFromArn returns the API destination resource name. ARNs are
// arn:aws:events:region:account:api-destination/NAME/UUID — DescribeApiDestination expects NAME only.
func apiDestinationNameFromArn(arn string) string {
	suffix := resourceSuffixFromArn(arn, "api-destination/")
	if i := strings.Index(suffix, "/"); i >= 0 {
		return suffix[:i]
	}
	return suffix
}

func scheduleGroupAndNameFromArn(arn string) (group, name string) {
	// arn:aws:scheduler:region:acct:schedule/group/nameparts...
	suffix := resourceSuffixFromArn(arn, "schedule/")
	parts := strings.SplitN(suffix, "/", 2)
	if len(parts) == 2 {
		return parts[0], parts[1]
	}
	return "default", suffix
}

func awsCfg(t *testing.T, ctx ttctx.TestContext) aws.Config {
	t.Helper()
	region := terraform.Output(t, ctx.TerratestTerraformOptions(), "aws_region")
	require.NotEmpty(t, region)
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(region))
	require.NoError(t, err)
	return cfg
}

func getFirstAttachedPolicyDocument(t *testing.T, c *iam.Client, roleName string) string {
	t.Helper()
	lap, err := c.ListAttachedRolePolicies(context.TODO(), &iam.ListAttachedRolePoliciesInput{
		RoleName: aws.String(roleName),
	})
	require.NoError(t, err)
	require.NotEmpty(t, lap.AttachedPolicies)
	policyArn := lap.AttachedPolicies[0].PolicyArn
	gp, err := c.GetPolicy(context.TODO(), &iam.GetPolicyInput{PolicyArn: policyArn})
	require.NoError(t, err)
	require.NotNil(t, gp.Policy)
	require.NotNil(t, gp.Policy.DefaultVersionId)
	gpv, err := c.GetPolicyVersion(context.TODO(), &iam.GetPolicyVersionInput{
		PolicyArn: policyArn,
		VersionId: gp.Policy.DefaultVersionId,
	})
	require.NoError(t, err)
	require.NotNil(t, gpv.PolicyVersion)
	doc := aws.ToString(gpv.PolicyVersion.Document)
	if dec, err := url.QueryUnescape(doc); err == nil {
		doc = dec
	}
	return doc
}

type iamPolicyDoc struct {
	Statement []struct {
		Resource json.RawMessage `json:"Resource"`
	} `json:"Statement"`
}

func assertPolicyResourcesScoped(t *testing.T, policyJSON string, mustContain string) {
	t.Helper()
	var doc iamPolicyDoc
	require.NoError(t, json.Unmarshal([]byte(policyJSON), &doc))
	for _, st := range doc.Statement {
		var s string
		if err := json.Unmarshal(st.Resource, &s); err == nil {
			assert.NotEqual(t, "*", s, "IAM policy must not use Resource *")
			if mustContain != "" {
				assert.Contains(t, s, mustContain, "policy Resource should scope to target ARN")
			}
			continue
		}
		var arr []string
		require.NoError(t, json.Unmarshal(st.Resource, &arr))
		for _, r := range arr {
			assert.NotEqual(t, "*", r, "IAM policy must not use Resource *")
			if mustContain != "" {
				assert.Contains(t, r, mustContain)
			}
		}
	}
}
