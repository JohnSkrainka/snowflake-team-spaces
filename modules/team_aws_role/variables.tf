variable "name" {
  description = "Team name, lowercase (finance -> IAM role <env>-finance-tools)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{1,30}$", var.name))
    error_message = "Team names must be lowercase letters, digits, or underscores."
  }
}

variable "environment" {
  description = "Environment (the Terraform workspace). Prefixes the role name."
  type        = string
}

variable "trusted_services" {
  description = "AWS services allowed to run as this role, i.e. where the team's tools run (ECS tasks, Lambda, MWAA...)."
  type        = list(string)
  default     = ["ecs-tasks.amazonaws.com"]
}
