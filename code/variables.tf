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
  default     = "avd"
  description = "Prefix for all resources"
}

variable "vm_name" {
  type        = string
  default     = "avd-vm"
  description = "Name of the virtual machine"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Size of the virtual machine"
}

variable "nic_name" {
  type        = string
  default     = "avd-nic"
  description = "Name of the network interface"
}

variable "subnet_name" {
  type        = string
  default     = "avd-subnet"
  description = "Name of the subnet"
}

variable "vnet_name" {
  type        = string
  default     = "avd-vn"
  description = "Name of the virtual network"
  
}

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  
}

variable "subnet_address_prefix" {
  type        = list(string)
  default     = ["10.0.0.0/24"]
  
}
