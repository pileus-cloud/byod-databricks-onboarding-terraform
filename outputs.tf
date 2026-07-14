# -----------------------------------------------------------------------------
# Outputs to enter in Umbrellacost onboarding (byod-mgmt account provider_config
# / Secrets Manager secret)
# -----------------------------------------------------------------------------

output "service_principal_id" {
  description = "OAuth Client ID of the Umbrellacost billing service principal"
  value       = databricks_service_principal.umbrellacost_billing_sp.application_id
}

output "service_principal_secret" {
  description = "OAuth secret of the Umbrellacost billing service principal"
  value       = databricks_service_principal_secret.umbrellacost_billing_sp_credentials.secret
  sensitive   = true
}

output "umbrellacost_billing_warehouse_id" {
  description = "ID of the Umbrellacost billing SQL Warehouse"
  value       = databricks_sql_endpoint.umbrellacost_billing_warehouse.id
}

output "metastore_name" {
  description = "Metastore attached to this workspace — confirm Metastore Admin is set on this exact metastore (see README Prerequisites) before apply"
  value       = data.databricks_current_metastore.this.metastore_info[0].name
}
