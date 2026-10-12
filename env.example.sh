# Copy to env.sh (gitignored), fill in, then: source env.sh
# The providers read these, so nothing account-specific lives in *.tf files.

# Snowflake
export SNOWFLAKE_ORGANIZATION_NAME="YOURORG"   # from bootstrap/terraform_user.sql
export SNOWFLAKE_ACCOUNT_NAME="YOURACCOUNT"
export SNOWFLAKE_USER="TERRAFORM_SVC"
export SNOWFLAKE_AUTHENTICATOR="SNOWFLAKE_JWT"
export SNOWFLAKE_PRIVATE_KEY="$(cat ~/.ssh/snowflake_tf_key.p8)"

# AWS: nothing needed if `aws sts get-caller-identity` works (e.g. after
# `aws login`). Otherwise name the profile:
# export AWS_PROFILE="my-profile"

# Workspace: locally, `terraform workspace select dev`. A deployer pins it per
# pipeline instead:
# export TF_WORKSPACE="prod"
