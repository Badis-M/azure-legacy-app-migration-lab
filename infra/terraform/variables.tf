variable "location" {
  description = "Azure region where resources will be created."
  type        = string
  default     = "francecentral"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
  default     = "azure-legacy-migration-lab"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag for FinOps tracking."
  type        = string
}

variable "acr_name" {
  description = "Globally unique Azure Container Registry name. Lowercase letters and numbers only."
  type        = string
}

variable "aks_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-azure-legacy-migration-dev"
}

variable "aks_dns_prefix" {
  description = "AKS DNS prefix."
  type        = string
  default     = "aks-azlegacy-dev"
}

variable "aks_node_count" {
  description = "AKS default node pool node count."
  type        = number
  default     = 1
}

variable "aks_node_resource_group_name" {
  description = "Short name for the AKS managed node resource group."
  type        = string
  default     = "rg-aksnodes-azmig-dev"
}

variable "aks_location" {
  description = "Azure region for the AKS cluster."
  type        = string
  default     = "westeurope"
}

variable "aks_node_vm_size" {
  description = "AKS default node pool VM size."
  type        = string
  default     = "Standard_B2s"
}
