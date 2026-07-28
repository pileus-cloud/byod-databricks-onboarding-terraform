# Ready-to-run onboarding config for terraform-databricks-umbrellacost-integration.
# Clone this repo, cd into this folder, and run `terraform apply` — the
# actual reusable module lives in ../module. Creates real resources in your
# Databricks workspace.

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.121.0"
    }
  }
  required_version = ">= 1.0"
}

variable "databricks_workspace_url" {
  type        = string
  description = "Workspace URL, e.g. https://dbc-xxxxxx.cloud.databricks.com"
}

variable "databricks_token" {
  type        = string
  description = "Personal access token with Account Admin + Metastore Admin privileges"
  sensitive   = true
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks Account ID (from the Accounts Console)"
}

provider "databricks" {
  host  = var.databricks_workspace_url
  token = var.databricks_token
}

module "umbrellacost_integration" {
  source        = "../module"
  workspace_url = var.databricks_workspace_url
  account_id    = var.databricks_account_id
  # enable_ip_allowlist     = true
  # umbrellacost_static_ips = ["1.2.3.4/32"]
}

# Trivial passthroughs — the module's own outputs are already named to match
# what the Umbrellacost wizard expects, so no aliasing needed here.
output "client_id" {
  value = module.umbrellacost_integration.client_id
}

output "client_secret" {
  value     = module.umbrellacost_integration.client_secret
  sensitive = true
}

output "warehouse_id" {
  value = module.umbrellacost_integration.warehouse_id
}

output "workspace_url" {
  value = module.umbrellacost_integration.workspace_url
}

output "account_id" {
  value = module.umbrellacost_integration.account_id
}

output "metastore_name" {
  value = module.umbrellacost_integration.metastore_name
}

output "creds" {
  value     = module.umbrellacost_integration.creds
  sensitive = true
}
