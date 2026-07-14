# terraform-databricks-umbrellacost-integration

This module provisions all resources and permissions required to integrate your Databricks account with Umbrellacost.

At a high level, the module will:

1. Create a Service Principal (`umbrellacost-billing-sp`)
2. Create OAuth credentials for the Service Principal
3. Create a SQL Warehouse (`umbrellacost-billing-warehouse`)
4. Assign the Service Principal permissions to use the SQL Warehouse
5. Grant the Service Principal `USE_SCHEMA` on `system.billing` and `system.access`, plus table-level `SELECT` on exactly `system.billing.usage`, `system.billing.list_prices`, and `system.access.workspaces_latest` — mirrors the manual GRANT statements in the onboarding README/CUSTOMER_SETUP_GUIDE exactly. `system.access` is intentionally **not** granted schema-wide, since that would also expose `system.access.audit` (the full user audit log). `system.compute` is not granted at all — it's for a tag-enrichment feature that isn't implemented in the export container yet.

This module runs entirely in **your** Databricks account/workspace and does not talk to Umbrellacost or submit anything anywhere. After `terraform apply`, collect these values from the outputs and your workspace — you'll be asked to provide them as a separate step when connecting your account in Umbrellacost (currently coordinated with your Umbrellacost contact; self-service entry in the app is planned):

| Value | Source |
|---|---|
| Client ID | `service_principal_id` output |
| Client Secret | `service_principal_secret` output |
| Warehouse ID | `umbrellacost_billing_warehouse_id` output |
| Workspace URL | your Databricks workspace URL |
| Databricks Account ID | Account Console → your account |

### IP allowlist

Optionally set `enable_ip_allowlist = true` to restrict workspace access to a set of static egress IPs, passed via `umbrellacost_static_ips` (list of strings)

## Prerequisites

