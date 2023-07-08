#!/usr/bin/env bash

subscription="Visual Studio Professional Subscription"
resourceGroup="change-my-ip-eastus-rg"
location="eastus"
vmName="change-my-ip-eastus-debian-vm" 
image="Debian11"
size="Standard_B1ls"
publicIpSku="Standard"
random=$RANDOM
temporarySshKey="$HOME/.ssh/azure_temporary_ssh_key"
azureUser="azureuser"

# Colors
colorOff='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'

# TODO
# 1. az login -> get active subscription
#   {
#     "cloudName": "AzureCloud",
#     "homeTenantId": "xxxxxxxxxxxx-xxxx-xxxxx-xxxxx-xxxxxxxxxxxxx",
#     "id": "f6b61c58-e42e-4ddb-9bfc-efc2eec69263",
#     "isDefault": true,
#     "managedByTenants": [],
#     "name": "Visual Studio Professional Subscription",
#     "state": "Enabled",
#     "tenantId": "xxxxxxxxxxx-xxxx-xxxxx-xxxxx-xxxxxxxxxxxxx",
#     "user": {
#       "name": "user_name@email.com",
#       "type": "user"
#     }
#   },

# 2. az feature register --namespace "Microsoft.Compute" --name "EncryptionAtHost"
# {
#   "id": "/subscriptions/xxxxxxxxxxx-xxxx-xxxxx-xxxxx-xxxxxxxxxxxxx/providers/Microsoft.Features/providers/Microsoft.Compute/features/EncryptionAtHost",
#   "name": "Microsoft.Compute/EncryptionAtHost",
#   "properties": {
#     "state": "Registering"
#   },
#   "type": "Microsoft.Features/providers/features"
# }



if [[ $1 == "enable" ]] || [[ $1 == "--enable" ]] || [[ $1 == "-e" ]]; then
    # Create temporary ssh key without answearing questions
    echo "Creating SSH keys..."
    ssh-keygen -t rsa -f "$temporarySshKey" -q -P ""
    echo -e "$green SSH keys have been created successfully.$colorOff"

    az account set --subscription "$subscription" 1>/dev/null

    echo "Creating a resource group..."
    az group create --name $resourceGroup --location $location 1>/dev/null
    echo -e "$green Resource group has been created successfully.$colorOff"
    
    echo "Creating a virtual machine..."
    az vm create \
    --resource-group "$resourceGroup" \
    --name "$vmName" \
    --image "$image" \
    --size "$size" \
    --admin-username "$azureUser" \
    --ssh-key-values "$temporarySshKey".pub \
    --encryption-at-host true \
    --public-ip-sku "$publicIpSku" > /tmp/publicIpAddress_$random
    echo -e "$green Virtual Machine has been created successfully.$colorOff"
    
    echo -e "$green All required resources have been created successfully.$colorOff"
    
    echo ""
    echo -e "$red Be aware of:$colorOff"
    echo " Before executing '$0 disable' be sure that you don't have any important manually created resources in the $resourceGroup resource group."

    # Parse json and map publicIpAddress value to a variable
    publicIpAddress=$(python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["publicIpAddress"])' < /tmp/publicIpAddress_$random)

    echo "SOCKS5 server is running. Don't forget to set up your browser."
    echo "Recommended browser - Mozilla Firefox https://www.mozilla.org"
    echo "Recommended browser addon - FoxyProxy https://getfoxyproxy.org"
    echo ""
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -D 9999 -i "$temporarySshKey" "$azureUser"@"$publicIpAddress"

elif [[ $1 == "disable" ]] || [[ $1 == "--disable" ]] || [[ $1 == "-d" ]]; then
    echo -e "$yellow Resources in the $resourceGroup resource group are going to be destroyed in 10 seconds.$colorOff"
    echo -e "$yellow Ctrl+C could be your last chance to stop this.$colorOff"

    sleep 10

    # Destroy all resources inside a resource group
    echo "Starting destroying the resources..."
    az group delete --name $resourceGroup --yes
    echo -e "$green All resources have been destroyed successfully.$colorOff"

    echo "Deleting SSH keys..."
    rm -f "$temporarySshKey"*
    echo -e "$green SSH keys have been deleted successfully.$colorOff"
else
    echo -e "$yellow Please provide the required arguments. Acceptable arguments: enable, --enable, -e or disable, --disable, -d.$colorOff"
fi
