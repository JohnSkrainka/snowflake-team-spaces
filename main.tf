# Three modules per team, split by who's allowed to run them:
#
#   team_objects   -> Snowflake SYSADMIN       database + schema + warehouse
#   team_access    -> Snowflake SECURITYADMIN  role, grants, optional service user
#   team_aws_role  -> AWS IAM                  the identity the team's tools run as
#
# Each module gets exactly one provider. Here all three run in one plan for
# the demo. In a larger org they'd be separate pipelines with separate
# credentials (platform team, security team, the team that owns the workload),
# and only names and ARNs would pass between them.

locals {
  teams = try(local.env.teams, {})

  # A for expression with an `if` filters the map: only teams that asked for
  # a service user get an AWS role.
  teams_with_service_user = {
    for name, team in local.teams : name => team if try(team.service_user, false)
  }
}

# for_each over a map keyed by team name: each team has a stable address
# (module.team_objects["finance"]), so removing one team never touches the others.
module "team_objects" {
  source   = "./modules/team_objects"
  for_each = local.teams

  providers = {
    snowflake = snowflake # SYSADMIN
  }

  name                = each.key
  environment         = terraform.workspace
  warehouse_size      = try(each.value.warehouse_size, null) # null -> module default
  data_retention_days = try(each.value.data_retention_days, null)
}

module "team_aws_role" {
  source   = "./modules/team_aws_role"
  for_each = local.teams_with_service_user

  providers = {
    aws = aws
  }

  name        = each.key
  environment = terraform.workspace
}

module "team_access" {
  source   = "./modules/team_access"
  for_each = local.teams

  providers = {
    snowflake = snowflake.security # SECURITYADMIN
  }

  name        = each.key
  environment = terraform.workspace

  # Names flowing from objects to access. Referencing the outputs also makes
  # Terraform create the objects first.
  database  = module.team_objects[each.key].database
  schema    = module.team_objects[each.key].schema
  warehouse = module.team_objects[each.key].warehouse

  # The ARN is a reference, not a pasted string: Terraform creates the IAM
  # role first, then hands its ARN to the service user. Teams without a
  # service user have no role, so try() gives them null.
  service_user              = try(each.value.service_user, null)
  service_user_aws_role_arn = try(module.team_aws_role[each.key].role_arn, null)
}
