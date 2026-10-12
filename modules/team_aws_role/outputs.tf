output "role_arn" {
  description = "ARN of the role. team_access puts it on the team's Snowflake service user."
  value       = aws_iam_role.this.arn
}
