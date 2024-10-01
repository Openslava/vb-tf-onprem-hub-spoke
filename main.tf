data "azurerm_client_config" "current" {}
terraform {

  required_version = ">=1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.2"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "core"
}