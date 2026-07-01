moved {
  from = azurerm_resource_group.main
  to   = module.resource_group.azurerm_resource_group.main
}

moved {
  from = azurerm_container_registry.main
  to   = module.acr.azurerm_container_registry.main
}
