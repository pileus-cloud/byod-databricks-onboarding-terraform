# Local test harness for terraform-databricks-umbrellacost-integration.
# Not part of the module itself — creates real resources in the target
# Databricks workspace. Run `terraform destroy` when done testing.

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.121.0"
    }
  }
  required_version = ">= 1.0"
}

variable "databricks_host" {
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
  host  = var.databricks_host
  token = var.databricks_token
}

module "umbrellacost_integration" {
  source = "../../"
  # enable_ip_allowlist     = true
  # umbrellacost_static_ips = ["1.2.3.4/32"]
}

output "client_id" {
  value = module.umbrellacost_integration.service_principal_id
}

output "client_secret" {
  value     = module.umbrellacost_integration.service_principal_secret
  sensitive = true
}

output "warehouse_id" {
  value = module.umbrellacost_integration.umbrellacost_billing_warehouse_id
}

output "workspace_url" {
  value = var.databricks_host
}

output "account_id" {
  value = var.databricks_account_id
}

output "metastore_name" {
  value = module.umbrellacost_integration.metastore_name
}
