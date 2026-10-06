# snowflake-team-spaces

Self-service team spaces in Snowflake. A team that needs a place to work
gets one with a one-line PR instead of a ticket:

```hcl
teams = {
  marketing = {}
  finance   = { service_user = true }
  sales     = {}                       # <- the whole onboarding request
}
```

Each team gets its own database, its own warehouse, and a role that can use
both and nothing else. A team that runs tools (dbt, a loader, a BI tool) can
also get a **keyless** service user: Snowflake trusts the team's AWS IAM role
(workload identity federation), so there's no password or private key to
store or rotate.

## Three modules, split by who's allowed to run them

| Module | Runs as | Creates |
|---|---|---|
| `team_objects` | Snowflake SYSADMIN | database (with one managed-access schema), warehouse |
| `team_access` | Snowflake SECURITYADMIN | team role, its grants, optional service user |
| `team_aws_role` | AWS IAM | the IAM role the team's tools run as |

Each module gets exactly one provider, so none of them can do another's
job. They run in one plan here for the demo. In a larger org they'd be
separate pipelines owned by the platform team, the security team, and the
team that owns the workload. Only names and the role ARN pass between them.

## What gets created

For the `dev` workspace:

| | marketing | finance |
|---|---|---|
| Database + managed-access schema (`team_objects`) | `DEV_MARKETING_DB.MAIN` | `DEV_FINANCE_DB.MAIN` |
| Warehouse, XSMALL, suspends after 60s idle (`team_objects`) | `DEV_MARKETING_WH` | `DEV_FINANCE_WH` |
| Role: USAGE on the DB and warehouse, USAGE + CREATE TABLE/VIEW on the schema (`team_access`) | `DEV_MARKETING` | `DEV_FINANCE` |
| IAM role for the team's tools (`team_aws_role`) | none | `dev-finance-tools` |
| Service user that trusts that IAM role (`team_access`) | none | `DEV_FINANCE_SVC` |

Dev plans 20 resources: 8 for marketing, 10 in Snowflake plus 1 IAM role for
finance, and a workspace guard.

## Layout

```
main.tf                  the three modules, each with for_each over the teams
workspaces.tf            per-workspace team lists (dev, prod) + a guard for unknown workspaces
providers.tf             Snowflake SYSADMIN, Snowflake SECURITYADMIN, AWS
modules/team_objects/    SYSADMIN: the team's schema and warehouse
modules/team_access/     SECURITYADMIN: the team role, its grants, optional service user
modules/team_aws_role/   AWS: the IAM role the team's tools run as
bootstrap/               one-time setup: Terraform's key pair and its Snowflake user
demo/demo.sql            shows the boundaries hold
```

## Run it

```bash
# One-time setup (skip if TERRAFORM_SVC already exists):
./bootstrap/make_key.sh                 # prints a public key
# Paste it into bootstrap/terraform_user.sql, then Run All in Snowsight.

cp env.example.sh env.sh                # fill in org and account names
source env.sh                           # in every new terminal
aws login                               # or any AWS credentials; check with: aws sts get-caller-identity

terraform init
terraform workspace new dev             # later: terraform workspace select dev
terraform plan                          # expect: Plan: 20 to add
terraform apply
terraform output teams
```

Then run `demo/demo.sql` in Snowsight, one statement at a time.

## Interview walkthrough (about 5 minutes)

1. **The problem.** Teams want a place to work in Snowflake. Doing that by
   hand is a ticket, someone running SQL, and grants that drift. Here it's
   one line in `workspaces.tf`.
2. **`main.tf`**: three module calls, each with `for_each` and exactly one
   provider. The ARN goes from `team_aws_role` into `team_access` as a
   reference (`module.team_aws_role[each.key].role_arn`), so Terraform builds
   the IAM role first and nobody copies an ARN by hand.
3. **The modules.** `team_objects` is a database, a schema, and a warehouse.
   `team_access` is the role, its grants, and the service user.
   `team_aws_role` is one IAM role with no permissions attached. Point out
   that each module can only do its own job.
4. **Live: add a team.** Add `sales = {}`, then `plan`: 8 to add, nothing
   else touched.
5. **Live: flip a toggle.** Set `service_user = true` on marketing: 3 to add
   (IAM role, service user, role grant).
6. **Live: remove a team.** Delete `sales`: only its 8 resources are
   destroyed.
7. **`demo.sql`**: marketing can build in its own database but can't see
   finance's or use its warehouse, and finance's service user trusts an IAM role
   instead of holding a key.

## count vs for_each (the question you'll get)

