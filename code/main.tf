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