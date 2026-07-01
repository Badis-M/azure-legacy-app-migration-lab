locals {
  resource_group_name = "rg-${var.project_name}-${var.environment}"

  common_tags = {
    project     = var.project_name
    environment = var.environment
    owner       = var.owner
    managed_by  = "terraform"
    cost_center = "learning-lab"
  }
}

module "resource_group" {
  source = "./modules/resource-group"

  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "acr" {
  source = "./modules/acr"

  name                = var.acr_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.common_tags
}

module "aks" {
  source = "./modules/aks"

  name                     = var.aks_name
  location                 = var.aks_location
  resource_group_name      = module.resource_group.name
  dns_prefix               = var.aks_dns_prefix
  node_resource_group_name = var.aks_node_resource_group_name
  node_count               = var.aks_node_count
  node_vm_size             = var.aks_node_vm_size
  acr_id                   = module.acr.id
  tags                     = local.common_tags
}
