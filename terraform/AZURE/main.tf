
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=2.40.0"
  features {}
}

resource "azurerm_resource_group" "RG1" {
  name     = "basecamp-resources"
  location = "North Europe"
}

#-----------------------------------------------------------------

resource "azurerm_virtual_network" "VNet" {
  name                = "basecamp-network"
  resource_group_name = azurerm_resource_group.RG1.name
  location            = azurerm_resource_group.RG1.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "VNetSubnet1" {
  name                 = "Subnet-1"
  resource_group_name  = azurerm_resource_group.RG1.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "VNetSubnet2" {
  name                 = "Subnet-2"
  resource_group_name  = azurerm_resource_group.RG1.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_network_security_group" "RG1-SG" {
  name                = "SG"
  location            = azurerm_resource_group.RG1.location
  resource_group_name = azurerm_resource_group.RG1.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "VNetSubnet1_sg" {
  subnet_id                 = azurerm_subnet.VNetSubnet1.id
  network_security_group_id = azurerm_network_security_group.RG1-SG.id
}

resource "azurerm_subnet_network_security_group_association" "VNetSubnet2_sg" {
  subnet_id                 = azurerm_subnet.VNetSubnet2.id
  network_security_group_id = azurerm_network_security_group.RG1-SG.id
}

#-----------------------------------------------------------------

resource "azurerm_network_interface" "LocalInt1" {
  name                = "nic1"
  location            = azurerm_resource_group.RG1.location
  resource_group_name = azurerm_resource_group.RG1.name

  ip_configuration {
    name                          = "internal1"
    subnet_id                     = azurerm_subnet.VNetSubnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "LocalInt2" {
  name                = "nic2"
  location            = azurerm_resource_group.RG1.location
  resource_group_name = azurerm_resource_group.RG1.name

  ip_configuration {
    name                          = "internal2"
    subnet_id                     = azurerm_subnet.VNetSubnet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

#-----------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "VM1" {
  name                = "VM1-machine"
  resource_group_name = azurerm_resource_group.RG1.name
  location            = azurerm_resource_group.RG1.location
  size                = "Standard_F2"
  admin_username      = "ujen"
  zone				  = "1"
  network_interface_ids = [
    azurerm_network_interface.LocalInt1.id,
  ]

  admin_ssh_key {
    username   = "ujen"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "VM2" {
  name                = "VM2-machine"
  resource_group_name = azurerm_resource_group.RG1.name
  location            = azurerm_resource_group.RG1.location
  size                = "Standard_F2"
  admin_username      = "ujen"
  zone 				  = "2"
  network_interface_ids = [
    azurerm_network_interface.LocalInt2.id,
  ]

  admin_ssh_key {
    username   = "ujen"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}


#-----------------------------------------------------------------

resource "azurerm_public_ip" "RG1PublicIP" {
  name                = "PublicIPForLB"
  location            = azurerm_resource_group.RG1.location
  resource_group_name = azurerm_resource_group.RG1.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "RG1LoadBalancer" {
  name                = "LoadBalancer"
  location            = azurerm_resource_group.RG1.location
  resource_group_name = azurerm_resource_group.RG1.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.RG1PublicIP.id
  }
}

resource "azurerm_lb_rule" "rule1" {
  resource_group_name            = azurerm_resource_group.RG1.name
  loadbalancer_id                = azurerm_lb.RG1LoadBalancer.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id		 = azurerm_lb_backend_address_pool.BEPool.id
  probe_id						 = azurerm_lb_probe.probe.id
}

resource "azurerm_lb_backend_address_pool" "BEPool" {
  resource_group_name = azurerm_resource_group.RG1.name
  loadbalancer_id     = azurerm_lb.RG1LoadBalancer.id
  name                = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "VM1" {
  network_interface_id    = azurerm_network_interface.LocalInt1.id
  ip_configuration_name   = "internal1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.BEPool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "VM2" {
  network_interface_id    = azurerm_network_interface.LocalInt2.id
  ip_configuration_name   = "internal2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.BEPool.id
}

resource "azurerm_lb_probe" "probe" {
  resource_group_name = azurerm_resource_group.RG1.name
  loadbalancer_id     = azurerm_lb.RG1LoadBalancer.id
  name                = "http-running-probe"
  port                = 80
}