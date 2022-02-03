locals {
  spoke2-location       = var.location
  prefix-spoke2         = "${var.prefix}-spoke2"
  spoke2-resource-group = "rg-${local.prefix-spoke2}-${var.region}"
  spoke2-vmname         = "vm${var.prefix}spoke2"
}

resource "azurerm_resource_group" "spoke2-vnet-rg" {
  name     = local.spoke2-resource-group
  location = local.spoke2-location
}

resource "azurerm_virtual_network" "spoke2-vnet" {
  name                = "vnet-${local.prefix-spoke2}"
  location            = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name = azurerm_resource_group.spoke2-vnet-rg.name
  address_space       = ["10.2.0.0/16"]

  tags = {
    environment = local.prefix-spoke2
  }
}

resource "azurerm_subnet" "spoke2-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.spoke2-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  address_prefixes     = ["10.2.0.64/27"]
}

resource "azurerm_subnet" "spoke2-workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.spoke2-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}
resource "azurerm_subnet" "spoke2-apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.spoke2-vnet-rg.name
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
  location            = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name = azurerm_resource_group.spoke2-vnet-rg.name

  security_rule {
    name                       = "Any"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "spoke2"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke2-apim-nsg-association" {
  subnet_id                 = azurerm_subnet.spoke2-apim.id
  network_security_group_id = azurerm_network_security_group.spoke2-apim-nsg.id
  depends_on                = [azurerm_subnet.spoke1-apim, azurerm_network_security_group.spoke2-apim-nsg]
}

resource "azurerm_virtual_network_peering" "spoke2-hub-peer" {
  name                      = "peer-${local.prefix-spoke2}-hub"
  resource_group_name       = azurerm_resource_group.spoke2-vnet-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke2-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
  depends_on = [
    null_resource.spoke2-subnets,
    azurerm_virtual_network.spoke2-vnet,
    azurerm_virtual_network.hub-vnet,
    azurerm_virtual_network_gateway.hub-vnet-gateway
  ]
}

resource "azurerm_network_interface" "spoke2-nic" {
  name                 = "nic-${local.spoke2-vmname}"
  location             = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name  = azurerm_resource_group.spoke2-vnet-rg.name
  enable_ip_forwarding = true

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
  name                  = local.spoke2-vmname
  location              = azurerm_resource_group.spoke2-vnet-rg.location
  resource_group_name   = azurerm_resource_group.spoke2-vnet-rg.name
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
    azurerm_virtual_network.spoke2-vnet,
    azurerm_virtual_network.hub-vnet,
    azurerm_virtual_network_gateway.hub-vnet-gateway
  ]
}