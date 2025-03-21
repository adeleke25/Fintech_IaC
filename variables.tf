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

variable "tenant_id" {
  default = "b5f5b805-7416-41f5-98c2-13ffa56c9410"
}




