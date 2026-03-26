// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

package testimpl

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/launchbynttdata/lcaf-component-terratest/lib"
	ttctx "github.com/launchbynttdata/lcaf-component-terratest/types"
)

// RunFunctionalTestExamples mirrors lcaf lib.RunSetupTestTeardown for destructive tests but always runs
// terraform destroy in a defer. The stock lcaf path wraps teardown in test_structure.RunTestStage, which
// skips destroy when SKIP_teardown_test_<exampleName> is set, leaving AWS resources in the account.
func RunFunctionalTestExamples(t *testing.T, ctx *ttctx.TestContext, testFunc func(*testing.T, ttctx.TestContext)) {
	infraFolder, varFile := lib.FindTestConfig(ctx.TestConfigFolderName(), ctx.TestConfigFileName())
	var dirs []string
	if lib.IsExamplesFolder(t, infraFolder) {
		dirs = append(dirs, lib.ListAllExamples(t, infraFolder)...)
	} else {
		dirs = append(dirs, infraFolder)
	}
	for _, dir := range dirs {
		runFunctionalTestOneExample(t, ctx, dir, varFile, testFunc)
	}
}

func runFunctionalTestOneExample(t *testing.T, ctx *ttctx.TestContext, dir, varFile string, testFunc func(*testing.T, ttctx.TestContext)) {
	if lib.IsSkipThisTestRequested(dir, *ctx) {
		return
	}
	lib.LoadRequestedInfraDefinitionFromTfVarsOut(t, dir, varFile, ctx.TestConfig())
	ctx.SetTerratestTerraformOptions(lib.NewTerratestTerraformOptions(dir, varFile))
	ctx.SetCurrentTestName(filepath.Base(dir))

	opts := ctx.TerratestTerraformOptions()
	ConfigureTerraformAWSRegionFromSDK(t, opts)
	ConfigureLocalE2ETerraformLogging(t, opts)
	defer terraform.Destroy(t, opts)

	test_structure.RunTestStage(t, "setup_test_"+ctx.CurrentTestName(), func() {
		flags := ctx.TestSpecificFlags()
		name := ctx.CurrentTestName()
		if flags[name] != nil && !flags[name]["IS_TERRAFORM_IDEMPOTENT_APPLY"] {
			terraform.InitAndApply(t, opts)
		} else {
			terraform.InitAndApplyAndIdempotent(t, opts)
		}
	})

	testFunc(t, *ctx)
}
