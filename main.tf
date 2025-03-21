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

#Load Balancer. Note that Standard SKU Load Balancer requires Standard SKU Public IP

#Public IP for Load Balance

resource "azurerm_public_ip" "lb_public_ip" {
  name                = "lb-public-ip"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

#Azure Load Balancer

resource "azurerm_lb" "web_lb" {
  name                = "web-tier-lb"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "web-frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }
}

#Backend Address Pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "web_backend_pool" {
  name            = "web-backend-pool"
  loadbalancer_id = azurerm_lb.web_lb.id

}


#What is a Backend Address Pool in Azure Load Balancer?
#A Backend Address Pool is a collection of virtual machines (VMs) or network interfaces (NICs) that receive incoming traffic distributed by the Load Balancer.

#In simple terms:

#Backend Address Pool = List of servers (VMs) behind the Load Balancer to handle traffic.

#When you set up a Load Balancer, you want to distribute traffic (like HTTP requests) to multiple VMs for:

#High availability (if one VM fails, traffic goes to others)
#Scalability (handling more traffic by adding more VMs)
#The Backend Pool is where you define those VMs/NICs that should receive traffic.#

#Health Probe for Port 80 (HTTP)
resource "azurerm_lb_probe" "http_probe" {
  name                = "http-health-probe"
  loadbalancer_id     = azurerm_lb.web_lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

#Load Balancing Rule (HTTP on Port 80)
resource "azurerm_lb_rule" "http_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "web-frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend_pool.id] # Use a list
  probe_id                       = azurerm_lb_probe.http_probe.id
}


#Adding Web Tier VMs to Backend Pool
#When you define network interfaces (NICs) for each Web VM, you must associate them to the backend pool

resource "azurerm_network_interface_backend_address_pool_association" "web_vm_nic_lb" {
  count                   = 2 # Assuming 2 web VMs
  network_interface_id    = azurerm_network_interface.web_nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id
}

#Web Tier VMs (Loop to create 2 instances)

resource "azurerm_windows_virtual_machine" "web_vm" {
  count                 = var.web_vm_count
  name                  = "web-vm-${count.index + 1}"
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.web_vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  availability_set_id   = azurerm_availability_set.web_avset.id
  network_interface_ids = [azurerm_network_interface.web_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "web_nic" {
  count               = var.web_vm_count
  name                = "nic-web-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Database Tier VM (Single Instance)
resource "azurerm_windows_virtual_machine" "db_vm" {
  name                  = "database-vm-1"
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.db_vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.db_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "db_nic" {
  name                = "nic-db-1"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Azure Key Vault to store and manage secrets like db connection str

resource "azurerm_key_vault" "kv" {
  name                = "keyvaultfintech1"
  location            = var.location
  resource_group_name = var.resource_group
  tenant_id           = var.tenant_id
  sku_name            = "standard"
}

#Store a Database Connection String
#resource "azurerm_key_vault_secret" "db_connection" {
 # name         = "db-connection-string"
  #value        = "Server=mydbserver.database.windows.net;Database=mydb;User Id=myuser;Password=mypassword;"
  #key_vault_id = azurerm_key_vault.kv.id
#}


#Create a Recovery Services Vault
resource "azurerm_recovery_services_vault" "backup_vault" {
  name                = "backup-vault"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Standard"
}


#Enable Backup for a Virtual Machine

resource "azurerm_backup_policy_vm" "backup_policy" {
  name                = "daily-backup-policy"
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }
}


#Backup Protection
resource "azurerm_backup_protected_vm" "vm_backup" {
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault.name
  source_vm_id        = azurerm_windows_virtual_machine.web_vm[0].id
  backup_policy_id    = azurerm_backup_policy_vm.backup_policy.id
}

