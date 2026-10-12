# The AWS identity a team's tools run as. Snowflake's service user for the
# team trusts this role (workload identity federation), so the tools log in
# to Snowflake as themselves: no password, no key pair, nothing to rotate.

resource "aws_iam_role" "this" {
  name        = "${lower(var.environment)}-${replace(var.name, "_", "-")}-tools"
  description = "Identity of ${var.name}'s tools. Snowflake service user ${upper(var.environment)}_${upper(var.name)}_SVC trusts it. Managed by Terraform (snowflake-team-spaces)."

  # Who can become this role: the AWS service the team's tools run on.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = var.trusted_services }
    }]
  })

  # No permissions are attached on purpose. Proving the role's identity to
  # Snowflake uses sts:GetCallerIdentity, which needs no IAM permissions. Any
  # policies here would be for the tool's own work (reading S3, writing logs).
}
