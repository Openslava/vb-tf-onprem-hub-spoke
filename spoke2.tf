locals {
  spoke2-location       = var.location
  prefix-spoke2         = "${var.prefix}-spoke2"
  spoke2-resource-group = "rg-${local.prefix-spoke2}-${var.region}"
  spoke2-vmname         = "vm${var.prefix}spoke2"
}

resource "azurerm_resource_group" "spoke2-rg" {
  name     = local.spoke2-resource-group
  location = local.spoke2-location
}

# --- route tables ---

resource "azurerm_route_table" "spoke2-rt" {
  name                          = "rt-${local.prefix-spoke2}"
  location                      = azurerm_resource_group.spoke2-rg.location
  resource_group_name           = azurerm_resource_group.spoke2-rg.name
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

# service tags https://learn.microsoft.com/en-us/azure/virtual-network/service-tags-overview
# setup apim subnet wihtout service endpoint require routing tables
resource "azurerm_route_table" "spoke2-rt-apim" {
  name                          = "rt-${local.prefix-spoke2}-apim"
  location                      = azurerm_resource_group.spoke2-rg.location
  resource_group_name           = azurerm_resource_group.spoke2-rg.name
  bgp_route_propagation_enabled = false

  # default go to appliance 
  route {
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.36"
  }

  route {
    name           = "default-ApiManagement"
    address_prefix = "ApiManagement"
    next_hop_type  = "Internet"
  }

  route {
    name           = "default-AzureMonitor"
    address_prefix = "AzureMonitor"
    next_hop_type  = "Internet"
  }


  route {
    name           = "default-Sql"
    address_prefix = "Sql"
    next_hop_type  = "Internet"
  }

  # instead of Service end point
  route {
    name           = "default-AzureActiveDirectory"
    address_prefix = "AzureActiveDirectory"
    next_hop_type  = "Internet"
  }

  # instead of Service end point 
  route {
    name           = "default-AzureKeyVault"
    address_prefix = "AzureKeyVault"
    next_hop_type  = "Internet"
  }

  # instead of Service end point
  route {
    name           = "default-Storage"
    address_prefix = "Storage"
    next_hop_type  = "Internet"
  }

  # instead of Service end point
  route {
    name           = "default-EventHub"
    address_prefix = "EventHub"
    next_hop_type  = "Internet"
  }

  # instead of Service end point
  route {
    name           = "default-ServiceBus"
    address_prefix = "ServiceBus"
    next_hop_type  = "Internet"
  }

  tags = {
    environment = local.prefix-hub-nva
  }
}

#--- VNET ----

resource "azurerm_virtual_network" "spoke2-vnet" {
  name                = "vnet-${local.prefix-spoke2}"
  location            = azurerm_resource_group.spoke2-rg.location
  resource_group_name = azurerm_resource_group.spoke2-rg.name
  address_space       = ["10.2.0.0/16"]

  subnet {
    name             = "mgmt"
    address_prefixes = ["10.2.0.64/27"]
    route_table_id   = azurerm_route_table.spoke2-rt.id
  }
  subnet {
    name             = "workload"
    address_prefixes = ["10.2.1.0/24"]
    route_table_id   = azurerm_route_table.spoke2-rt.id
  }

  # setup apim subnet wihtout service endpoint require routing tables
  subnet {
    name             = "apim"
    address_prefixes = ["10.2.3.0/26"]
    security_group   = azurerm_network_security_group.spoke2-apim-nsg.id
    route_table_id   = azurerm_route_table.spoke2-rt-apim.id
  }

  tags = {
    environment = local.prefix-spoke2
  }
}

# --- peering ---
resource "azurerm_virtual_network_peering" "spoke2-hub-peer" {
  name                      = "peer-${local.prefix-spoke2}-hub"
  resource_group_name       = azurerm_resource_group.spoke2-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke2-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on = [
    azurerm_virtual_network.spoke2-vnet,
    azurerm_virtual_network.hub-vnet
  ]
}


resource "azurerm_virtual_network_peering" "hub-spoke2-peer" {
  name                         = "peer-${var.prefix}-hub-spoke2"
  resource_group_name          = azurerm_resource_group.hub-rg.name
  virtual_network_name         = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on = [
    azurerm_virtual_network.spoke2-vnet,
    azurerm_virtual_network.hub-vnet
  ]
}
