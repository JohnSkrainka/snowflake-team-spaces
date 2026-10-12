-- Run once, by hand, in a Snowsight worksheet, before the first `terraform apply`.
-- Use Run All (Cmd/Ctrl+Shift+Enter); Cmd/Ctrl+Enter runs only one statement.
--
-- Everything here needs ACCOUNTADMIN, which is why it isn't in Terraform:
-- Terraform itself never runs as ACCOUNTADMIN. Every statement is safe to
-- re-run, so it's fine if some of this already exists from another project.

USE ROLE ACCOUNTADMIN;

-- 1. The user Terraform logs in as. This key pair is for Terraform's own login
--    from a laptop, not for the teams' service users (those are keyless).
--    A deployer running in AWS or HCP Terraform could drop the key and use
--    workload identity here too (provider authenticator = WORKLOAD_IDENTITY).
CREATE USER IF NOT EXISTS TERRAFORM_SVC
  TYPE                    = SERVICE   -- key pair only: no password, no MFA prompts
  DEFAULT_ROLE            = SYSADMIN
  DEFAULT_SECONDARY_ROLES = ()        -- each provider alias gets exactly one role
  RSA_PUBLIC_KEY          = '<paste the one-line key from make_key.sh>'
  COMMENT                 = 'Terraform automation';

GRANT ROLE SYSADMIN      TO USER TERRAFORM_SVC;  -- databases, schemas, warehouses
GRANT ROLE SECURITYADMIN TO USER TERRAFORM_SVC;  -- roles, grants, users

-- 2. The credit cap. Only ACCOUNTADMIN can create resource monitors or attach
--    them to warehouses, so it lives here instead of in Terraform. An account
--    monitor covers every warehouse in the account, including each team's,
--    and ones Terraform creates later. (It doesn't cover serverless features
--    or storage; Snowflake Budgets do that.)
CREATE RESOURCE MONITOR IF NOT EXISTS ACCOUNT_MONITOR
  WITH CREDIT_QUOTA = 25          -- credits per month, all warehouses combined
  TRIGGERS ON  75 PERCENT DO NOTIFY
           ON  90 PERCENT DO NOTIFY
           ON 100 PERCENT DO SUSPEND             -- let running queries finish, then suspend
           ON 110 PERCENT DO SUSPEND_IMMEDIATE;  -- cancel running queries too
ALTER ACCOUNT SET RESOURCE_MONITOR = ACCOUNT_MONITOR;

-- Values for env.sh
SELECT CURRENT_ORGANIZATION_NAME() AS organization_name,
       CURRENT_ACCOUNT_NAME()      AS account_name;