# -----------------------------------------------------------------------------
# Values needed to connect this Databricks account to Umbrellacost. Provide
# these when you complete onboarding — this module does not submit them
# anywhere on its own.
# -----------------------------------------------------------------------------

output "client_id" {
  description = "OAuth Client ID of the Umbrellacost billing service principal"
  value       = databricks_service_principal.umbrellacost_billing_sp.application_id
}

output "client_secret" {
  description = "OAuth secret of the Umbrellacost billing service principal"
  value       = databricks_service_principal_secret.umbrellacost_billing_sp_credentials.secret
  sensitive   = true
}

output "warehouse_id" {
  description = "ID of the Umbrellacost billing SQL Warehouse"
  value       = databricks_sql_endpoint.umbrellacost_billing_warehouse.id
}

output "workspace_url" {
  description = "Echoes var.workspace_url — included so terraform output -json has this alongside the other onboarding values"
  value       = var.workspace_url
}

output "account_id" {
  description = "Echoes var.account_id — included so terraform output -json has this alongside the other onboarding values"
  value       = var.account_id
}

output "metastore_name" {
  description = "Metastore attached to this workspace — confirm Metastore Admin is set on this exact metastore (see README Prerequisites) before apply"
  value       = data.databricks_current_metastore.this.metastore_info[0].name
}

output "creds" {
  description = "Bundles client_id/client_secret/warehouse_id/workspace_url/account_id into one flat object — `terraform output -json creds` returns it unwrapped (no jq needed to strip the {value, sensitive} wrapper), for pasting into the Umbrellacost onboarding wizard"
  value = {
    client_id     = databricks_service_principal.umbrellacost_billing_sp.application_id
    client_secret = databricks_service_principal_secret.umbrellacost_billing_sp_credentials.secret
    warehouse_id  = databricks_sql_endpoint.umbrellacost_billing_warehouse.id
    workspace_url = var.workspace_url
    account_id    = var.account_id
  }
  sensitive = true
}
