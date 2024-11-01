# --- VMs
data "azurerm_subnet" "spoke2-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.spoke2-rg.name
  virtual_network_name = azurerm_virtual_network.spoke2-vnet.name
  depends_on           = [azurerm_virtual_network.spoke2-vnet]
}

resource "azurerm_network_interface" "spoke2-nic" {
  name                  = "nic-${local.spoke2-vmname}"
  location              = azurerm_resource_group.spoke2-rg.location
  resource_group_name   = azurerm_resource_group.spoke2-rg.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = local.prefix-spoke2
    subnet_id                     = data.azurerm_subnet.spoke2-mgmt.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.prefix-spoke2
  }
  depends_on = [
    data.azurerm_subnet.spoke2-mgmt
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
