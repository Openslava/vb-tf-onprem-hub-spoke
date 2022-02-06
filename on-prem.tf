#
# on-prem simulation
#

locals {
  onprem-location       = var.location
  prefix-onprem         = "${var.prefix}-onprem"
  onprem-resource-group = "rg-${local.prefix-onprem}-${var.region}"
  onprem-vmname         = "vm${var.prefix}onprem"
}

resource "azurerm_resource_group" "onprem-rg" {
  count    = var.onprem == "True" ? 1 : 0
  name     = local.onprem-resource-group
  location = local.onprem-location
}

resource "azurerm_virtual_network" "onprem-vnet" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "vnet-${local.prefix-onprem}"
  location            = azurerm_resource_group.onprem-rg[0].location
  resource_group_name = azurerm_resource_group.onprem-rg[0].name
  address_space       = ["192.168.0.0/16"]

  tags = {
    environment = local.prefix-onprem
  }
}

resource "azurerm_subnet" "onprem-gateway-subnet" {
  count                = var.onprem == "True" ? 1 : 0
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.onprem-rg[0].name
  virtual_network_name = azurerm_virtual_network.onprem-vnet[0].name
  address_prefixes     = ["192.168.255.224/27"]
}

resource "azurerm_subnet" "onprem-mgmt" {
  count                = var.onprem == "True" ? 1 : 0
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.onprem-rg[0].name
  virtual_network_name = azurerm_virtual_network.onprem-vnet[0].name
  address_prefixes     = ["192.168.1.128/25"]
}

resource "null_resource" "onprem-subnets" {
  count = var.onprem == "True" ? 1 : 0
  depends_on = [
    azurerm_subnet.onprem-gateway-subnet,
    azurerm_subnet.onprem-mgmt
  ]
}

resource "azurerm_public_ip" "onprem-pip" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "pip-${local.onprem-vmname}"
  location            = azurerm_resource_group.onprem-rg[0].location
  resource_group_name = azurerm_resource_group.onprem-rg[0].name
  allocation_method   = "Dynamic"

  tags = {
    environment = local.prefix-onprem
  }
}

resource "azurerm_network_interface" "onprem-nic" {
  count                = var.onprem == "True" ? 1 : 0
  name                 = "nic-${local.onprem-vmname}"
  location             = azurerm_resource_group.onprem-rg[0].location
  resource_group_name  = azurerm_resource_group.onprem-rg[0].name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = local.prefix-onprem
    subnet_id                     = azurerm_subnet.onprem-mgmt[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onprem-pip[0].id
  }
  depends_on = [
    null_resource.onprem-subnets,
    azurerm_public_ip.onprem-pip
  ]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "onprem-nsg" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "nsg-${local.prefix-onprem}"
  location            = azurerm_resource_group.onprem-rg[0].location
  resource_group_name = azurerm_resource_group.onprem-rg[0].name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "onprem"
  }
}

resource "azurerm_subnet_network_security_group_association" "mgmt-nsg-association" {
  count                     = var.onprem == "True" ? 1 : 0
  subnet_id                 = azurerm_subnet.onprem-mgmt[0].id
  network_security_group_id = azurerm_network_security_group.onprem-nsg[0].id
}

resource "azurerm_virtual_machine" "onprem-vm" {
  count                 = var.onprem == "True" ? 1 : 0
  name                  = local.onprem-vmname
  location              = azurerm_resource_group.onprem-rg[0].location
  resource_group_name   = azurerm_resource_group.onprem-rg[0].name
  network_interface_ids = [azurerm_network_interface.onprem-nic[0].id]
  vm_size               = var.vmsize

  storage_image_reference {
    publisher = var.vmimage.publisher
    offer     = var.vmimage.offer
    sku       = var.vmimage.sku
    version   = var.vmimage.version
  }

  storage_os_disk {
    name              = "disk-${local.onprem-vmname}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.onprem-vmname
    admin_username = var.username
    admin_password = local.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = local.prefix-onprem
  }
  depends_on = [
    azurerm_network_interface.onprem-nic
  ]
}

resource "azurerm_public_ip" "onprem-vpn-gateway1-pip" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "pip-${local.prefix-onprem}-vpn-gateway"
  location            = azurerm_resource_group.onprem-rg[0].location
  resource_group_name = azurerm_resource_group.onprem-rg[0].name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "onprem-vpn-gateway" {
  count               = var.onprem == "True" ? 1 : 0
  name                = "vgw-${local.prefix-onprem}"
  location            = azurerm_resource_group.onprem-rg[0].location
  resource_group_name = azurerm_resource_group.onprem-rg[0].name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onprem-vpn-gateway1-pip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem-gateway-subnet[0].id
  }
  depends_on = [
    azurerm_public_ip.onprem-vpn-gateway1-pip,
    null_resource.onprem-subnets
  ]

}
