# nullable = false on a variable with a default: passing null (a setting the
# workspace didn't list) gets the default instead.

variable "name" {
  description = "Team name, lowercase (marketing -> role <ENV>_MARKETING)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{1,30}$", var.name))
    error_message = "Team names must be lowercase letters, digits, or underscores."
  }
}

variable "environment" {
  description = "Environment (the Terraform workspace). Prefixes the role and service user."
  type        = string
}

variable "database" {
  description = "The team's database (from team_objects; gets USAGE)."
  type        = string
}

variable "schema" {
  description = "The team's schema, fully qualified (from team_objects)."
  type        = string
}

variable "warehouse" {
  description = "The team's warehouse (from team_objects)."
  type        = string
}

variable "service_user" {
  description = "Create a service user for the team's tools (dbt, a loader, a BI tool)."
  nullable    = false
  type        = bool
  default     = false
}

variable "service_user_aws_role_arn" {
  description = "IAM role the team's tools run as. The service user trusts it (workload identity federation). Required when service_user = true."
  type        = string
  default     = null

  validation {
    condition     = var.service_user_aws_role_arn == null || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.service_user_aws_role_arn))
    error_message = "service_user_aws_role_arn must be an IAM role ARN (arn:aws:iam::<account>:role/<name>)."
  }
}
