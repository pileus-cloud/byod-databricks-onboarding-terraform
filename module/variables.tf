variable "enable_ip_allowlist" {
  type        = bool
  default     = false
  description = "Enable IP allowlist restricting Databricks workspace access to Umbrellacost's static egress IPs. Requires umbrellacost_static_ips to be set."
}

variable "umbrellacost_static_ips" {
  type        = list(string)
  default     = []
  description = "Umbrellacost's static egress IP addresses, allowlisted when enable_ip_allowlist = true. Must be populated with real values before enabling — left empty by default"
}

variable "workspace_url" {
  type        = string
  description = "Your Databricks workspace URL, e.g. https://dbc-xxxxxx.cloud.databricks.com. Not used to configure the provider (that's the caller's responsibility) — passed through here purely so it's echoed back in the workspace_url output alongside the other onboarding values."
}

variable "account_id" {
  type        = string
  description = "Your Databricks Account ID (from the Account Console). Not fetchable via the workspace API — passed through here purely so it's echoed back in the account_id output alongside the other onboarding values."
}
