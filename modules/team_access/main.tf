# Who can use a team's objects: a team role, its grants, and an optional
# service user. Managed by SECURITYADMIN. The objects themselves come from
# team_objects; this module only receives their names.

locals {
  prefix = "${upper(var.environment)}_${upper(var.name)}"
  note   = "Team role for ${var.name}. Managed by Terraform (snowflake-team-spaces)."
}

resource "snowflake_account_role" "this" {
  name    = local.prefix
  comment = local.note
}

# Roll the team role up to SYSADMIN, so admins can see and manage whatever
# the team creates.
resource "snowflake_grant_account_role" "to_sysadmin" {
  role_name        = snowflake_account_role.this.name
  parent_role_name = "SYSADMIN"
}

# for_each over a map: USAGE on each account-level object the team needs.
# The keys (DATABASE, WAREHOUSE) become the resource addresses, e.g.
# module.team_access["marketing"].snowflake_grant_privileges_to_account_role.usage["WAREHOUSE"]
resource "snowflake_grant_privileges_to_account_role" "usage" {
  for_each = {
    DATABASE  = var.database
    WAREHOUSE = var.warehouse
  }

  account_role_name = snowflake_account_role.this.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = each.key
    object_name = each.value
  }
}

# Use the schema and create tables and views in it. Whatever the team creates
# is owned by the team role, so it has full control of its own objects.
# Other teams' schemas stay invisible to it.
resource "snowflake_grant_privileges_to_account_role" "schema" {
  account_role_name = snowflake_account_role.this.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]

  on_schema {
    schema_name = var.schema
  }
}

# count as an on/off switch: 1 if the team wants a service user, 0 if not.
# Not every team runs tools, so most teams get none.
#
# No password and no key pair: the user trusts the team's AWS IAM role
# (workload identity federation). A tool running as that role connects with
# authenticator = WORKLOAD_IDENTITY, and Snowflake checks which role it is.
resource "snowflake_service_user" "this" {
  count = var.service_user ? 1 : 0

  name                           = "${local.prefix}_SVC"
  comment                        = "Service user for ${var.name}'s tools. Managed by Terraform (snowflake-team-spaces)."
  default_role                   = snowflake_account_role.this.name
  default_warehouse              = var.warehouse
  default_secondary_roles_option = "NONE" # only the team role, nothing else

  default_workload_identity {
    aws {
      arn = var.service_user_aws_role_arn
    }
  }

  lifecycle {
    precondition {
      condition     = var.service_user_aws_role_arn != null
      error_message = "Team ${var.name} has service_user = true but no service_user_aws_role_arn to trust."
    }
  }
}

# Same condition as the user, so whenever this exists, [0] does too.
resource "snowflake_grant_account_role" "service_user" {
  count = var.service_user ? 1 : 0

  role_name = snowflake_account_role.this.name
  user_name = snowflake_service_user.this[0].name
}
