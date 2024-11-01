
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

  depends_on = [data.azurerm_subnet.spoke2-apim, azurerm_resource_group.spoke2-rg, azurerm_public_ip.public-ip2]

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
    name                   = "Block-All-Traffic"
    priority               = 4096
    direction              = "Inbound"
    access                 = "Deny"
    protocol               = "*"
    source_port_range      = "*"
    source_address_prefix  = "*"
    destination_port_range = "*"
  }

  tags = {
    environment = "spoke2"
  }
}

