variable "location" {
  description = "Location of the network"
  default     = "westeurope"
}

variable "username" {
  description = "Username for Virtual Machines"
  default     = "viliamb"
}

variable "vmsize" {
  description = "Size of the VMs"
  default     = "Standard_B2s"
}

variable "prefix" {
  description = "prefix for naming convention  e.g. vb01"
  default     = "vb01"
}

variable "region" {
  description = "region used in naming convention e.g. we"
  default     = "we"
}

resource "random_string" "password" {
  length  = 16
  special = true
}

locals {
  password = sha256(bcrypt(random_string.password.result))
}

variable "vmimage" {
  default = {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}