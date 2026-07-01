variable "name" {
  description = "Azure Container Registry name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku" {
  description = "ACR SKU."
  type        = string
  default     = "Basic"
}

variable "admin_enabled" {
  description = "Whether the ACR admin user is enabled."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
}
