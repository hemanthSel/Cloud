import os
import time
from dotenv import load_dotenv
import paramiko
from azure.identity import ClientSecretCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient

#LOAD & RETRIEVE VARIABLES FROM ENVIRONMENT
load_dotenv()
tenant_id =   os.getenv('TENANT_ID')  
client_id = os.getenv('CLIENT_ID') 
client_secret = os.getenv('CLIENT_SECRET') 
subscription_id = os.getenv('SUBSCRIPTION_ID')
PASSWORD = os.getenv('PASSWORD')

#INITIALZE LOCAL VARIABLES 
LOCATION = "EastUs"
RESOURCE_GROUP_NAME = "linux-VM-rg"
public_ip_name = "my-public-ip"
VNET_NAME = "linux-vnet"
SUBNET_NAME = "liunx-subnet" 
NIC_NAME = "linux-nic"
VM_NAME = "linuxAzureVM"
USERNAME = "azureuser"


# Set up the credentials
credential= ClientSecretCredential(tenant_id, client_id, client_secret)
resource_client = ResourceManagementClient(credential, subscription_id)
#CREATE RESOURCE GROUP
rg_result = resource_client.resource_groups.create_or_update(RESOURCE_GROUP_NAME, {"location": LOCATION})
network_client = NetworkManagementClient(credential, subscription_id)
poller = network_client.virtual_networks.begin_create_or_update(
    RESOURCE_GROUP_NAME,
    VNET_NAME,
    {
        "location": LOCATION,
        "address_space": {"address_prefixes": ["10.0.0.0/16"]},
    },    
)
vnet_result = poller.result()
print("vnet results: ", RESOURCE_GROUP_NAME, vnet_result.address_space )
#CREATE SUBNET 
subnet_result = network_client.subnets.begin_create_or_update(
    RESOURCE_GROUP_NAME,
    VNET_NAME,
    SUBNET_NAME,
    {"address_prefix": "10.0.0.0/24"},
).result()

print("SUBNET results: ", subnet_result.address_prefix)

# Create Network Security Group
new_nsg_name = "new_nsg"
new_nsg = {
    "location": "EastUs",
    "security_rules": [
        {
            "name": "allow_ssh",
            "priority": 300,
            "direction": "Inbound",
            "protocol": "Tcp",
            "source_port_range": "*",
            "destination_port_range": "22",
            "source_address_prefix": "*",
            "destination_address_prefix": "*",
            "access": "Allow"
        },
        {
            "name": "allow_http",
            "priority": 310,
            "direction": "Inbound",
            "protocol": "Tcp",
            "source_port_range": "*",
            "destination_port_range": "80",
            "source_address_prefix": "*",
            "destination_address_prefix": "*",
            "access": "Allow"
        }
    ]
}
nsg = network_client.network_security_groups.begin_create_or_update(
    RESOURCE_GROUP_NAME, new_nsg_name, new_nsg
).result()

print(f"Network Security Group '{nsg.id}' created successfully!")

#ASSING IP ADDRESS
poller = network_client.public_ip_addresses.begin_create_or_update(
RESOURCE_GROUP_NAME,
public_ip_name,
{
 "location": LOCATION,
 "sku": {"name": "Standard"},
 "public_ip_allocation_method": "Static",
 "public_ip_address_version": "IPV4",
 },
)
ip_address_result = poller.result()

print("ip addressresults: ", ip_address_result.ip_address )

#CREATE NIC
poller = network_client.network_interfaces.begin_create_or_update(
    RESOURCE_GROUP_NAME,
    NIC_NAME,
    {
        "location": LOCATION,
        "ip_configurations": [
            {
                "name": "ipconfig1",
                 "subnet": {"id": subnet_result.id}, 
                   "public_ip_address": {"id": ip_address_result.id},
            }
        ], #LINK NIC TO NSG
        "network_security_group": {
                "id": nsg.id
        }
    },
)     
nic_result = poller.result()

compute_client = ComputeManagementClient(credential, subscription_id)

network_interface_params = {
    "name":"myIPConfig", #
    "location": "EastUs", 
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

print(f"Provisioning virtual machine {VM_NAME}; this operation might take a few minutes.")

#PROVISION VM
poller = compute_client.virtual_machines.begin_create_or_update(
    RESOURCE_GROUP_NAME,
    VM_NAME,
    {
        "location": LOCATION,
        "storage_profile": {
            "image_reference": {
                "publisher":"Canonical", 
                "offer": "UbuntuServer",
                "sku": "18.04-LTS",
                "version": "latest",
            }
        },
        "hardware_profile": {"vm_size": "Standard_DS1_v2"}, 
        "os_profile": {
            "computer_name": VM_NAME,
            "admin_username": USERNAME,
            "admin_password": PASSWORD,
        },
        "network_profile": {
            "network_interfaces": [
                {
                    "id":nic_result.id
                }
            ]
        },
    },
)


time.sleep(50)
# Create a SSH CONNECTION to execute commands
ssh_client =  paramiko.SSHClient()
print("ssh_client connection started:>>>>>>>>>>>")
ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

ssh_client.connect(ip_address_result.ip_address,username=USERNAME, password=PASSWORD)

print("ssh_client connection started:>>>>>>>>>>>")
# Execute the inline commands
for commands in [
    "#!/bin/bash",
    "set -e",
    "set -x",
    "sudo apt-get update || { echo 'apt-get update failed'; exit 1; }",
    "sudo apt-get install -y redis || { echo 'redis installation failed'; exit 1; }",
    "sudo systemctl start redis",
    "sudo systemctl enable redis"
]:
   # for command in commands:
        stdin, stdout, stderr = ssh_client.exec_command(commands)
        print(stdout.read().decode())
    