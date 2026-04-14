// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}
