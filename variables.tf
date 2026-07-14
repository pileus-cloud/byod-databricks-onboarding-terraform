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
