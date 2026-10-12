output "teams" {
  description = "Per team: database, schema, warehouse, role, and (if any) service user and the IAM role it trusts."
  value = {
    for team, objects in module.team_objects : team => {
      database      = objects.database
      schema        = objects.schema
      warehouse     = objects.warehouse
      role          = module.team_access[team].role
      service_user  = module.team_access[team].service_user
      tools_iam_arn = try(module.team_aws_role[team].role_arn, null)
    }
  }
}
