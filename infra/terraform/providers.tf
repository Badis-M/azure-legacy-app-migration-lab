terraform {
  required_version = ">= 1.6.0"

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-azure-migration-lab-dev"
    storage_account_name = "sttfstatebadisazmig001"
    container_name       = "tfstate"
    key                  = "azure-legacy-migration-lab/dev.tfstate"
    use_azuread_auth     = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}
