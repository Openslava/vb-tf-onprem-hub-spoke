locals {
  spoke1-location       = var.location
  prefix-spoke1         = "${var.prefix}-spoke1"
  spoke1-resource-group = "rg-${local.prefix-spoke1}-${var.region}"
  spoke1-vmname         = "vm${var.prefix}spoke1"
}

resource "azurerm_resource_group" "spoke1-rg" {
  name     = local.spoke1-resource-group
  location = local.spoke1-location
}

# ------- Route Tables spoke1 ----------
resource "azurerm_route_table" "spoke1-rt" {
  name                          = "rt-${local.prefix-spoke1}"
  location                      = azurerm_resource_group.spoke1-rg.location
  resource_group_name           = azurerm_resource_group.spoke1-rg.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.36"
  }

  tags = {
    environment = local.prefix-hub-nva
  }
}

# https://learn.microsoft.com/en-us/azure/virtual-network/service-tags-overview
resource "azurerm_route_table" "spoke1-rt-apim" {
  name                          = "rt-${local.prefix-spoke1}-apim"
  location                      = azurerm_resource_group.spoke1-rg.location
  resource_group_name           = azurerm_resource_group.spoke1-rg.name
  bgp_route_propagation_enabled = false

  #apim specific
  route {
    name           = "default-ApiManagement"
    address_prefix = "ApiManagement"
    next_hop_type  = "Internet"
  }

  # use service endpoint instead of all 
  route {
    name           = "default-AzureCloud"
    address_prefix = "AzureCloud"
    next_hop_type  = "Internet"
  }


  route {
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.36"
  }


  tags = {
    environment = local.prefix-hub-nva
  }
}

# ------- VNET spoke1 ----------
resource "azurerm_virtual_network" "spoke1-vnet" {
  name                = "vnet-${local.prefix-spoke1}"
  location            = azurerm_resource_group.spoke1-rg.location
  resource_group_name = azurerm_resource_group.spoke1-rg.name
  address_space       = ["10.1.0.0/16"]

  subnet {
    name             = "mgmt"
    address_prefixes = ["10.1.0.64/27"]
    route_table_id   = azurerm_route_table.spoke1-rt.id
  }

  subnet {
    name             = "dmz"
    address_prefixes = ["10.1.0.32/27"]
  }
  subnet {
    name             = "workload"
    address_prefixes = ["10.1.1.0/24"]
    route_table_id   = azurerm_route_table.spoke1-rt.id
  }

  subnet {
    name             = "AzureFirewallSubnet"
    address_prefixes = ["10.1.2.0/26"]
  }

  # setup apim subnet wihtout service endpoint require routing tables
  subnet {
    name             = "apim"
    address_prefixes = ["10.1.3.0/26"]
    security_group   = azurerm_network_security_group.spoke1-apim-nsg.id
    route_table_id   = azurerm_route_table.spoke1-rt-apim.id
    # service_endpoints    =  ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.AzureActiveDirectory", "Microsoft.Sql", "Microsoft.CognitiveServices", "Microsoft.EventHub", "Microsoft.ServiceBus"]
  }

  tags = {
    environment = local.prefix-spoke1
  }
}

# ----- peering ------
resource "azurerm_virtual_network_peering" "spoke1-hub-peer" {
  name                      = "peer-${local.prefix-spoke1}-spoke1-hub"
  resource_group_name       = azurerm_resource_group.spoke1-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke1-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on = [
    azurerm_virtual_network.spoke1-vnet,
    azurerm_virtual_network.hub-vnet,
  ]
}

resource "azurerm_virtual_network_peering" "hub-spoke1-peer" {
  name                         = "peer-${var.prefix}-hub-spoke1"
  resource_group_name          = azurerm_resource_group.hub-rg.name
  virtual_network_name         = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on = [
    azurerm_virtual_network.spoke1-vnet,
    azurerm_virtual_network.hub-vnet
  ]
}
