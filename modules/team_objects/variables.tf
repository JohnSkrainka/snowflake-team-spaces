# nullable = false on a variable with a default: passing null (a setting the
# workspace didn't list) gets the default instead.

variable "name" {
  description = "Team name, lowercase (marketing -> database <ENV>_MARKETING_DB, warehouse <ENV>_MARKETING_WH)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{1,30}$", var.name))
    error_message = "Team names must be lowercase letters, digits, or underscores."
  }
}

variable "environment" {
  description = "Environment (the Terraform workspace). Prefixes the database and warehouse names."
  type        = string
}

variable "warehouse_size" {
  description = "Size of the team's warehouse."
  nullable    = false
  type        = string
  default     = "XSMALL"
}

variable "data_retention_days" {
  description = "Time Travel retention for the team's database. Values above 1 need Enterprise edition."
  nullable    = false
  type        = number
  default     = 1
}
