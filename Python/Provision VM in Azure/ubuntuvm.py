from azure.identity import ClientSecretCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient
import os
from config import CLIENT_ID, TENANT_ID, CLIENT_SECRET


# Replace with your service principal credentials
tenant_id =  TENANT_ID 
client_id = CLIENT_ID 
client_secret = CLIENT_SECRET 

subscription_id="5b02b7ae-cb6f-490e-8848-5086652c196f"

resource_group_name = "my-resource-group"
LOCATION = "eastus"

# Define virtual machine parameters
vm_name = "my-vm"
vm_size = "Standard_DS1_v2"  # Replace with your desired VM size
image_publisher = "microsoft-windows-server"
image_offer = "2019-datacenter"
image_sku = "1809-lts"
network_interface_name = "my-nic"
public_ip_name = "my-public-ip"
VNET_NAME = "win-example-vnet"
SUBNET_NAME = "win-example-subnet"

# no virtual networs
#no subnets

# Create a credential object
credential = ClientSecretCredential(tenant_id, client_id, client_secret)

# Create a resource management client
resource_client = ResourceManagementClient(credential, subscription_id)

# Create a resource group

resource_group_params = {
    "location": "eastus"  # Replace with your desired location
}
resource_client.resource_groups.create_or_update(resource_group_name, resource_group_params)
network_client = NetworkManagementClient(credential, subscription_id)

# Create a compute management client
compute_client = ComputeManagementClient(credential, subscription_id)
network_interfaces_operations = network_client.network_interfaces

# Create a network interface
network_interface_params = {
    "name": "myipconfig", #network_interface_name,
    "location": "eastus",  # Replace with your desired location
    "ip_configurations": [
        {
            "name": "ipconfig1",
            "private_ip_allocation_method": "Dynamic",
            "public_ip_address": {
                "id": "/subscriptions/subscription_id/resourceGroups/my-resource-group/providers/microsoft.network/publicIPAddresses/" + public_ip_name
                
            }
        }
    ]
}
network_interface = network_client.network_interfaces.begin_create_or_update(resource_group_name, network_interface_params, network_interface_name)
'''network_interface = network_interfaces_operations.begin_create_or_update(
    resource_group_name,
    network_interface_name,
    network_interface_params
)'''
#network_interface = network_client.network_interfaces.begin_create_or_update(RESOURCE_GROUP_NAME, network_interface_params, network_interface_name)}
#network_interface = network_client.network_interfaces.   network_client.network_interfaces.create_or_update(resource_group_name,network_interface_params, network_interface_name) #compute_client

# Create a virtual machine
vm_params = {
    "location": "eastus",  # Replace with your desired location
    "hardware_profile": {"vm_size": vm_size},
    "storage_profile": {
        "os_disk": {
           # "os_type": "linux",
            "create_option": "from_image",
            "image": {
                "publisher": image_publisher,
                "offer": image_offer,
                "sku": image_sku,
                "version": "latest"
            }
        }
    },
    "network_interfaces": [
        {
            "id": network_interface.id
        }
    ]
}
vm = compute_client.virtual_machines.create_or_update(resource_group_name, vm_name, vm_params)

# Create a public IP address
public_ip_params = {
    "location": "eastus",  # Replace with your desired location
    "sku": {"name": "Standard"}
}
public_ip = compute_client.public_ip_addresses.create_or_update(resource_group_name, public_ip_name, public_ip_params)
