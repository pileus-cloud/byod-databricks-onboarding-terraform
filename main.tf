# -----------------------------------------------------------------------------
# Terraform Configuration for Umbrellacost Integration with Databricks
#
# This script sets up a Databricks Service Principal with access to system
# schemas and a SQL Warehouse for billing-related data collection. It also
# configures necessary permissions and access controls.
#
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
      # https://github.com/databricks/terraform-provider-databricks/releases/tag/${version}
      # this version allows for service principal creation at the workspace level
      version = ">= 1.121.0"
    }
  }
  required_version = ">= 1.0"
}

# -----------------------------------------------------------------------------
# Create a service principal for Umbrellacost to use within the Databricks
# workspace. Name matches the convention used in Umbrellacost onboarding docs.
# -----------------------------------------------------------------------------
resource "databricks_service_principal" "umbrellacost_billing_sp" {
  display_name          = "umbrellacost-billing-sp"
  databricks_sql_access = true
  workspace_access      = true
  active                = true
}

# -----------------------------------------------------------------------------
# Generate a secret (client credentials) for the service principal in the
# account scope.
# -----------------------------------------------------------------------------
resource "databricks_service_principal_secret" "umbrellacost_billing_sp_credentials" {
  service_principal_id = databricks_service_principal.umbrellacost_billing_sp.id
}

# -----------------------------------------------------------------------------
# Create a serverless SQL Warehouse that Umbrellacost will use to run billing
# queries.
# -----------------------------------------------------------------------------
resource "databricks_sql_endpoint" "umbrellacost_billing_warehouse" {
  name                      = "umbrellacost-billing-warehouse"
  cluster_size              = "2X-Small"
  enable_serverless_compute = true
  max_num_clusters          = 1
  auto_stop_mins            = 5
}

# -----------------------------------------------------------------------------
# Grant the service principal permission to use the SQL Warehouse.
# -----------------------------------------------------------------------------
resource "databricks_permissions" "sp_usage_of_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.umbrellacost_billing_warehouse.id

  access_control {
    service_principal_name = databricks_service_principal.umbrellacost_billing_sp.application_id
    permission_level       = "CAN_USE"
  }
}

# -----------------------------------------------------------------------------
# Enable IP access lists restricting workspace access to Umbrellacost's static
# egress IPs
# -----------------------------------------------------------------------------
resource "databricks_workspace_conf" "enable_ip_access_lists" {
  count = var.enable_ip_allowlist ? 1 : 0

  custom_config = {
    "enableIpAccessLists" = true
  }
}

resource "databricks_ip_access_list" "umbrellacost_static_ips" {
  count = var.enable_ip_allowlist ? 1 : 0

  label        = "allow_in"
  list_type    = "ALLOW"
  ip_addresses = var.umbrellacost_static_ips
  depends_on   = [databricks_workspace_conf.enable_ip_access_lists]
}

# -----------------------------------------------------------------------------
# Metastore attached to this workspace. Purely informational (see the
# metastore_name output) — grants below resolve against it automatically,
# nothing here needs to reference it explicitly. Surfaced because Metastore
# Admin has to be set on this exact metastore before apply will succeed
# (see README Prerequisites), and it's otherwise only visible in the Account
# Console.
# -----------------------------------------------------------------------------
data "databricks_current_metastore" "this" {}

# -----------------------------------------------------------------------------
# Reference to the 'system.billing' schema, which contains billing data.
#
# Only USE_SCHEMA is granted at schema level. SELECT is granted per-table below
# — matches our documented least-privilege GRANT statements (README /
# CUSTOMER_SETUP_GUIDE), not the schema-wide SELECT the upstream Umbrellacost
# module used.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_billing" {
  name = "system.billing"
}

resource "databricks_grant" "system_billing_use_schema" {
  schema     = data.databricks_schema.system_billing.id
  principal  = databricks_service_principal.umbrellacost_billing_sp.application_id
  privileges = ["USE_SCHEMA"]
}

resource "databricks_grant" "system_billing_usage_select" {
  table      = "system.billing.usage"
  principal  = databricks_service_principal.umbrellacost_billing_sp.application_id
  privileges = ["SELECT"]
}

resource "databricks_grant" "system_billing_list_prices_select" {
  table      = "system.billing.list_prices"
  principal  = databricks_service_principal.umbrellacost_billing_sp.application_id
  privileges = ["SELECT"]
}

# -----------------------------------------------------------------------------
# 'system.compute' is intentionally NOT granted here. Tag enrichment from
# system.compute.clusters/warehouses is a planned export feature, not yet
# implemented — see IMPLEMENTATION_CHECKLIST. Add a grant when that ships.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Reference to the 'system.access' schema, used for workspace name enrichment.
#
# SELECT is scoped to workspaces_latest only — do NOT grant SELECT on the
# whole schema. system.access also contains system.access.audit (the full
# user audit log), which must never be exposed.
# -----------------------------------------------------------------------------
data "databricks_schema" "system_access" {
  name = "system.access"
}

resource "databricks_grant" "system_access_use_schema" {
  schema     = data.databricks_schema.system_access.id
  principal  = databricks_service_principal.umbrellacost_billing_sp.application_id
  privileges = ["USE_SCHEMA"]
}

resource "databricks_grant" "system_access_workspaces_latest_select" {
  table      = "system.access.workspaces_latest"
  principal  = databricks_service_principal.umbrellacost_billing_sp.application_id
  privileges = ["SELECT"]
}
