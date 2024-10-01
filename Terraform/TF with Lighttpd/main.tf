# pro
provider "azurerm" {
  #version 4.0.1
  subscription_id = var.SubscriptionId
  features {}
}
#create resource group
resource "azurerm_resource_group" "this" {
  name = var.ResourceGroupName
  location = var.Location
}
#This NSG will define security rules to control inbound and outbound network traffic  for resources associated with it
resource "azurerm_network_security_group" "firewall" {
  name                = "${var.VmName}-vm"
   location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
# Port "22" allows SSH access
  security_rule {
    name                       = "tpd-rule"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  } 
  # Port “80" allows Http access.
  security_rule {
    name                 = "allow-http"
    description         = "Allow inbound HTTP traffic"
    protocol            = "Tcp"
    direction           = "Inbound"
    priority            = 320
    source_port_range    = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    access              = "Allow"
  }
}
#This  ip address will be assigned to the VM for external accessibility
resource "azurerm_public_ip" "pip" {
  name                = "${var.VmName}-ip"
   location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
}
#The NIC allows the VM to connect to the virtual network and access the internet 
resource "azurerm_network_interface" "nic" {
  name                = "${var.VmName}-nic"
 location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
# Define IP configuration for NIC
  ip_configuration {
    name                          = "public_ip_con"
    subnet_id                     = azurerm_subnet.nw_group.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}
#create Vnet for the VM
resource "azurerm_virtual_network" "vnet" {
  name = var.VirtualNetwork
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}
#create Network group for the VM
resource "azurerm_subnet" "nw_group" {
    name = "default"
    address_prefixes = ["10.0.0.0/24"]
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name = azurerm_resource_group.this.name
}
# associate NIC to the VM and NSG
  resource "azurerm_subnet_network_security_group_association" "asso" {
  subnet_id                 = azurerm_subnet.nw_group.id
  network_security_group_id = azurerm_network_security_group.firewall.id  
}
# read user name from terminal
variable "user" {
  description = "read username from command"
  type        = string
  
}
# read password from terminal
variable "pwd" {
  description = "read pwd from terminal"
  type        = string
  sensitive = true  
}
# display the ip address assigned to the VM
output "new_ip"{
    value= azurerm_public_ip.pip.ip_address
    sensitive = false
}
# VM name
output "mname"{
    value= azurerm_virtual_machine.tpd.name
    sensitive = false
}
#create VM
resource "azurerm_virtual_machine" "tpd" {
  name                  = var.VmName
   location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DC1s_v2"
  
  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy" 
    sku       = "22_04-lts-gen2"              
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 30 
    os_type           = "Linux"

  }
  os_profile {
    computer_name  = "ubuntu-tpd"
    admin_username =  var.user
    admin_password = var.pwd
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  # run the bash  commads on the VM server to deploy Lighttpd
  provisioner "remote-exec" {
    
    connection {
    
      type     = "ssh"
      user     = var.user
      password = var.pwd
      host     =  azurerm_public_ip.pip.ip_address
      timeout  = "5m" 
    }
    
    inline = [
        
      #!/bin/bash
      # Update package lists
        "#!/bin/bash",
        "set -e",
        "set -x",     
      "echo 'This command might fail initially'",
      #!/bin/bash
      "sudo apt-get update || { echo 'apt-get update failed'; exit 1; }",
      # Install lighttpd
      "sudo apt-get install -y lighttpd || { echo 'lighttpd installation failed'; exit 1; }",
      # Start lighttpd service
      "sudo systemctl start lighttpd",
      # Enable lighttpd service to start on boot
      "sudo systemctl enable lighttpd" ,
      "exit 0"
    ]    
  }
  
  tags = {
    environment = "dev"
  }
}

