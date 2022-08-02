terraform {
  required_version = "~>v1.2.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.16.0"
    }
  }
}

provider "azurerm" {
  features {
  }
}

variable "myprefix" {
  type        = string
  description = "default value of an resource"
  default     = "dummy"
}

resource "azurerm_resource_group" "rg" {
  name     = var.myprefix
  location = "eastus"
  tags = {
    "env" = "dev"
  }
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "${var.myprefix}1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    "env" = "dev"
    "dep" = "001"
  }
}