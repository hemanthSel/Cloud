# pro
provider "azurerm" {
  #version 4.0.1
  subscription_id = var.SubscriptionId
  features {}
   /* resource_group {
      preventprevent_deletion_if_contains_resources = false
    }
│   }
*/
}
resource "azurerm_resource_group" "this" {
  name = var.ResourceGroupName
  location = var.Location
}
#This NSG will define security rules to control inbound and outbound network traffic  for resources associated with it
resource "azurerm_network_security_group" "firewall" {
  name                = "${var.VmName}--nsg"
   location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
# Port "22" allows SSH access
  security_rule {
    name                       = "nsg-rule"
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
  name                = "${var.VmName}--ip"
   location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
}
#The NIC allows the VM to connect  to the virtual network and access the internet 
resource "azurerm_network_interface" "nic" {
  name                = "${var.VmName}--nic"
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
resource "azurerm_virtual_network" "vnet" {
  name = var.VirtualNetwork
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_subnet" "nw_group" {
    name = "default"
    address_prefixes = ["10.0.0.0/24"]
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name = azurerm_resource_group.this.name
}
  resource "azurerm_subnet_network_security_group_association" "asso" {
  subnet_id                 = azurerm_subnet.nw_group.id
  network_security_group_id = azurerm_network_security_group.firewall.id  
}


resource "azurerm_virtual_machine" "ngx" {
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
    computer_name  = "ubuntu-nginxt"
    admin_username = "hemanth"
    admin_password = "Twilight@123"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  provisioner "remote-exec" {
    
    connection {
    
      type     = "ssh"
      user     = "hemanth"
      password = "Twilight@123"
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
      # Install NGINX
      "sudo apt-get install -y nginx || { echo 'nginx installation failed'; exit 1; }",
      # Start nginx service
      "sudo systemctl start nginx",
      # Enable Apache2 service to start on boot
      "sudo systemctl enable nginx" ,
      "echo 'print(\"Hello from Terraform!\")' > /tmp/hello.py",
      "exit 0"
    ]    
    
  }
  tags = {
    environment = "dev"
  }
}

