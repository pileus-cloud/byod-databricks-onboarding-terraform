<p align="center">
  <img src="img/logo.png" alt="Umbrella" width="275">
</p>

# terraform-databricks-umbrellacost-integration

This module provisions all resources and permissions required to integrate your Databricks account with Umbrellacost. It runs entirely in **customer** Databricks account/workspace — it does not talk to Umbrellacost or submit anything anywhere.

## Contents

- [What This Module Does](#what-this-module-does)
- [Prerequisites](#prerequisites)
- [Onboarding](#onboarding)
- [Reference](#reference)

## What This Module Does

1. Create a Service Principal (`umbrellacost-billing-sp`)
2. Create OAuth credentials for the Service Principal
3. Create a SQL Warehouse (`umbrellacost-billing-warehouse`)
4. Assign the Service Principal permissions to use the SQL Warehouse
5. Grant the Service Principal `USE_SCHEMA` on `system.billing` and `system.access`, plus table-level `SELECT` on exactly `system.billing.usage`, `system.billing.list_prices`, and `system.access.workspaces_latest` — mirrors the manual GRANT statements in the onboarding README/CUSTOMER_SETUP_GUIDE exactly. `system.access` is intentionally **not** granted schema-wide, since that would also expose `system.access.audit` (the full user audit log). `system.compute` is not granted at all — it's for a tag-enrichment feature that isn't implemented in the export container yet.

Optionally set `enable_ip_allowlist = true` (module variable) to restrict workspace access to a set of static egress IPs, passed via `umbrellacost_static_ips`.

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

## Onboarding

1. Clone this repo and `cd onboarding/`.
2. Set `databricks_host` and `databricks_account_id` (in `terraform.tfvars`, or answer the prompts interactively) and run `terraform apply` (see [Prerequisites](#prerequisites)). `onboarding/` is a ready-to-run config — the reusable module itself lives in `module/`, referenced via `source = "../module"`, so there's nothing to write yourself.
3. Run `terraform output -json creds | jq`.
4. In the Umbrellacost onboarding wizard, choose **Automatically (Terraform)** and paste the result into the **Terraform output JSON** field. Umbrellacost parses the credentials and validates connectivity automatically — no manual GRANTs, no separate credential entry.

This repo only sets up your Databricks side — it doesn't submit these values anywhere itself; pasting the output into the wizard is the step that does.

The `creds` output bundles `client_id`, `client_secret`, `warehouse_id`, `workspace_url`, and `account_id` into one flat object — `terraform output -json creds` returns it unwrapped, with exactly the 5 keys the wizard needs.

### Example

This is the exact output to paste into the **Terraform output JSON** field in the Umbrellacost onboarding wizard:

```
$ terraform output -json creds | jq
{
  "account_id": "00000000-0000-0000-0000-000000000000",
  "client_id": "11111111-1111-1111-1111-111111111111",
  "client_secret": "dose0000000000000000000000000000",
  "warehouse_id": "0123456789abcdef",
  "workspace_url": "https://dbc-xxxxxxxx-xxxx.cloud.databricks.com"
}
```

### Local verification (optional)

Before pasting into the wizard, you can sanity-check connectivity yourself with the vendored test script:

```bash
CREDS=$(terraform output -json creds)
python ../test-connection/test_databricks_connection.py \
  --host "$(echo $CREDS | jq -r .workspace_url)" \
  --warehouse_id "$(echo $CREDS | jq -r .warehouse_id)" \
  --client_id "$(echo $CREDS | jq -r .client_id)" \
  --client_secret "$(echo $CREDS | jq -r .client_secret)"
```

A `FAIL` on `system.compute.clusters` is expected — this module intentionally doesn't grant `system.compute` (see [What This Module Does](#what-this-module-does)). Only `system.billing.usage`, `system.billing.list_prices`, and `system.access.workspaces_latest` need to pass.

## Reference

Requirements, providers, resources, inputs, and outputs are auto-generated from the Terraform source — see [TERRAFORM_DOCS.md](./TERRAFORM_DOCS.md).
