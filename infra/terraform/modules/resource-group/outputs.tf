output "name" {
  description = "Resource Group name."
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Resource Group location."
  value       = azurerm_resource_group.main.location
}
