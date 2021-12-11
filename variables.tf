variable "location" {
    description = "Location of the network"
    default     = "westeurope"
}

variable "username" {
    description = "Username for Virtual Machines"
    default     = "viliamb"
}

variable "password" {
    description = "Password for Virtual Machines"
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

variable "environment" {
    description = "environemnt used in naming convention e.g. lab01"
    default     = "lab01"
}

variable "region" {
    description = "region used in naming convention e.g. we"
    default     = "we"
}

resource "random_string" "password" {
 length = 16
 special = true
}

locals {
    password =  "${sha256(bcrypt(random_string.password.result))}"
}