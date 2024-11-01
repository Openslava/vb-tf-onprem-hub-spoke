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

  # to ensure the hub spoke is in place
  depends_on = [
    azurerm_virtual_network_peering.hub-spoke1-peer,
    azurerm_virtual_network_peering.spoke1-hub-peer,
    azurerm_public_ip.public-ip1
  ]

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
    name                       = "Allow_Inbount_https_VirtualNetwork"
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
    name                       = "Allow_Inbound_Redis_Cache"
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
    name                       = "Allow_Outbound_Redis_Cache"
    priority                   = 1020
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["6381", "6382", "6383"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Inbound_Redis_Limit"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["4290"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Outbound_Redis_Limit"
    priority                   = 1040
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["4290"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Outbound_Sql"
    priority                   = 1050
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["1433"]
    destination_address_prefix = "Sql"
  }

  security_rule {
    name                       = "Allow_Outbound_EventHub"
    priority                   = 1060
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["5671"]
    destination_address_prefix = "EventHub"
  }

  # 445 for git deployment, 443 for table access
  security_rule {
    name                       = "Allow_Outbound_Storage"
    priority                   = 1080
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["443", "445"]
    destination_address_prefix = "Storage"
  }


  security_rule {
    name                       = "Allow_Inbound_AzureLoadBalancer"
    priority                   = 1080
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_port_range     = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow_Outbound_AzureMonitor"
    priority                   = 1090
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["443", "1886"]
    destination_address_prefix = "AzureMonitor"
  }

  security_rule {
    name                       = "Allow_Outbound_AzureKeyVault"
    priority                   = 1100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["443"]
    destination_address_prefix = "AzureKeyVault"
  }

  security_rule {
    name                       = "Allow_Outbound_AzureActiveDirectory"
    priority                   = 1110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["443"]
    destination_address_prefix = "AzureActiveDirectory"
  }

  security_rule {
    name                       = "Allow_Outbound_VirtualNetwork"
    priority                   = 1200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["22", "443"]
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

  security_rule {
    name                       = "Deny-Any-Outbound"
    priority                   = 2010
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }


  tags = {
    environment = "spoke1"
  }
}


