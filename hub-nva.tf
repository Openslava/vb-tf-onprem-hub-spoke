locals {
  prefix-hub-nva         = "${var.prefix}-hub-nva"
  hub-nva-location       = var.location
  hub-nva-resource-group = "rg-${local.prefix-hub-nva}-${var.region}"
  hub-nva-vmname         = "vm${var.prefix}hubnva"
}

resource "azurerm_resource_group" "hub-nva-rg" {
  name     = local.hub-nva-resource-group
  location = local.hub-nva-location

  tags = {
    environment = local.prefix-hub-nva
  }
}

resource "azurerm_network_interface" "hub-nva-nic" {
  name                  = "nic-${local.hub-nva-vmname}"
  location              = azurerm_resource_group.hub-nva-rg.location
  resource_group_name   = azurerm_resource_group.hub-nva-rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = local.prefix-hub-nva
    subnet_id                     = azurerm_subnet.hub-dmz.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.36"
  }

  tags = {
    environment = local.prefix-hub-nva
  }
  depends_on = [
    azurerm_subnet.hub-dmz
  ]
}

resource "azurerm_virtual_machine" "hub-nva-vm" {
  count                 = var.vms == "True" ? 1 : 0
  name                  = local.hub-nva-vmname
  location              = azurerm_resource_group.hub-nva-rg.location
  resource_group_name   = azurerm_resource_group.hub-nva-rg.name
  network_interface_ids = [azurerm_network_interface.hub-nva-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    publisher = var.vmimage.publisher
    offer     = var.vmimage.offer
    sku       = var.vmimage.sku
    version   = var.vmimage.version
  }

  storage_os_disk {
    name              = "disk-${local.hub-nva-vmname}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.hub-nva-vmname
    admin_username = var.username
    admin_password = local.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = local.prefix-hub-nva
  }
  depends_on = [azurerm_network_interface.hub-nva-nic]
}

resource "azurerm_virtual_machine_extension" "enable-routes" {
  count                = var.vms == "True" ? 1 : 0
  name                 = "enable-iptables-routes"
  virtual_machine_id   = azurerm_virtual_machine.hub-nva-vm[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  # the mentioned url does not exists anymore
  /*
  settings = <<SETTINGS
    {
        "fileUris": [
        "https://raw.githubusercontent.com/mspnp/reference-architectures/master/scripts/linux/enable-ip-forwarding.sh"
        ],
        "commandToExecute": "bash enable-ip-forwarding.sh"
    }
  SETTINGS
  */
  tags = {
    environment = local.prefix-hub-nva
  }
}

resource "azurerm_route_table" "hub-gateway-rt" {
  name                          = "rt-${local.prefix-hub-nva}-hub-gateway"
  location                      = azurerm_resource_group.hub-nva-rg.location
  resource_group_name           = azurerm_resource_group.hub-nva-rg.name
  bgp_route_propagation_enabled = false

  route {
    name           = "toHub"
    address_prefix = "10.0.0.0/16"
    next_hop_type  = "VnetLocal"
  }

  route {
    name                   = "toSpoke1"
    address_prefix         = "10.1.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.36"
  }

  route {
    name                   = "toSpoke2"
    address_prefix         = "10.2.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.36"
  }

  tags = {
    environment = local.prefix-hub-nva
  }
}

resource "azurerm_subnet_route_table_association" "hub-gateway-rt-hub-vnet-gateway-subnet" {
  subnet_id      = azurerm_subnet.hub-gateway-subnet.id
  route_table_id = azurerm_route_table.hub-gateway-rt.id
  depends_on = [
    null_resource.hub-subnets
  ]
}
