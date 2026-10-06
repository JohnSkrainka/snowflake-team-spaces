terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.20"
    }
  }
}

# Expects a provider running as SECURITYADMIN (or a role with CREATE ROLE,
# CREATE USER, and MANAGE GRANTS), with the experimental feature
# USER_ENABLE_DEFAULT_WORKLOAD_IDENTITY turned on (see providers.tf).
# This module never creates data objects. It only decides who can use the
# ones team_objects made.