Before running `terraform apply`, the identity used by the `databricks` provider (a user PAT, or a service principal if you're bootstrapping this way) must have:

1. **Account Admin** — to create the service principal.
2. **Metastore Admin on the metastore attached to the target workspace** — required for every `databricks_grant` resource in this module. Account Admin alone is **not** sufficient; without this, `apply` fails partway through with `User does not have MANAGE on Schema/Table ...` (SP, secret, and warehouse resources will have already been created by that point, since grants run last).

   Metastores are account-wide but Metastore Admin isn't a single account setting — with multiple metastores (e.g. multi-region), you must be admin on the **specific one this workspace uses**:
   - Account Console → **Workspaces** → click the workspace → note the **Metastore** name under Storage (e.g. `metastore_aws_us_west_2`)
   - Account Console → **Catalog** → click that exact metastore → **Configuration** tab → confirm **Metastore Admin** is your account. If not: **Edit** → set it → **Save**

3. **A personal access token, generated with "All APIs" scope:**
   - In the target workspace: user avatar (top-right) → **Settings** → **Developer** → **Access tokens** → **Generate new token**
   - **Name**: anything identifiable, e.g. `terraform`
   - **Lifetime**: short-lived is fine — this token is only used for `apply`/`destroy`, not stored anywhere long-term
   - **Scope**: select **Other APIs**, then in **API scope(s)** choose **All APIs**
   - Copy the token immediately — like the OAuth secret, it's shown only once

Confirm both admin roles are in place *before* running `apply` — check 1 and 2 above rather than discovering the gap mid-apply.

## Databricks Provider Configuration

You will need to define a Databricks provider in your Terraform configuration, specifically a workspace-level provider.

```hcl
# Workspace-level provider
provider "databricks" {
  host  = "$YOUR_WORKSPACE_URL"
  # authenticate to your Databricks workspace...
  # https://registry.terraform.io/providers/databricks/databricks/latest/docs#authentication
}

module "databricks_umbrellacost_integration" {
  source = "./"
  # enable_ip_allowlist     = true
  # umbrellacost_static_ips = ["1.2.3.4/32"]
}
```

## Testing

Run from `examples/local-test/` (or any root config invoking this module directly):

```
$ terraform apply
var.databricks_account_id
  Databricks Account ID (from the Accounts Console)

  Enter a value: <your-databricks-account-id>

var.databricks_host
  Workspace URL, e.g. https://dbc-xxxxxx.cloud.databricks.com

  Enter a value: https://dbc-xxxxxx.cloud.databricks.com

var.databricks_token
  Personal access token with Account Admin + Metastore Admin privileges

  Enter a value:
```

`databricks_host` is safe to save in `terraform.tfvars` for repeated runs. Keep `databricks_token` out of `tfvars`/shell history — let it prompt each time (or export `TF_VAR_databricks_token` only for the duration of one session) so it isn't left lying around after testing.

After `terraform apply`, this local variable is only for driving the connectivity test script below — it's not submitted anywhere. Build it from the outputs with `terraform output -json` (not plain `terraform output`, which redacts `client_secret`):

```bash
CREDS=$(terraform output -json | jq -c '{
  clientId: .client_id.value,
  clientSecret: .client_secret.value,
  workspaceUrl: .workspace_url.value,
  warehouseId: .warehouse_id.value,
  accountId: .account_id.value
}')
```

Verify connectivity locally before providing these values to Umbrellacost as part of onboarding:

```bash
python test-connection/test_databricks_connection.py \
  --host "$(echo $CREDS | jq -r .workspaceUrl)" \
  --warehouse_id "$(echo $CREDS | jq -r .warehouseId)" \
  --client_id "$(echo $CREDS | jq -r .clientId)" \
  --client_secret "$(echo $CREDS | jq -r .clientSecret)"
```

A `FAIL` on `system.compute.clusters` is expected — this module intentionally doesn't grant `system.compute` (see grant list above). Only `system.billing.usage`, `system.billing.list_prices`, and `system.access.workspaces_latest` need to pass.

## Reference

Auto-generated by `terraform-docs` via the `terraform_docs` pre-commit hook — do not edit by hand, run `pre-commit run terraform_docs --all-files` to regenerate.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_databricks"></a> [databricks](#requirement\_databricks) | >= 1.121.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_databricks"></a> [databricks](#provider\_databricks) | 1.121.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [databricks_grant.system_access_use_schema](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_grant.system_access_workspaces_latest_select](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_grant.system_billing_list_prices_select](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_grant.system_billing_usage_select](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_grant.system_billing_use_schema](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_ip_access_list.umbrellacost_static_ips](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/ip_access_list) | resource |
| [databricks_permissions.sp_usage_of_warehouse](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/permissions) | resource |
| [databricks_service_principal.umbrellacost_billing_sp](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/service_principal) | resource |
| [databricks_service_principal_secret.umbrellacost_billing_sp_credentials](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/service_principal_secret) | resource |
| [databricks_sql_endpoint.umbrellacost_billing_warehouse](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/sql_endpoint) | resource |
| [databricks_workspace_conf.enable_ip_access_lists](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/workspace_conf) | resource |
| [databricks_current_metastore.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/current_metastore) | data source |
| [databricks_schema.system_access](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/schema) | data source |
| [databricks_schema.system_billing](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/schema) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_ip_allowlist"></a> [enable\_ip\_allowlist](#input\_enable\_ip\_allowlist) | Enable IP allowlist restricting Databricks workspace access to Umbrellacost's static egress IPs. Requires umbrellacost\_static\_ips to be set. | `bool` | `false` | no |
| <a name="input_umbrellacost_static_ips"></a> [umbrellacost\_static\_ips](#input\_umbrellacost\_static\_ips) | Umbrellacost's static egress IP addresses, allowlisted when enable\_ip\_allowlist = true. Must be populated with real values before enabling — left empty by default | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_metastore_name"></a> [metastore\_name](#output\_metastore\_name) | Metastore attached to this workspace — confirm Metastore Admin is set on this exact metastore (see README Prerequisites) before apply |
| <a name="output_service_principal_id"></a> [service\_principal\_id](#output\_service\_principal\_id) | OAuth Client ID of the Umbrellacost billing service principal |
| <a name="output_service_principal_secret"></a> [service\_principal\_secret](#output\_service\_principal\_secret) | OAuth secret of the Umbrellacost billing service principal |
| <a name="output_umbrellacost_billing_warehouse_id"></a> [umbrellacost\_billing\_warehouse\_id](#output\_umbrellacost\_billing\_warehouse\_id) | ID of the Umbrellacost billing SQL Warehouse |
<!-- END_TF_DOCS -->
