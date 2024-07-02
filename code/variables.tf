variable "resource_group_location" {
  default     = "West Europe"
  description = "Location of the resource group."
}

variable "rg_name" {
  type        = string
  default     = "rg-avd-resources"
  description = "Name of the Resource group in which to deploy service objects"
}

variable "rg_sa" {
  type        = string
  default     = "rg-storage-account"
  description = "Name of the Resource group in which to deploy storage account"

}
variable "rg_onprem" {
  type        = string
  default     = "rg-onprem-resources"
  description = "Name of the Resource group in which to deploy on-prem resources"

}

variable "rg_avd_compute" {
  type        = string
  default     = "rg-avd-compute"
  description = "Name of the Resource group in which to deploy session host"
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
  default     = "2024-07-25T12:00:00Z"
  description = "Registration token expiration"
}

variable "prefix" {
  type        = string
  default     = "avd"
  description = "Prefix for all resources"
}

variable "rdsh_count" {
  description = "Number of AVD machines to deploy"
  default     = 1
}

variable "vm_size" {
  description = "Size of the machine to deploy"
  default     = "Standard_DS2_v2"
}

variable "ou_path" {
  default = ""
}

variable "local_admin_username" {
  type        = string
  default     = "adminuser"
  description = "local admin username"
}

variable "local_admin_password" {
  type        = string
  default     = "Password1234!"
  description = "local admin password"
  sensitive   = true
}
variable "avd_vnet_name" {
  type        = string
  default     = "AVD-VNET"
  description = "Name of the VNET for AVD machines"
}

variable "avd_subnet_name" {
  type        = string
  default     = "AVD-SUBNET"
  description = "Name of the Subnet for AVD machines"

}

variable "storage_account_vnet_name" {
  type        = string
  default     = "STORAGE-VNET"
  description = "Name of the VNET for storage account"

}

variable "storage_account_subnet_name" {
  type        = string
  default     = "STORAGE-SUBNET"
  description = "Name of the Subnet for storage account"
}

variable "onprem_vnet_name" {
  type        = string
  default     = "ONPREM-VNET"
  description = "Name of the VNET for on-prem resources"
}

variable "onprem_subnet_name" {
  type        = string
  default     = "ONPREM-SUBNET"
  description = "Name of the Subnet for on-prem resources"

}
variable "bastion_subnet_name" {
  type        = string
  default     = "AzureBastionSubnet"
  description = "Name of the Subnet for bastion host"

}

variable "storage_account_name" {
  type        = string
  default     = "sa-avd-file-sync-"
  description = "Name of the storage account"

}

variable "github_actions_ip_ranges" {
  description = "List of IP ranges for GitHub Actions"
  default     = []
}


locals {
  config = yamldecode(file("../.github/workflows/terraform.yml"))
}

variable "arm_subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "arm_client_id" {
  type        = string
  description = "Azure Client ID"
}

variable "arm_tenant_id" {
  type        = string
  description = "Azure Tenant ID"
  sensitive   = true

}

variable "filesync_vm_name" {
  type        = string
  default     = "filesync-server"
  description = "Name of the file sync VM"

}

variable "storage_sync_service_name" {
  type        = string
  default     = "StorageSync"
  description = "Name of the file sync service"

}

variable "storage_sync_group_name" {
  type        = string
  default     = "StorageSyncGroup"
  description = "Name of the file sync group"

}