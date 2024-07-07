# Description: This script is used to connect to Azure using the Az module
# Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Import the Az module
# Import-Module Az

# Get-Command -Verb New -Noun AzVirtualNetwork* -Module Az.Network

# Variables - Remember to change these to your own TenantID and SubscriptionID found in the Azure Portal
$tenantID = "bd0944c8-c04e-466a-9729-d7086d13a653"
$subscrptionID = "41082359-57d6-4427-b5d9-21e269157652"

# Connect to Azure
Connect-AzAccount -Tenant $tenantID -Subscription $subscrptionID


# Variables
$prefix = 'tim'
# Resource group:
$rgName = $prefix + '-rg-powershelldemo-001'
$location = 'uksouth'

# VNET:
$vnetName = $prefix + '-vnet-powershelldemo-002'
$addressPrefix = '10.10.0.0/16'

# SUBNET:
$subnetName = $prefix + '-snet-powershelldemo-002'
$subnetAddressPrefix = '10.10.0.0/24'



# Create Resource group
$rg = @{
    Name = $rgName
    Location = $location
}
New-AzResourceGroup @rg

# Create VNET
$vnet = @{
    Name = $vnetName
    ResourceGroupName = $rgName
    Location = $location
    AddressPrefix = $addressPrefix
}
$virtualNetwork = New-AzVirtualNetwork @vnet

# Create Subnet
$subnet = @{
    Name = $subnetName
    VirtualNetwork = $virtualNetwork
    AddressPrefix = $subnetAddressPrefix
}
$subnetConfig = Add-AzVirtualNetworkSubnetConfig @subnet

$virtualNetwork | Set-AzVirtualNetwork