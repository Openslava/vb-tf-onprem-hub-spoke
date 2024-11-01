# ----- VMs ------

data "azurerm_subnet" "spoke1-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.spoke1-rg.name
  virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
  depends_on           = [azurerm_virtual_network.spoke1-vnet]
}

resource "azurerm_network_interface" "spoke1-nic" {
  name                  = "nic-${local.spoke1-vmname}"
  location              = azurerm_resource_group.spoke1-rg.location
  resource_group_name   = azurerm_resource_group.spoke1-rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = local.prefix-spoke1
    subnet_id                     = data.azurerm_subnet.spoke1-mgmt.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
    azurerm_virtual_network.spoke1-vnet
  ]
}


resource "azurerm_virtual_machine" "spoke1-vm" {
  count                 = var.vms == "True" ? 1 : 0
  name                  = local.spoke1-vmname
  location              = azurerm_resource_group.spoke1-rg.location
  resource_group_name   = azurerm_resource_group.spoke1-rg.name
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

