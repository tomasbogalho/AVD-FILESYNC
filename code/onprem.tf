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
  address_prefixes     = ["10.0.2.0/24"]
  depends_on = [
    azurerm_virtual_network.onprem_vnet
  ]
}
