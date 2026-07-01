output "name" {
  description = "ACR name."
  value       = azurerm_container_registry.main.name
}

output "login_server" {
  description = "ACR login server."
  value       = azurerm_container_registry.main.login_server
}
