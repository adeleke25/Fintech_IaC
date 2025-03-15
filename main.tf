# TERRAFORM CONFIG
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
  }
}

# PROVIDERS

provider "azurerm" {
  features {}
}


# NSG Configuration with Proper Rules

# Web Tier NSG
resource "azurerm_network_security_group" "web_nsg" {
  name                = var.web_nsg_name
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Availability Set for Web Tier VMs

resource "azurerm_availability_set" "web_avset" {
  name                         = "web-tier-avset"
  location                     = var.location
  resource_group_name          = var.resource_group
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}


# Database Tier NSG
resource "azurerm_network_security_group" "db_nsg" {
  name                = var.db_nsg_name
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "Allow-SQL-From-Web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.web_tier_subnet[0]
    destination_address_prefix = "*"
  }
}

#Virtual Network (VNet)

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group
}


# Subnet for Web Tier
resource "azurerm_subnet" "web_subnet" {
  name                 = "web-tier-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.web_tier_subnet
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# Subnet for Database Tier
resource "azurerm_subnet" "db_subnet" {
  name                 = "database-tier-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.database_tier_subnet
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}
