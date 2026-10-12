terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.23"
    }
  }
}

# AWS only: this module never touches Snowflake. In a real org it would live
# with the team's workload (their repo, their AWS account, their pipeline),
# and only the role ARN it outputs would cross over to the Snowflake side.
