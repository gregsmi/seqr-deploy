variable "resource_group" {
  description = "Resource group in which to place cluster."
  type = object({
    name     = string
    location = string
  })
}

variable "node_resource_group_name" {
  description = "Name to use for AKS-created node resource group."
  type        = string
}

variable "subnet_id" {
  description = "ID of subnet for Kubernetes to use."
  type        = string
}

variable "secrets" {
  description = "Map of secrets (name => contents) to create within cluster."
  type        = map(any)
}

variable "default_vm_size" {
  description = "VM size to use for default node pool."
  type        = string
}

variable "min_compute_nodes" {
  description = "Minimum number of nodes to run in the compute pool."
  type        = number
}

variable "min_data_nodes" {
  description = "Minimum number of nodes to run in the data pool."
  type        = number
}

variable "compute_vm_size" {
  description = "VM size to use for compute node pool."
  type        = string
}

variable "data_vm_size" {
  description = "VM size to use for data node pool."
  type        = string
}
