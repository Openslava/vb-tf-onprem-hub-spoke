# define local variables
locals {
  resourceGroupName = "rg-${var.prefix}-apim-${var.region}"
}

# create resource group
resource "azurerm_resource_group" "rg" {
  name     = local.resourceGroupName
  location = var.location
  # tags     = var.tags
}

