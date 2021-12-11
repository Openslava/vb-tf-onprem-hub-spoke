# define local variables
locals {
  resourceGroupName  = "rg-${var.prefix}-apim-${var.environment}-${var.region}"
  storageAccountName = "sa${var.prefix}apim${var.environment}${var.region}"
}

# create resource group
resource "azurerm_resource_group" "rg" {
  name     = local.resourceGroupName
  location = var.location
  # tags     = var.tags
}

