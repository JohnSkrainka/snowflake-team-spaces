output "database" {
  description = "The team's database (input for team_access)."
  value       = snowflake_database.this.name
}

output "schema" {
  description = "The team's schema, fully qualified (input for team_access)."
  value       = snowflake_schema.this.fully_qualified_name
}

output "warehouse" {
  description = "The team's warehouse (input for team_access)."
  value       = snowflake_warehouse.this.name
}
