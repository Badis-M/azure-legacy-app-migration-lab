variable "name" {
  description = "AKS cluster name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group name."
  type        = string
}

variable "dns_prefix" {
  description = "AKS DNS prefix."
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "VM size for the AKS default node pool."
  type        = string
  default     = "Standard_B2s"
}

variable "acr_id" {
  description = "Azure Container Registry resource ID."
  type        = string
}

variable "node_resource_group_name" {
  description = "Short name for the AKS managed node resource group."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
}
