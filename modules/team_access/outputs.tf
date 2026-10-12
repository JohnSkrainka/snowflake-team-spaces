output "role" {
  description = "Role to grant to the team's people."
  value       = snowflake_account_role.this.name
}

output "service_user" {
  description = "Service user name, or null if the team doesn't have one."
  # one() turns a 0-or-1 element list (from count) into the value or null.
  value = one(snowflake_service_user.this[*].name)
}
