# Resoure group for AVD resources
resource "azurerm_resource_group" "sh" {
  name     = var.rg_name
  location = var.resource_group_location
}

# Resoure group for AVD machines
resource "azurerm_resource_group" "rg" {
  name     = var.rg_avd_compute
  location = var.resource_group_location
}

# Resource group simulation OnPrem environment
resource "azurerm_resource_group" "rg_onprem" {
  name     = var.rg_onprem
  location = var.resource_group_location
}

# Resource group for Storage Account Resource
resource "azurerm_resource_group" "rg_sa" {
  name     = var.rg_sa
  location = var.resource_group_location

}

# Create AVD workspace
resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = var.workspace
  resource_group_name = azurerm_resource_group.sh.name
  location            = azurerm_resource_group.sh.location
  friendly_name       = "${var.prefix} Workspace"
  description         = "${var.prefix} Workspace"
}

# Create AVD host pool
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  resource_group_name      = azurerm_resource_group.sh.name
  location                 = azurerm_resource_group.sh.location
  name                     = var.hostpool
  friendly_name            = var.hostpool
  validate_environment     = true
  custom_rdp_properties    = "audiocapturemode:i:1;audiomode:i:0;"
  description              = "${var.prefix} Terraform HostPool"
  type                     = "Pooled"
  maximum_sessions_allowed = 16
  load_balancer_type       = "DepthFirst" #[BreadthFirst DepthFirst]
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "registrationinfo" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = var.rfc3339
}

# Create AVD DAG
resource "azurerm_virtual_desktop_application_group" "dag" {
  resource_group_name = azurerm_resource_group.sh.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  location            = azurerm_resource_group.sh.location
  type                = "Desktop"
  name                = "${var.prefix}-dag"
  friendly_name       = "Desktop AppGroup"
  description         = "AVD application group"
  depends_on          = [azurerm_virtual_desktop_host_pool.hostpool, azurerm_virtual_desktop_workspace.workspace]
}

# Associate Workspace and DAG
resource "azurerm_virtual_desktop_workspace_application_group_association" "ws-dag" {
  application_group_id = azurerm_virtual_desktop_application_group.dag.id
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
}


locals {
  registration_token = azurerm_virtual_desktop_host_pool_registration_info.registrationinfo.token
}

resource "random_string" "storage_account_name" {
  length  = 18
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_network_interface" "avd_vm_nic" {
  count               = var.rdsh_count
  name                = "${var.prefix}-${count.index + 1}-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
  }

  depends_on = [
    azurerm_resource_group.rg
  ]
}

resource "azurerm_windows_virtual_machine" "avd_vm" {
  count                 = var.rdsh_count
  name                  = "${var.prefix}-${count.index + 1}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  network_interface_ids = ["${azurerm_network_interface.avd_vm_nic.*.id[count.index]}"]
  provision_vm_agent    = true
  admin_username        = var.local_admin_username
  admin_password        = var.local_admin_password

  os_disk {
    name                 = "${lower(var.prefix)}-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "20h2-evd"
    version   = "latest"
  }

  depends_on = [
    azurerm_resource_group.rg,
    azurerm_network_interface.avd_vm_nic
  ]
}

resource "azurerm_virtual_machine_extension" "aad_login" {
  count                = var.rdsh_count
  name                 = "AADLogin"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows" # For Windows VMs: AADLoginForWindows for linux VMs: AADLoginForLinux
  type_handler_version = "1.0"                # There may be a more recent version
}

resource "azurerm_virtual_machine_extension" "vmext_dsc" {
  count                      = var.rdsh_count
  name                       = "${var.prefix}${count.index + 1}-avd_dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<-SETTINGS
    {
      "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "HostPoolName":"${azurerm_virtual_desktop_host_pool.hostpool.name}"
      }
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "properties": {
      "registrationInfoToken": "${local.registration_token}"
    }
  }
PROTECTED_SETTINGS

  depends_on = [
    azurerm_virtual_machine_extension.aad_login,
    azurerm_virtual_desktop_host_pool.hostpool
  ]
}

#vnet components for AVD
resource "azurerm_virtual_network" "vnet" {
  name                = var.avd_vnet_name
  address_space       = ["10.0.0.0/24"]
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.sh.name

  depends_on = [
    azurerm_resource_group.sh
  ]
}

