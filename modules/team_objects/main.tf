# A team's objects: its own database (with one schema to build in) and a
# warehouse to pay with. Owned by SYSADMIN. Who can use them is decided
# separately, in team_access.

locals {
  prefix = "${upper(var.environment)}_${upper(var.name)}"
  note   = "Team space for ${var.name}. Managed by Terraform (snowflake-team-spaces)."
}

# A database per team: a hard boundary between teams, and per-team settings
# like Time Travel retention. Cloning or replicating one team's whole space
# is a single statement.
resource "snowflake_database" "this" {
  name                           = "${local.prefix}_DB"
  comment                        = local.note
  data_retention_time_in_days    = var.data_retention_days
  drop_public_schema_on_creation = true
}

resource "snowflake_schema" "this" {
  database = snowflake_database.this.name
  name     = "MAIN"
  comment  = local.note

  # Managed access: the team still owns (and fully controls) what it creates,
  # but only the schema owner or SECURITYADMIN can grant access to it. So
  # nobody can share a table outside Terraform with GRANT SELECT.
  with_managed_access = "true"
}

resource "snowflake_warehouse" "this" {
  name                = "${local.prefix}_WH"
  comment             = local.note
  warehouse_size      = var.warehouse_size
  auto_suspend        = 60     # idle for a minute -> stop billing
  auto_resume         = "true" # wake up on the next query
  initially_suspended = true   # creating it costs nothing
}
