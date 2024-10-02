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

resource "azurerm_virtual_network" "spoke2-vnet" {
  name                = "vnet-${local.prefix-spoke2}"
  location            = azurerm_resource_group.spoke2-rg.location
  resource_group_name = azurerm_resource_group.spoke2-rg.name
  address_space       = ["10.2.0.0/16"]

  tags = {
    environment = local.prefix-spoke2
  }
}

resource "azurerm_subnet" "spoke2-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.spoke2-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  address_prefixes     = ["10.2.0.64/27"]
}

resource "azurerm_subnet" "spoke2-workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.spoke2-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}
resource "azurerm_subnet" "spoke2-apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.spoke2-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  address_prefixes     = ["10.2.3.0/26"]
}

resource "null_resource" "spoke2-subnets" {
  depends_on = [
    azurerm_subnet.spoke2-apim,
    azurerm_subnet.spoke2-workload,
    azurerm_subnet.spoke2-mgmt
  ]
}

resource "azurerm_network_security_group" "spoke2-apim-nsg" {
  name                = "nsg-${local.prefix-spoke2}-apim"
  location            = azurerm_resource_group.spoke2-rg.location
  resource_group_name = azurerm_resource_group.spoke2-rg.name

  tags = {
    environment = "spoke2"
  }
}

resource "azurerm_route_table" "spoke2-rt" {
  name                          = "rt-${local.prefix-hub-nva}-spoke2"
  location                      = azurerm_resource_group.spoke2-rg.location
  resource_group_name           = azurerm_resource_group.spoke2-rg.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "toSpoke1"
    address_prefix         = "10.1.0.0/16"
    next_hop_in_ip_address = "10.0.0.36"
    next_hop_type          = "VirtualAppliance"
  }

  route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VnetLocal"
  }

  tags = {
    environment = local.prefix-hub-nva
  }
}

resource "azurerm_route_table" "spoke2-rt-apim" {
  name                          = "rt-${local.prefix-spoke2}-${local.prefix-hub-nva}-apim"
  location                      = azurerm_resource_group.spoke2-rg.location
  resource_group_name           = azurerm_resource_group.spoke2-rg.name
  bgp_route_propagation_enabled = false

  route {
    name           = "apim-mngm"
    address_prefix = "ApiManagement"
    next_hop_type  = "Internet"
  }

  route {
    name           = "default-apim"
    address_prefix = "AzureCloud"
    next_hop_type  = "Internet"
  }

  route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VnetLocal"
  }

  tags = {
    environment = local.prefix-hub-nva
  }
}

resource "azurerm_subnet_route_table_association" "spoke2-rt-spoke2-vnet-mgmt" {
  subnet_id      = azurerm_subnet.spoke2-mgmt.id
  route_table_id = azurerm_route_table.spoke2-rt.id
  depends_on = [
    null_resource.spoke2-subnets
  ]
}

resource "azurerm_subnet_route_table_association" "spoke2-rt-spoke2-vnet-workload" {
  subnet_id      = azurerm_subnet.spoke2-workload.id
  route_table_id = azurerm_route_table.spoke2-rt.id
  depends_on = [
    null_resource.spoke2-subnets
  ]
}

resource "azurerm_subnet_route_table_association" "spoke2-rt-spoke2-vnet-apim" {
  subnet_id      = azurerm_subnet.spoke2-apim.id
  route_table_id = azurerm_route_table.spoke2-rt.id
  depends_on = [
    null_resource.spoke2-subnets
  ]
}

resource "azurerm_subnet_network_security_group_association" "spoke2-apim-nsg-association" {
  subnet_id                 = azurerm_subnet.spoke2-apim.id
  network_security_group_id = azurerm_network_security_group.spoke2-apim-nsg.id
  depends_on                = [azurerm_subnet.spoke1-apim, azurerm_network_security_group.spoke2-apim-nsg]
}

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
    null_resource.spoke2-subnets,
    null_resource.hub-subnets,
    azurerm_virtual_network.spoke2-vnet,
    azurerm_virtual_network.hub-vnet
  ]
}

resource "azurerm_network_interface" "spoke2-nic" {
  name                  = "nic-${local.spoke2-vmname}"
  location              = azurerm_resource_group.spoke2-rg.location
  resource_group_name   = azurerm_resource_group.spoke2-rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = local.prefix-spoke2
    subnet_id                     = azurerm_subnet.spoke2-mgmt.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.prefix-spoke2
  }
  depends_on = [
    azurerm_subnet.spoke2-mgmt
  ]
}

resource "azurerm_virtual_machine" "spoke2-vm" {
  count                 = var.vms == "True" ? 1 : 0
  name                  = local.spoke2-vmname
  location              = azurerm_resource_group.spoke2-rg.location
  resource_group_name   = azurerm_resource_group.spoke2-rg.name
  network_interface_ids = [azurerm_network_interface.spoke2-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    publisher = var.vmimage.publisher
    offer     = var.vmimage.offer
    sku       = var.vmimage.sku
    version   = var.vmimage.version
  }

  storage_os_disk {
    name              = "disk-${local.spoke2-vmname}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.spoke2-vmname
    admin_username = var.username
    admin_password = local.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = local.prefix-spoke2
  }

  depends_on = [
    azurerm_network_interface.spoke2-nic
  ]
}


resource "azurerm_virtual_network_peering" "hub-spoke2-peer" {
  name                         = "peer-${var.prefix}-hub-spoke2"
  resource_group_name          = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name         = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on = [
    null_resource.spoke2-subnets,
    null_resource.hub-subnets,
    azurerm_virtual_network.spoke2-vnet,
    azurerm_virtual_network.hub-vnet,
    azurerm_virtual_network_gateway.hub-vnet-gateway
  ]
}