resource "azurerm_subnet" "subnet" {
  name                 = var.avd_subnet_name
  resource_group_name  = azurerm_resource_group.sh.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

#creating a new vnet
resource "azurerm_virtual_network" "storage_account_vnet" {
  name                = var.storage_account_vnet_name
  address_space       = ["10.0.1.0/24"]
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg_sa.name
  depends_on = [
    azurerm_resource_group.rg_sa
  ]
}

resource "azurerm_subnet" "storage_account_subnet" {
  name                 = var.storage_account_subnet_name
  resource_group_name  = azurerm_resource_group.rg_sa.name
  virtual_network_name = azurerm_virtual_network.storage_account_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [
    azurerm_virtual_network.storage_account_vnet
  ]
}

resource "azurerm_virtual_network" "onprem_vnet" {
  name                = var.onprem_vnet_name
  address_space       = ["10.0.2.0/24"]
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg_onprem.name
  depends_on = [
    azurerm_resource_group.rg_onprem
  ]
}

resource "azurerm_subnet" "name" {
  name                 = var.onprem_subnet_name
  resource_group_name  = azurerm_resource_group.rg_onprem.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on = [
    azurerm_virtual_network.onprem_vnet
  ]
}


#creating a peering between avd vent and storage account vnet 
resource "azurerm_virtual_network_peering" "peering1" {
  name                         = "avd-vnet-to-storage-account-vnet"
  resource_group_name          = azurerm_resource_group.sh.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.storage_account_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network.storage_account_vnet
  ]
}

#creating the peering between storage account vnet and avd vnet
resource "azurerm_virtual_network_peering" "peering2" {
  name                         = "storage-account-vnet-to-avd-vnet"
  resource_group_name          = azurerm_resource_group.rg_sa.name
  virtual_network_name         = azurerm_virtual_network.storage_account_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network.storage_account_vnet
  ]

}

#creating the peering between storage account vnet and onprem vnet
resource "azurerm_virtual_network_peering" "peering3" {
  name                         = "storage-account-vnet-to-onprem-vnet"
  resource_group_name          = azurerm_resource_group.rg_sa.name
  virtual_network_name         = azurerm_virtual_network.storage_account_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.onprem_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_virtual_network.onprem_vnet,
    azurerm_virtual_network.storage_account_vnet
  ]

}
# creating the peering between onprem vnet and storage account vnet
resource "azurerm_virtual_network_peering" "peering4" {
  name                         = "onprem-vnet-to-storage-account-vnet"
  resource_group_name          = azurerm_resource_group.rg_onprem.name
  virtual_network_name         = azurerm_virtual_network.onprem_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.storage_account_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_virtual_network.onprem_vnet,
    azurerm_virtual_network.storage_account_vnet
  ]
}

#creating a storage account with a private endpoint in vnet storage_account_vnet
resource "azurerm_storage_account" "sa" {
  name                     = "sademo${random_string.storage_account_name.result}"
  resource_group_name      = azurerm_resource_group.rg_sa.name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.storage_account_subnet.id]
  }
  depends_on = [
    azurrm.resource_group_name.rg_sa
  ]

}
resource "azurerm_private_dns_zone" "pdns_st" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg_sa.name
  depends_on = [
    azurerm_storage_account.sa
  ]
}

resource "azurerm_private_endpoint" "pep_st" {
  name                = "pep-sd2488-st-non-prod-weu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg_sa.name
  subnet_id           = azurerm_subnet.storage_account_subnet.id
  private_service_connection {
    name                           = "sc-sta"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "dns-group-sta"
    private_dns_zone_ids = [azurerm_private_dns_zone.pdns_st.id]
  }
  depends_on = [
    azurerm_private_dns_zone.pdns_st
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_lnk_sta" {
  name                  = "lnk-dns-vnet-sta"
  resource_group_name   = azurerm_resource_group.rg_sa.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_st.name
  virtual_network_id    = azurerm_virtual_network.storage_account_vnet.id
  depends_on = [
    azurerm_private_dns_zone.pdns_st
  ]
}

resource "azurerm_private_dns_a_record" "dns_a_sta" {
  name                = "sta_a_record"
  zone_name           = azurerm_private_dns_zone.pdns_st.name
  resource_group_name = azurerm_resource_group.rg_sa.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.pep_st.private_service_connection.0.private_ip_address]
  depends_on = [
    azurerm_private_endpoint.pep_st
  ]
}
