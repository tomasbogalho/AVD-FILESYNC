terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
  backend "azurerm" {
    resource_group_name  = "RG_Terraform_Manangement"
    storage_account_name = "saerrmanangement4388"
    container_name       = "terraformstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.arm_subscription_id
  tenant_id = var.arm_tenant_id
  client_id = var.arm_client_id
}