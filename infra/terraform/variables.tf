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
