
##### Public IP Required to multizone deployment depending on var.multizone boolean variable############################

resource "azurerm_public_ip" "public-ip2" {
  count               = var.apim == "True" ? 1 : 0
  name                = "apim-${var.prefix}-spoke2-feip1"
  location            = azurerm_resource_group.spoke2-rg.location
  resource_group_name = azurerm_resource_group.spoke2-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "apim2-${var.prefix}"
}


data "azurerm_subnet" "spoke2-apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.spoke2-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  depends_on           = [azurerm_virtual_network.spoke2-vnet]
}

##### Conditional multizone deployment depending on var.multizone boolean variable#########################################

resource "azurerm_api_management" "apim2" {
  count                = var.apim == "True" ? 1 : 0
  name                 = "apim-${var.prefix}-spoke2"
  location             = azurerm_resource_group.spoke2-rg.location
  resource_group_name  = azurerm_resource_group.spoke2-rg.name
  publisher_name       = "test"
  publisher_email      = "test@test.com"
  sku_name             = "Developer_1"
  virtual_network_type = "Internal"
  zones                = null
  public_ip_address_id = azurerm_public_ip.public-ip2[count.index].id


  virtual_network_configuration {
    subnet_id = data.azurerm_subnet.spoke2-apim.id
  }

  # to ensure the hub spoke is in place
  depends_on = [
    azurerm_virtual_network_peering.hub-spoke2-peer,
    azurerm_virtual_network_peering.spoke2-hub-peer,
    azurerm_public_ip.public-ip2
  ]

  # tags, introduced new Azure Policy and misaligment of tags on RGs is preventing deployment in TEST and PROD for TAGS
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

# --- NSGs ---

resource "azurerm_network_security_group" "spoke2-apim-nsg" {
  name                = "nsg-${local.prefix-spoke2}-apim"
  location            = azurerm_resource_group.spoke2-rg.location
  resource_group_name = azurerm_resource_group.spoke2-rg.name

  # https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet?tabs=stv2#configure-nsg-rules
  # only inbound trafic is fildered 
  # default outboud trafic is used instead of specific considerations
  # -65000 - Allow - Any-Any-Vnet-VNET
  # -65001 -Allow  - Any-Any-Any-Internet
  security_rule {
    name                       = "Allog_Inbound_https"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["443"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Inbound_ApiManagement"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "ApiManagement"
    destination_port_ranges    = ["3443"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Inbound_RedisCache"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["6381", "6382", "6383"]
    destination_address_prefix = "VirtualNetwork"
  }


  security_rule {
    name                       = "Allow_Inbound_RedisLimit"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["4290"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Inbound_AzureLoadBalancer"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_port_ranges    = ["6390"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allog_Inbound_SyncCounters"
    priority                   = 1140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["4290"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Deny-Any-Inbound"
    priority                   = 2000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "spoke2"
  }
}

