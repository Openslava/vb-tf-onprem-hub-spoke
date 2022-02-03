locals {
  spoke1-location       = var.location
  prefix-spoke1         = "${var.prefix}-spoke1"
  spoke1-resource-group = "rg-${local.prefix-spoke1}-${var.region}"
  spoke1-vmname         = "vm${var.prefix}spoke1"
}

resource "azurerm_resource_group" "spoke1-vnet-rg" {
  name     = local.spoke1-resource-group
  location = local.spoke1-location
}

resource "azurerm_virtual_network" "spoke1-vnet" {
  name                = "vnet-${local.prefix-spoke1}"
  location            = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name = azurerm_resource_group.spoke1-vnet-rg.name
  address_space       = ["10.1.0.0/16"]

  tags = {
    environment = local.prefix-spoke1
  }
}

resource "azurerm_subnet" "spoke1-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  address_prefixes     = ["10.1.0.64/27"]
}

resource "azurerm_subnet" "spoke1-dmz" {
  name                 = "dmz"
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  address_prefixes     = ["10.1.0.32/27"]
}

resource "azurerm_subnet" "spoke1-workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}
resource "azurerm_subnet" "spoke1-azurefirewallsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  address_prefixes     = ["10.1.2.0/26"]
}

resource "azurerm_subnet" "spoke1-apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  address_prefixes     = ["10.1.3.0/26"]
}

resource "null_resource" "spoke1-subnets" {
  depends_on = [
    azurerm_subnet.spoke1-workload,
    azurerm_subnet.spoke1-dmz,
    azurerm_subnet.spoke1-mgmt,
    azurerm_subnet.spoke1-azurefirewallsubnet,
    azurerm_subnet.spoke1-apim
  ]
}

resource "azurerm_network_security_group" "spoke1-apim-nsg" {
  name                = "nsg-${local.prefix-spoke1}-apim"
  location            = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name = azurerm_resource_group.spoke1-vnet-rg.name

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
    environment = "spoke1"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke1-apim-nsg-association" {
  subnet_id                 = azurerm_subnet.spoke1-apim.id
  network_security_group_id = azurerm_network_security_group.spoke1-apim-nsg.id
  depends_on                = [azurerm_subnet.spoke1-apim, azurerm_network_security_group.spoke1-apim-nsg]
}

resource "azurerm_virtual_network_peering" "spoke1-hub-peer" {
  name                      = "peer-${local.prefix-spoke1}-spoke1-hub"
  resource_group_name       = azurerm_resource_group.spoke1-vnet-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke1-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
  depends_on = [
    azurerm_virtual_network.spoke1-vnet,
    azurerm_virtual_network.hub-vnet,
    azurerm_virtual_network_gateway.hub-vnet-gateway,
    null_resource.spoke1-subnets
  ]
}


resource "azurerm_network_interface" "spoke1-nic" {
  name                 = "nic-${local.spoke1-vmname}"
  location             = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = local.prefix-spoke1
    subnet_id                     = azurerm_subnet.spoke1-mgmt.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
    azurerm_subnet.spoke1-mgmt
  ]
}

resource "azurerm_virtual_machine" "spoke1-vm" {
  name                  = local.spoke1-vmname
  location              = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name   = azurerm_resource_group.spoke1-vnet-rg.name
  network_interface_ids = [azurerm_network_interface.spoke1-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    publisher = var.vmimage.publisher
    offer     = var.vmimage.offer
    sku       = var.vmimage.sku
    version   = var.vmimage.version
  }

  storage_os_disk {
    name              = "disk-${local.spoke1-vmname}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.spoke1-vmname
    admin_username = var.username
    admin_password = local.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = local.prefix-spoke1
  }
  depends_on = [
    azurerm_network_interface.spoke1-nic
  ]
}


resource "azurerm_virtual_network_peering" "hub-spoke1-peer" {
  name                         = "peer-${var.prefix}-hub-spoke1"
  resource_group_name          = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name         = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
  depends_on = [
    null_resource.spoke1-subnets,
    azurerm_virtual_network.spoke1-vnet,
    azurerm_virtual_network.hub-vnet,
    azurerm_virtual_network_gateway.hub-vnet-gateway
  ]
}
