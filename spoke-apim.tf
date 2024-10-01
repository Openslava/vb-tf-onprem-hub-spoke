# define local variables
locals {
  resourceGroupName = "rg-${var.prefix}-apim-${var.region}"
}

# create resource group
resource "azurerm_resource_group" "rg-apim" {
  name     = local.resourceGroupName
  location = var.location
  # tags     = var.tags
}

#---------------------------
# MS native - cytric 
#
# PURPOSE: APIM
#
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management

locals {
  multizone = null
}

##### Public IP Required to multizone deployment depending on var.multizone boolean variable############################

resource "azurerm_public_ip" "public-ip" {
  count               = var.apim == "True" ? 1 : 0
  name                = "apim-${var.prefix}-feip"
  location            = azurerm_resource_group.rg-apim.location
  resource_group_name = azurerm_resource_group.rg-apim.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "apim-${var.prefix}"
}

##### Conditional multizone deployment depending on var.multizone boolean variable#########################################

resource "azurerm_api_management" "apim" {
  count                = var.apim == "True" ? 1 : 0
  name                 = "apim-${var.prefix}"
  location             = azurerm_resource_group.rg-apim.location
  resource_group_name  = azurerm_resource_group.rg-apim.name
  publisher_name       = "vb"
  publisher_email      = "viliam@batka.name"
  sku_name             = "Developer_1"
  virtual_network_type = "Internal"
  zones                = null
  public_ip_address_id = azurerm_public_ip.public-ip[count.index].id
  

  virtual_network_configuration {
    subnet_id = azurerm_subnet.spoke1-apim.id
  }

  depends_on = [azurerm_subnet.spoke1-apim, azurerm_resource_group.rg-apim]

  # tags, introduced new Azure Policy and misaligment of tags on RGs is preventing deployment in TEST and PROD for TAGS
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_security_rule" "apim_nsg_rule0" {
  resource_group_name         = azurerm_network_security_group.spoke1-apim-nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke1-apim-nsg.name
      name                       = "general-ports"
      priority                   = 4094
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      source_address_prefix      = "*"
      destination_port_ranges    = ["443","80", "22"]
      destination_address_prefix = "VirtualNetwork"
}

resource "azurerm_network_security_rule" "apim_nsg_rule1" {
  resource_group_name         = azurerm_network_security_group.spoke1-apim-nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke1-apim-nsg.name
  name                        = "AllowAPIMManagementEndpoint"
  priority                    = 4093
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "ApiManagement"
  destination_port_ranges     = ["3443"]
  destination_address_prefix  = "VirtualNetwork"
  depends_on                  = [azurerm_network_security_group.spoke1-apim-nsg]
}

resource "azurerm_network_security_rule" "apim_nsg_rule2" {
  resource_group_name         = azurerm_network_security_group.spoke1-apim-nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke1-apim-nsg.name
  name                        = "Allow-All-LoadBalancer-Inbound"
  priority                    = 4095
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_port_range      = "*"
  destination_address_prefix  = "VirtualNetwork"
  depends_on                  = [azurerm_network_security_group.spoke1-apim-nsg]
}

resource "azurerm_network_security_rule" "apim_nsg_rule3" {
  resource_group_name         = azurerm_network_security_group.spoke1-apim-nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke1-apim-nsg.name
  name                        = "Block-All-Traffic"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "*"
  destination_address_prefix  = "*"
  depends_on                  = [azurerm_network_security_group.spoke1-apim-nsg]
}