- **`for_each` for collections with names.** Teams are keyed by name, so each
  one has a stable address like `module.team_access["finance"]`. Remove
  marketing and nothing else changes. With `count` over a list, teams are
  addressed by position (`module.team_access[1]`). Remove the first one and
  every team after it shifts down an index. Terraform then tries to turn the
  old `[1]` into the new `[0]`, renaming or recreating objects that had
  nothing to do with the change.
- **`count` for an on/off switch on one resource.**
  `count = var.service_user ? 1 : 0` creates the service user or doesn't.
  Its role grant uses the same condition, so `[0]` is always safe there, and
  the output uses `one(...)` to return the name or `null`.
- **`for_each` over a filtered map.** `team_aws_role` loops over
  `{ for name, team in local.teams : name => team if team.service_user }`,
  so only teams that asked for a service user get an IAM role.
- **`for_each` over a small fixed map inside a module.** The USAGE grants in
  `team_access` loop over `{ DATABASE = ..., WAREHOUSE = ... }`: the same
  privilege on two object types, written once.

## Keyless service users (workload identity federation)

- `team_aws_role` creates `dev-finance-tools`, which the team's tools run as
  (an ECS task role by default; `trusted_services` changes that).
- `team_access` creates `DEV_FINANCE_SVC` with
  `default_workload_identity { aws { arn = <that role> } }`.
- The tool connects with no secret at all:
  ```python
  snowflake.connector.connect(
      account="<org>-<account>",
      authenticator="WORKLOAD_IDENTITY",
      workload_identity_provider="AWS",
  )
  ```
  The driver proves which IAM role it's running as (a signed
  `sts:GetCallerIdentity` call), and Snowflake logs it in as the user that
  trusts that role.
- The IAM role has **no permissions attached**, because `GetCallerIdentity`
  needs none. Any policies would be for the tool's own work, like reading
  S3.
- **Caveats to mention:** the provider treats this field as experimental, so
  it's switched on with `experimental_features_enabled` in `providers.tf`,
  with the version pinned. The provider also can't read the workload identity
  back from Snowflake, so `plan` won't show drift on that one field.

## Design choices

- **A database per team.** It's a hard boundary between teams, and each team
  can have its own settings: finance in prod keeps 7 days of Time Travel,
  marketing keeps the default. Cloning or replicating one team's whole space
  is one statement. The tradeoff is more databases to manage, and if teams
  later share data with each other, those grants cross databases. A shared
  database with a schema per team is the lighter alternative when teams don't
  need different settings.
- **Nothing runs as ACCOUNTADMIN**, which matches Snowflake's recommendation
  for automated scripts. TERRAFORM_SVC has `DEFAULT_SECONDARY_ROLES = ()`, so
  each Snowflake provider really is only its one role.
- **Team roles roll up to SYSADMIN**, so admins can see and manage anything a
  team creates.
- **A warehouse per team.** Spend is attributable per team, and one team's
  heavy query can't slow another team down. Warehouses auto-suspend after a
  minute and are created suspended.
- **One root, one workspace per environment.** `workspaces.tf` holds the
  differences, and `terraform.workspace` names everything. A deployer pins
  the workspace per pipeline (`TF_WORKSPACE`), and branches handle promotion.
  A guard fails the plan in any workspace without settings.
- **Module defaults, overridden only where needed.** Team entries list only
  what's different. `try(each.value.x, null)` plus `nullable = false` in the
  modules means anything left out gets the default.

## Questions to expect

- **What if a tool doesn't run in AWS?** Workload identity also supports GCP,
  Azure, and generic OIDC (GitHub Actions, for example). For a SaaS vendor
  that can't use any of those, fall back to a key pair. The private key lives
  in Secrets Manager in the vendor's or the team's account, and only the
  public key goes in the PR. Never generate it with `tls_private_key`,
  because that puts the private key in Terraform state.
- **Why doesn't `team_access` create the IAM role itself?** Then one pipeline
  would need SECURITYADMIN *and* IAM admin. The role also belongs with the
  workload: its trust policy and permissions depend on where the tool runs.
  The ARN is the contract between the two.
- **How would you do a refactor like splitting modules on a live
  environment?** Resources that move between modules get new addresses, so a
  plain `plan` would destroy and recreate them. `moved` blocks tell Terraform
  it's the same object, so the plan shows a move and nothing is rebuilt.
- **What's missing for production?** Remote state with locking, CI running
  `plan` on PRs and `apply` on merge, a read-only role per team for BI, and
  managed-access schemas with future grants, so objects created by other
  roles stay visible to the team.
- **How do people get access?** Grant the team role to their user, ideally
  through SSO/SCIM groups rather than Terraform-managed users.

## Clean up

```bash
terraform workspace select dev && terraform destroy
```
