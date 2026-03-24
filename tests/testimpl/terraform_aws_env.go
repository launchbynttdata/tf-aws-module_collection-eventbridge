// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

package testimpl

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// ConfigureTerraformAWSRegionFromSDK sets AWS_REGION and AWS_DEFAULT_REGION on the Terraform subprocess from the
// default AWS config chain. Returns the resolved region for callers that also need -var aws_region (e.g. plan fixtures).
func ConfigureTerraformAWSRegionFromSDK(t *testing.T, opts *terraform.Options) string {
	t.Helper()
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)
	require.NotEmpty(t, cfg.Region, "set AWS_REGION, AWS_DEFAULT_REGION, or region in the active AWS profile so Terraform and tests use the same region")

	if opts.EnvVars == nil {
		opts.EnvVars = map[string]string{}
	}
	if _, ok := opts.EnvVars["AWS_REGION"]; !ok {
		opts.EnvVars["AWS_REGION"] = cfg.Region
	}
	if _, ok := opts.EnvVars["AWS_DEFAULT_REGION"]; !ok {
		opts.EnvVars["AWS_DEFAULT_REGION"] = cfg.Region
	}
	return cfg.Region
}
