##### Public IP Required to multizone deployment depending on var.multizone boolean variable############################

resource "azurerm_public_ip" "public-ip1" {
  count               = var.apim == "True" ? 1 : 0
  name                = "apim-${var.prefix}-spoke1-feip1"
  location            = azurerm_resource_group.spoke1-rg.location
  resource_group_name = azurerm_resource_group.spoke1-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "apim1-${var.prefix}"
}

##### Conditional multizone deployment depending on var.multizone boolean variable#########################################

# https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview
# no service endpoints only service tag on subnet
data "azurerm_subnet" "spoke1-apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.spoke1-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  depends_on           = [azurerm_virtual_network.spoke1-vnet]
}


resource "azurerm_api_management" "apim1" {
  count                = var.apim == "True" ? 1 : 0
  name                 = "apim-${var.prefix}-spoke1"
  location             = azurerm_resource_group.spoke1-rg.location
  resource_group_name  = azurerm_resource_group.spoke1-rg.name
  publisher_name       = "test"
  publisher_email      = "test@test.com"
  sku_name             = "Developer_1"
  virtual_network_type = "Internal"
  zones                = null
  public_ip_address_id = azurerm_public_ip.public-ip1[count.index].id

  virtual_network_configuration {
    subnet_id = data.azurerm_subnet.spoke1-apim.id
  }

  depends_on = [data.azurerm_subnet.spoke1-apim, azurerm_resource_group.spoke1-rg, azurerm_public_ip.public-ip1]

  # tags, introduced new Azure Policy and misaligment of tags on RGs is preventing deployment in TEST and PROD for TAGS
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_security_group" "spoke1-apim-nsg" {
  name                = "nsg-${local.prefix-spoke1}-apim"
  location            = azurerm_resource_group.spoke1-rg.location
  resource_group_name = azurerm_resource_group.spoke1-rg.name

  # https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet?tabs=stv2#configure-nsg-rules
  security_rule {
    name                       = "Block-All-Traffic"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "general-ports"
    priority                   = 4094
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["443", "80", "22"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAPIMManagementEndpoint"
    priority                   = 4093
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "ApiManagement"
    destination_port_ranges    = ["3443"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-All-LoadBalancer-Inbound"
    priority                   = 4095
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_port_range     = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-All-LoadBalancer-Inbound"
    priority                   = 4095
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_port_range     = "*"
    destination_address_prefix = "VirtualNetwork"
  }


  tags = {
    environment = "spoke1"
  }
}


