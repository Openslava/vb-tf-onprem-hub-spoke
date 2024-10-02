locals {
  prefix-hub         = "${var.prefix}-hub"
  hub-location       = var.location
  hub-resource-group = "rg-${local.prefix-hub}-${var.region}"
  hub-vmname         = "vm${var.prefix}hub"
  shared-key         = "6-v1ry-86cr37-1a84c-5s4r3d-q3z"
}

resource "azurerm_resource_group" "hub-vnet-rg" {
  name     = local.hub-resource-group
  location = local.hub-location
}

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "vnet-${local.prefix-hub}"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "hub-spoke"
  }
}

resource "azurerm_subnet" "hub-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.0.255.224/27"]
}

resource "azurerm_subnet" "hub-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.0.0.64/27"]
}

resource "azurerm_subnet" "hub-dmz" {
  name                 = "dmz"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.0.0.32/27"]
}

resource "azurerm_subnet" "hub-azurefirewallsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet" "hub-azurebastionsubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "hub-apim" {
  name                 = "apim"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.0.3.0/26"]
}

resource "null_resource" "hub-subnets" {
  depends_on = [
    azurerm_subnet.hub-apim,
    azurerm_subnet.hub-azurebastionsubnet,
    azurerm_subnet.hub-dmz,
    azurerm_subnet.hub-gateway-subnet,
    azurerm_subnet.hub-mgmt
  ]
}

resource "azurerm_network_security_group" "hub-nsg" {
  name                = "nsg-${local.prefix-hub}"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  # allow any inbound trafic to HUB (jumpbox)
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
    environment = "hub"
  }
}

resource "azurerm_subnet_network_security_group_association" "hub-apim-nsg-association" {
  subnet_id                 = azurerm_subnet.hub-apim.id
  network_security_group_id = azurerm_network_security_group.hub-nsg.id
  depends_on = [
    null_resource.hub-subnets,
  azurerm_network_security_group.hub-nsg]
}

resource "azurerm_subnet_network_security_group_association" "hub-dmz-nsg-association" {
  subnet_id                 = azurerm_subnet.hub-dmz.id
  network_security_group_id = azurerm_network_security_group.hub-nsg.id
  depends_on = [
    null_resource.hub-subnets,
    azurerm_network_security_group.hub-nsg
  ]
}

resource "azurerm_public_ip" "hub-pip" {
  name                = "pip-${local.hub-vmname}"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = local.prefix-hub
  }
}

resource "azurerm_network_interface" "hub-nic" {
  name                  = "nic-${local.hub-vmname}"
  location              = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name   = azurerm_resource_group.hub-vnet-rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = local.prefix-hub
    subnet_id                     = azurerm_subnet.hub-mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hub-pip.id
  }

  tags = {
    environment = local.prefix-hub
  }
  depends_on = [
    null_resource.hub-subnets,
    azurerm_public_ip.hub-pip
  ]
}

#Virtual Machine
resource "azurerm_virtual_machine" "hub-vm" {
  count                 = var.vms == "True" ? 1 : 0
  name                  = local.hub-vmname
  location              = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name   = azurerm_resource_group.hub-vnet-rg.name
  network_interface_ids = [azurerm_network_interface.hub-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    publisher = var.vmimage.publisher
    offer     = var.vmimage.offer
    sku       = var.vmimage.sku
    version   = var.vmimage.version
  }

  storage_os_disk {
    name              = "disk-${local.hub-vmname}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.hub-vmname
    admin_username = var.username
    admin_password = local.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = local.prefix-hub
  }
  depends_on = [
    azurerm_network_interface.hub-nic
  ]
}


# Virtual Network Gateway
resource "azurerm_public_ip" "hub-vpn-gateway1-pip" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "pip-${local.prefix-hub}-vpn-gateway"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "hub-vnet-gateway" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "vgw-${local.prefix-hub}"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.hub-vpn-gateway1-pip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub-gateway-subnet.id
  }
  depends_on = [
    azurerm_public_ip.hub-vpn-gateway1-pip,
    null_resource.hub-subnets
  ]
}

resource "azurerm_virtual_network_gateway_connection" "hub-onprem-conn" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "conn-${var.prefix}-hub-onprem"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  type           = "Vnet2Vnet"
  routing_weight = 1

  virtual_network_gateway_id      = azurerm_virtual_network_gateway.hub-vnet-gateway[0].id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem-vpn-gateway[0].id

  shared_key = local.shared-key
}

resource "azurerm_virtual_network_gateway_connection" "onprem-hub-conn" {
  count                           = var.onprem == "True" ? 1 : 0
  name                            = "conn-${var.prefix}-onprem-hub"
  location                        = azurerm_resource_group.onprem-rg[0].location
  resource_group_name             = azurerm_resource_group.onprem-rg[0].name
  type                            = "Vnet2Vnet"
  routing_weight                  = 1
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.onprem-vpn-gateway[0].id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.hub-vnet-gateway[0].id

  shared_key = local.shared-key
}
