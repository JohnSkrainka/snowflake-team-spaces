terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.20"
    }
  }
}

# Expects a provider running as SYSADMIN (or a role that can create schemas in
# the database and create warehouses). Everything here is an object; nothing
# here grants access to anything. That's team_access's job.
