# Everything that differs between environments, keyed by Terraform workspace.
#
#   terraform workspace select dev     (locally)
#   TF_WORKSPACE=prod                  (in the deployer, fixed per pipeline)
#
# Onboarding a team = one more line under `teams`. Every setting is optional;
# anything a team leaves out falls back to the module default:
#
#   warehouse_size      = "XSMALL"   # XSMALL | SMALL | MEDIUM | LARGE | ...  (team_objects)
#   data_retention_days = 1          # Time Travel days for the team's database; >1 needs Enterprise  (team_objects)
#   service_user        = false      # true -> an IAM role for the team's tools (team_aws_role)
#                                    #   and a Snowflake user that trusts it    (team_access)
#
# e.g.  finance = { warehouse_size = "SMALL", service_user = true }

locals {
  workspaces = {
    dev = {
      aws_region = "us-east-2"

      teams = {
        marketing = {}
        finance   = { service_user = true }
      }
    }

    prod = {
      aws_region = "us-east-2"

      teams = {
        marketing = { warehouse_size = "SMALL" }
        finance   = { warehouse_size = "MEDIUM", service_user = true, data_retention_days = 7 }
      }
    }
  }

  # null in any workspace without settings, including "default". The guard
  # below turns that into a clear plan error.
  env = try(local.workspaces[terraform.workspace], null)
}

resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = local.env != null
      error_message = "Workspace \"${terraform.workspace}\" has no settings in workspaces.tf. Run `terraform workspace select dev` (or prod), or add an entry for it."
    }
  }
}
