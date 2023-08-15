variable "deployment_name" {
  description = "Master deployment name, used as a prefix to derive various resource names."
  type        = string
  validation {
    condition = alltrue([
      can(regex("^[0-9a-z]+$", var.deployment_name)),
      length(var.deployment_name) >= 8,
      length(var.deployment_name) <= 16
    ])
    error_message = "Variable deployment_name must be 8-16 characters lowercase alphanumeric."
  }
}

variable "location" {
  description = "Azure region in which to create all resources."
  type        = string
}

variable "tenant_id" {
  description = "Tenant in which to create all resources."
  type        = string
}

variable "subscription_id" {
  description = "Subscription in which to create all resources."
  type        = string
}

# For a given deployment, put values for the following variables in a file named config.auto.tfvars.json.

# This is an optional set of IPs or IP blocks. It is used to control which 
# client IPs are allowed ingress to the container running the SEQR web interface.
variable "whitelisted_cidrs" {
  description = "Comma-separated list of CIDRs to whitelist for web access to SEQR."
  default     = "0.0.0.0/0"
  type        = string
}
# This is an optional set of mappings from storage account name to storage account resource group.
# It is used to add permission for the SEQR loader job to read/write dsta files in each storage account.
variable "data_storage_accounts" {
  description = "Map from storage account name to storage account resource group for data files."
  type        = map(string)
  default     = {}
}
