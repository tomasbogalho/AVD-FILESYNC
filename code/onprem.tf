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

# adding nic for file sync server
resource "azurerm_network_interface" "fss_vm_nic" {
  count               = var.fss_count
  name                = "${var.prefix}-${count.index + 1}-nic"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = azurerm_resource_group.rg_onprem.location

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = azurerm_subnet.onprem_subnet.id
    private_ip_address_allocation = "dynamic"
  }

  depends_on = [
    azurerm_resource_group.rg_onprem
  ]
}

# adding file sync server to the onprem vnet
resource "azurerm_windows_virtual_machine" "file_sync_vm" {
  count                 = var.fss_count
  name                  = "${var.filesync_vm_name}-${count.index + 1}"
  resource_group_name   = azurerm_resource_group.rg_onprem.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  network_interface_ids = ["${azurerm_network_interface.fss_vm_nic.*.id[count.index]}"]
  provision_vm_agent    = true
  admin_username        = var.local_admin_username
  admin_password        = var.local_admin_password

  os_disk {
    name                 = "${lower(var.filesync_vm_name)}-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_resource_group.rg_onprem,
    azurerm_network_interface.fss_vm_nic
  ]
}

resource "azurerm_managed_disk" "datadisk" {
  count                = var.fss_count
  name                 = "${lower(var.filesync_vm_name)}-${count.index + 1}-datadisk"
  location             = azurerm_resource_group.rg_onprem.location
  resource_group_name  = azurerm_resource_group.rg_onprem.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachment" {
  count              = var.fss_count
  managed_disk_id    = azurerm_managed_disk.datadisk.id[count.index]
  virtual_machine_id = azurerm_windows_virtual_machine.file_sync_vm.id[count.index]
  lun                = "10"
  caching            = "ReadWrite"
}


/* COMENTING AS RIGHT NOW SCRIP IS NOT WORKING
# adding VM extension to run PowerShell script
resource "azurerm_virtual_machine_extension" "filesync_extension" {
  name                 = "filesync-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.file_sync_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  
  settings = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/tomasbogalho/AVD-FILESYNC/main/code/RegisterFileSyncServer.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File RegisterFileSyncServer.ps1 Out-File -filepath postBuild.ps1 -rgName ${var.rg_onprem} -sssName ${var.storage_sync_service_name} -fssName ${var.filesync_vm_name} -SyncGroup ${var.storage_sync_group_name}"
    }
  SETTINGS
  
  depends_on = [azurerm_windows_virtual_machine.file_sync_vm, azurerm_managed_disk.datadisk]
}
*/


