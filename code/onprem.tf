# Resource group simulation OnPrem environment
resource "azurerm_resource_group" "rg_onprem" {
  name     = var.rg_onprem
  location = var.resource_group_location
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

resource "azurerm_subnet" "onprem_subnet" {
  name                 = var.onprem_subnet_name
  resource_group_name  = azurerm_resource_group.rg_onprem.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
  address_prefixes     = ["10.0.2.0/25"]
  depends_on = [
    azurerm_virtual_network.onprem_vnet
  ]
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = var.bastion_subnet_name
  resource_group_name  = azurerm_resource_group.rg_onprem.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
  address_prefixes     = ["10.0.2.128/25"]
  depends_on = [
    azurerm_virtual_network.onprem_vnet
  ]
}

# adding a bastion host public ip to the onprem vnet
resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "bastion-public-ip"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg_onprem.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# adding a bastion host to the onprem vnet
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg_onprem.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}

# onprem nic for the windows server
resource "azurerm_network_interface" "onprem_nic" {
  name                = "onprem-nic"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg_onprem.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# adding a windows server to the onprem vnet
resource "azurerm_windows_virtual_machine" "onprem_vm" {
  name                = "onprem-vm"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = var.resource_group_location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "Password1234!"
  network_interface_ids = [
    azurerm_network_interface.onprem_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

#Install Active Directory on the DC01 VM
resource "azurerm_virtual_machine_extension" "script_extension" {
  name = "install_ad"
  #  resource_group_name  = azurerm_resource_group.main.name
  virtual_machine_id   = azurerm_windows_virtual_machine.file_sync_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

}

# adding network security group to onprem windows server
resource "azurerm_network_security_group" "onprem_nsg" {
  name                = "onprem-nsg"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg_onprem.name
}


# adding nic for file sync server
resource "azurerm_network_interface" "file_sync_nic" {
  name                = "file-sync-nic"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg_onprem.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# adding file sync server to the onprem vnet
resource "azurerm_windows_virtual_machine" "file_sync_vm" {
  name                = "file-sync-vm"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = var.resource_group_location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "Password1234!"
  network_interface_ids = [
    azurerm_network_interface.file_sync_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_storage_sync" "storage_sync" {
  name                = "StorageSync"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = azurerm_resource_group.rg_onprem.location
}

resource "azurerm_storage_sync_group" "storage_sync_group" {
  name            = "StorageSyncGroup"
  storage_sync_id = azurerm_storage_sync.storage_sync.id
}

resource "azurerm_storage_sync_cloud_endpoint" "storage_sync_cloud_endpoint" {
  name                  = "storage-sync-cloud-endpoint"
  storage_sync_group_id = azurerm_storage_sync_group.storage_sync_group.id
  file_share_name       = azurerm_storage_share.fileshare.name
  storage_account_id    = azurerm_storage_account.sa.id
}


