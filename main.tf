terraform {

  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.1"
    }
  }
}

provider "azurerm" {
  features {}
}