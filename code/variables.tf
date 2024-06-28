variable "resource_group_location" {
  default     = "West Europe"
  description = "Location of the resource group."
}

variable "rg_name" {
  type        = string
  default     = "rg-avd-resources"
  description = "Name of the Resource group in which to deploy service objects"
}

variable "workspace" {
  type        = string
  description = "Name of the Azure Virtual Desktop workspace"
  default     = "AVD TF Workspace"
}

variable "hostpool" {
  type        = string
  description = "Name of the Azure Virtual Desktop host pool"
  default     = "AVD-TF-HP"
}

variable "rfc3339" {
  type        = string
  default     = "2024-07-01T12:00:00Z"
  description = "Registration token expiration"
}

variable "prefix" {
  type        = string
  default     = "avdtf"
  description = "Prefix of the name of the AVD machine(s)"
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
  default     = "my-vnet"
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet"
  default     = "my-subnet"
}

variable "public_ip_name" {
  type        = string
  description = "Name of the public IP address"
  default     = "my-public-ip"
}

variable "nsg_name" {
  type        = string
  description = "Name of the network security group"
  default     = "my-nsg"
}

variable "nic_name" {
  type        = string
  description = "Name of the network interface"
  default     = "my-nic"
}

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
  default     = "my-vm"
}

variable "vm_size" {
  type        = string
  description = "Size of the virtual machine"
  default     = "Standard_DS2_v2"
}

variable "admin_username" {
  type        = string
  description = "Username for the virtual machine"
  default     = "adminuser"
}

variable "admin_password" {
  type        = string
  description = "Password for the virtual machine"
  default     = "Password123!"
}