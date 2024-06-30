# Resource group for Storage Account Resource
resource "azurerm_resource_group" "rg_sa" {
  name     = var.rg_sa
  location = var.resource_group_location

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

resource "random_string" "storage_account_name" {
  length  = 17
  lower   = true
  numeric = false
  special = false
  upper   = false
}

locals {
  storage_account_local_name = "sademo${random_string.storage_account_name.result}"

}

#creating a storage account with a private endpoint in vnet storage_account_vnet
resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_local_name
  resource_group_name      = azurerm_resource_group.rg_sa.name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  /*
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.storage_account_subnet.id, azurerm_subnet.onprem_subnet.id, azurerm_subnet.avd_subnet.id]
    ip_rules                   = var.github_actions_ip_ranges
  }
  */
  depends_on = [
    azurerm_resource_group.rg_sa,
    random_string.storage_account_name,
    azurerm_subnet.storage_account_subnet
  ]

}

# adding a fileshare to the storage account
resource "azurerm_storage_share" "fileshare" {
  name                 = "fileshare"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 1024
  acl {
    id = "GhostedRecall"
    access_policy {
      permissions = "r"
    }
  }
  depends_on = [
    azurerm_storage_account.sa
  ]
}



resource "azurerm_private_dns_zone" "pdns_st" {
  name                = "privatelink.file.core.windows.net"
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
    subresource_names              = ["file"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "dns-group-sta"
    private_dns_zone_ids = [azurerm_private_dns_zone.pdns_st.id]
  }
  depends_on = [
    azurerm_private_dns_zone.pdns_st,
    azurerm_storage_account.sa
  ]
}

# Link the private DNS zone to the storage account VNET
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_lnk_sta" {
  name                  = "lnk-dns-vnet-sta"
  resource_group_name   = azurerm_resource_group.rg_sa.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_st.name
  virtual_network_id    = azurerm_virtual_network.storage_account_vnet.id
  depends_on = [
    azurerm_private_dns_zone.pdns_st,
    azurerm_storage_account.sa
  ]
}

# Link the private DNS zone to the OnPrem VNET
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_lnk_onprem" {
  name                  = "lnk-dns-vnet-onprem"
  resource_group_name   = azurerm_resource_group.rg_sa.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_st.name
  virtual_network_id    = azurerm_virtual_network.onprem_vnet.id
  depends_on = [
    azurerm_private_dns_zone.pdns_st,
    azurerm_storage_account.sa
  ]
}

# Link the private DNS zone to the AVD VNET
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_lnk_avd" {
  name                  = "lnk-dns-vnet-avd"
  resource_group_name   = azurerm_resource_group.rg_sa.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_st.name
  virtual_network_id    = azurerm_virtual_network.avd_vnet.id
  depends_on = [
    azurerm_private_dns_zone.pdns_st,
    azurerm_storage_account.sa
  ]
}

resource "azurerm_private_dns_a_record" "dns_a_sta" {
  name                = "sta_a_record"
  zone_name           = azurerm_private_dns_zone.pdns_st.name
  resource_group_name = azurerm_resource_group.rg_sa.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.pep_st.private_service_connection.0.private_ip_address]
  depends_on = [
    azurerm_private_endpoint.pep_st,
    azurerm_storage_account.sa
  ]
}
