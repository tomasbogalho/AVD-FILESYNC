resource "azurerm_storage_sync" "storage_sync" {
  name                = var.storage_sync_service_name
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = azurerm_resource_group.rg_onprem.location
}

resource "azurerm_storage_sync_group" "storage_sync_group" {
  name            = var.storage_sync_group_name
  storage_sync_id = azurerm_storage_sync.storage_sync.id
}

resource "azurerm_storage_sync_cloud_endpoint" "storage_sync_cloud_endpoint" {
  name                  = "storage-sync-cloud-endpoint"
  storage_sync_group_id = azurerm_storage_sync_group.storage_sync_group.id
  file_share_name       = azurerm_storage_share.fileshare.name
  storage_account_id    = azurerm_storage_account.sa.id

}

data "azuread_service_principal" "storagesync" {
  display_name = "Microsoft.StorageSync"
}

/* COMENTING AS RIGHT NOW POWERSHELL SCRIPT IS NOT WORKING AND SHOULD BE RUN PRIOR TO THIS
resource "azurerm_storage_sync_server_endpoint" "example" {
  name                  = "storage-sync-server-endpoint"
  server_local_path     = sync_server_local_path
  storage_sync_group_id = azurerm_resource_group.rg_onprem.id
  registered_server_id  = azurerm_storage_sync.example.registered_servers[0]

  depends_on = [azurerm_storage_sync_cloud_endpoint.example]
}
*/