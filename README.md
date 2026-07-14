# terraform-databricks-umbrellacost-integration

This module provisions all resources and permissions required to integrate your Databricks account with Umbrellacost.

At a high level, the module will:

1. Create a Service Principal (`umbrellacost-billing-sp`)
2. Create OAuth credentials for the Service Principal
3. Create a SQL Warehouse (`umbrellacost-billing-warehouse`)
4. Assign the Service Principal permissions to use the SQL Warehouse
5. Grant the Service Principal `USE_SCHEMA` on `system.billing` and `system.access`, plus table-level `SELECT` on exactly `system.billing.usage`, `system.billing.list_prices`, and `system.access.workspaces_latest` — mirrors the manual GRANT statements in the onboarding README/CUSTOMER_SETUP_GUIDE exactly. `system.access` is intentionally **not** granted schema-wide, since that would also expose `system.access.audit` (the full user audit log). `system.compute` is not granted at all — it's for a tag-enrichment feature that isn't implemented in the export container yet.

After applying this module, the outputs (`service_principal_id`, `service_principal_secret`, `umbrellacost_billing_warehouse_id`) feed directly into the Umbrellacost onboarding secret:

```json
{
  "clientId": "<service_principal_id output>",
  "clientSecret": "<service_principal_secret output>",
  "workspaceUrl": "<your workspace URL>",
  "warehouseId": "<umbrellacost_billing_warehouse_id output>",
  "accountId": "<your Databricks Account ID>"
}
```

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

After `terraform apply`, build the onboarding secret JSON directly from the outputs — use `terraform output -json`, not plain `terraform output`, since the latter redacts `client_secret`:

```bash
SECRET=$(terraform output -json | jq -c '{
  clientId: .client_id.value,
  clientSecret: .client_secret.value,
  workspaceUrl: .workspace_url.value,
  warehouseId: .warehouse_id.value,
  accountId: .account_id.value
}')
```

Verify connectivity with the standalone test script before wiring the account into the real onboarding pipeline:

```bash
python test-connection/test_databricks_connection.py \
  --host "$(echo $SECRET | jq -r .workspaceUrl)" \
  --warehouse_id "$(echo $SECRET | jq -r .warehouseId)" \
  --client_id "$(echo $SECRET | jq -r .clientId)" \
  --client_secret "$(echo $SECRET | jq -r .clientSecret)"
```

A `FAIL` on `system.compute.clusters` is expected — this module intentionally doesn't grant `system.compute` (see grant list above). Only `system.billing.usage`, `system.billing.list_prices`, and `system.access.workspaces_latest` need to pass.
