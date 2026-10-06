# Snowflake connection details come from environment variables (see
# env.example.sh):
#   SNOWFLAKE_ORGANIZATION_NAME, SNOWFLAKE_ACCOUNT_NAME, SNOWFLAKE_USER,
#   SNOWFLAKE_AUTHENTICATOR=SNOWFLAKE_JWT, SNOWFLAKE_PRIVATE_KEY
#
# Same user and key for both Snowflake blocks, each running as a different
# system role, so every resource uses the least privilege that can manage it.
# Nothing runs as ACCOUNTADMIN.

provider "snowflake" {
  role = "SYSADMIN" # databases, schemas, warehouses
}

provider "snowflake" {
  alias = "security"
  role  = "SECURITYADMIN" # roles, grants, users

  # The provider still treats workload identity on users as experimental, so
  # it has to be switched on explicitly. Opted into deliberately, with the
  # provider version pinned.
  experimental_features_enabled = ["USER_ENABLE_DEFAULT_WORKLOAD_IDENTITY"]
}

# AWS credentials come from the usual chain (`aws login`, AWS_PROFILE, the
# deployer's role). Only used for the teams' IAM roles; IAM is global, but
# the provider still wants a region.
provider "aws" {
  region = try(local.env.aws_region, null) # null only in a workspace the guard rejects

  default_tags {
    tags = {
      managed_by  = "terraform"
      repo        = "snowflake-team-spaces"
      environment = terraform.workspace
    }
  }
}
