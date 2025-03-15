variable "web_vm_size" {
  default = "Standard_D2s_v3" # 2 vCPU, 8GB RAM
}

variable "db_vm_size" {
  default = "Standard_D4s_v3" # 4 vCPU, 16GB RAM
}

variable "web_vm_count" {
  default = 2 # Web tier VMs
}

variable "admin_username" {
  default = "adminuser"
}

variable "admin_password" {
  default = "admin123@@" # Consider using secret management in production
}

variable "location" {
  default = "canadacentral"
}

variable "resource_group" {
  default = "rg-ladedoyin-training-cc-001"
}

variable "vnet_name" {
  default = "vnet-dev-web-001"
}

variable "address_space" {
  default = ["10.0.0.0/16"]
}

variable "web_tier_subnet" {
  default = ["10.0.1.0/24"]
}

variable "database_tier_subnet" {
  default = ["10.0.2.0/24"]
}

variable "web_nsg_name" {
  default = "nsg-web-tier"
}

variable "db_nsg_name" {
  default = "nsg-database-tier"
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

