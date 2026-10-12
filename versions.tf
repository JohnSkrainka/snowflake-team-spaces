terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.20" # pinned: this provider has broken configs between releases before
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.23" # 6.23+ reads credentials from `aws login`
    }
  }

  # Local state for the demo: each workspace gets its own file under
  # terraform.tfstate.d/<workspace>/. A team setup would use a remote backend
  # with locking, e.g. S3, where each workspace's state lands under env:/<workspace>/.
}
