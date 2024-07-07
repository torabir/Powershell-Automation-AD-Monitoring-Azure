## INSTALL THE NECESSARY STUFF:

# Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Import the Az module
# Import-Module Az


## 1. Create resource groups:

# Variables
$tenantID = "3b4d7412-b405-4565-920a-a5ecce6638dd" # Remember to change this to your own TenantID
$subscrptionID = "0294d970-350c-4719-a1d1-43fdc76d3653" # Remember to change this to your own SubscriptionID

# Connect to Azure
Connect-AzAccount -Tenant $tenantID -Subscription $subscrptionID

# Variables - REMEMBER to change $prefix to your own prefix, also, that $location is correct
$prefix = 'tab'
# Resource group:
$resourceGroupName = $prefix + '-rg-network-001'
$location = 'uksouth'

# Create Resource Group for the VNETs with a function
function New-ResourceGroup {
    param (
        [string]$resourceGroupName,
        [string]$location
    )

    # Check if the Resource Group already exists
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    if (-not $resourceGroup) {
        # Resource Group does not exist, so create it
        New-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction Stop
        Write-Output "Created Resource Group: $resourceGroupName in $location"
    } else {
        Write-Output "Resource Group $resourceGroupName already exists."
    }
}


# Create the resource group, if it does not exist
New-ResourceGroup -resourceGroupName $resourceGroupName -location $location

## 2. Create VNET and subnet: 

# This script will create four VNETs with subnets in Azure using the Az module.
# The VNETs and subnets are defined in an array of hash tables, where each hash table represents a VNET configuration.
# It ResourceGroup must be created first before running this script.
# 00-CreatResourceGroup.ps1 script can be used to create the Resource Group.
# The script contains a function New-VNetWithSubnets that creates a VNET with the specified subnets.
# It iterates over each subnet configuration and adds it to the VNET.

#Fjernet definisjoner av prefix etc, siden det står over. 

function New-VNetWithSubnets {
    param (
        [string]$resourceGroupName,
        [string]$location,
        [string]$vnetName,
        [string]$vnetAddressSpace,
        [array]$subnets
    )
    # Check if the Resource Group exists
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    if (-not $resourceGroup) {
        Write-Error "Resource Group $resourceGroupName does not exist. Creates the Resource Group first."
        Write-Host "Run the 00-CreateResourceGroup.ps1 script to create the Resource Group."
    }
    else {
    # Check if the VNET already exists
    $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

    if (-not $vnet) {
        # VNET does not exist, create it
        $vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressSpace -ErrorAction Stop
        Write-Output "Created VNET: $vnetName"
    } else {
        Write-Output "VNET $vnetName already exists."
    }

    # Iterate over each subnet configuration
    foreach ($subnet in $subnets) {
        # Check if the subnet already exists in the VNET
        $subnetConfig = $vnet.Subnets | Where-Object { $_.Name -eq $subnet.Name }

        if (-not $subnetConfig) {
            # Subnet does not exist, add it to the VNET
            $subnetConfig = Add-AzVirtualNetworkSubnetConfig -Name $subnet.Name -AddressPrefix $subnet.AddressPrefix -VirtualNetwork $vnet -ErrorAction Stop
            $vnet | Set-AzVirtualNetwork -ErrorAction Stop
            Write-Output "Added subnet $($subnet.Name) to $vnetName"
        } else {
            Write-Output "Subnet $($subnet.Name) already exists in $vnetName."
        }
    }
}
}

$vnetConfigs = @(
    @{
        Name = "$prefix-vnet-hub-shared-uk"
        AddressSpace = "10.10.0.0/16"
        Subnets = @(
            @{Name = "$prefix-snet-mgmt-prod-uk-001"; AddressPrefix = "10.10.0.0/24"}
        )
    },
    @{
        Name = "$prefix-vnet-web-shared-uk-001"
        AddressSpace = "10.20.0.0/16"
        Subnets = @(
            @{Name = "$prefix-snet-web-prod-uk-001"; AddressPrefix = "10.20.0.0/24"},
            @{Name = "$prefix-snet-app-prod-uk-001"; AddressPrefix = "10.20.1.0/24"},
            @{Name = "$prefix-snet-db-prod-uk-001"; AddressPrefix = "10.20.2.0/24"}
        )
    },
    @{
        Name = "$prefix-vnet-hr-prod-uk-001"
        AddressSpace = "10.30.0.0/16"
        Subnets = @(
            @{Name = "$prefix-snet-hrweb-prod-uk-001"; AddressPrefix = "10.30.0.0/24"},
            @{Name = "$prefix-snet-hrapp-prod-uk-001"; AddressPrefix = "10.30.1.0/24"},
            @{Name = "$prefix-snet-hrdb-prod-uk-001"; AddressPrefix = "10.30.2.0/24"}
        )
    },
    @{
        Name = "$prefix-vnet-hrdev-dev-uk-001"
        AddressSpace = "10.40.0.0/16"
        Subnets = @(
            @{Name = "$prefix-snet-hrweb-dev-uk-001"; AddressPrefix = "10.40.0.0/24"},
            @{Name = "$prefix-snet-hrapp-dev-uk-001"; AddressPrefix = "10.40.1.0/24"},
            @{Name = "$prefix-snet-hrdb-dev-uk-001"; AddressPrefix = "10.40.2.0/24"}
        )
    }
)


# Execution - Create the VNETs with subnets
foreach ($vnetConfig in $vnetConfigs) {
    New-VNetWithSubnets -resourceGroupName $resourceGroupName -location $location -vnetName $vnetConfig.Name -vnetAddressSpace $vnetConfig.AddressSpace -subnets $vnetConfig.Subnets
}


## 3. Create peering hub VNET's

# This script creates peering between the hub and spoke VNETs created in 01-CreateVNET-and-subnet.ps1.
# The script defines a function New-VNetPeering that creates a peering between two VNETs.

function New-VNetPeering {
    param (
        [Parameter(Mandatory=$true)]
        [string]$resourceGroupName,
        [Parameter(Mandatory=$true)]
        [string]$hubVnetName,
        [Parameter(Mandatory=$true)]
        [string]$spokeVnetName,
        [string]$hubToSpokePeeringName = "$hubVnetName-to-$spokeVnetName",
        [string]$spokeToHubPeeringName = "$spokeVnetName-to-$hubVnetName"
    )

    # Fetch the VNET objects
    $hubVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $resourceGroupName
    $spokeVnet = Get-AzVirtualNetwork -Name $spokeVnetName -ResourceGroupName $resourceGroupName

    # Check and create peering from Hub to Spoke
    $existingPeering = Get-AzVirtualNetworkPeering -VirtualNetworkName $hubVnetName -ResourceGroupName $resourceGroupName -Name $hubToSpokePeeringName -ErrorAction SilentlyContinue
    if (-not $existingPeering) {
        Add-AzVirtualNetworkPeering -Name $hubToSpokePeeringName -VirtualNetwork $hubVnet -RemoteVirtualNetworkId $spokeVnet.Id
        Write-Output "Created peering from $hubVnetName to $spokeVnetName."
    } else {
        Write-Output "Peering from $hubVnetName to $spokeVnetName already exists."
    }

    # Check and create peering from Spoke to Hub
    $existingPeering = Get-AzVirtualNetworkPeering -VirtualNetworkName $spokeVnetName -ResourceGroupName $resourceGroupName -Name $spokeToHubPeeringName -ErrorAction SilentlyContinue
    if (-not $existingPeering) {
        Add-AzVirtualNetworkPeering -Name $spokeToHubPeeringName -VirtualNetwork $spokeVnet -RemoteVirtualNetworkId $hubVnet.Id
        Write-Output "Created peering from $spokeVnetName to $hubVnetName."
    } else {
        Write-Output "Peering from $spokeVnetName to $hubVnetName already exists."
    }
}


# Create Peering between VNETs - NOTE! Hardcoded VNET names. These are the same as in the previous scripts.
# Define the hub and spoke VNET names. Names found in 01-CreateVNET-and-subnet.ps1 under $vnetConfigs hashtable.
$hubVnetName = "$prefix-vnet-hub-shared-uk"
$spokeVnetNames = @("$prefix-vnet-web-shared-uk-001", "$prefix-vnet-hr-prod-uk-001", "$prefix-vnet-hrdev-dev-uk-001")

# Loop through each spoke VNET and create peering with the hub
foreach ($spokeVnetName in $spokeVnetNames) {
    New-VNetPeering -resourceGroupName $resourceGroupName -hubVnetName $hubVnetName -spokeVnetName $spokeVnetName
}

## 4. Create Network Security Group (NSG): 

# In this PowerShell script, we will create one Network Security Group
# The NSG will be attached to appropriate subnets in the virtual networks on 04-AttachNSGtoSubnet.ps1.
# Then the script will create a rule that allows for inbound traffic on port 80 and 22.

$nsgName = "$prefix-nsg-port80-22"

# Attempt to fetch an existing NSG
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

# If the NSG doesn't exist, create it
if (-not $nsg) {
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nsgName
}

# Define the rule for HTTP traffic on port 80
$httpRule = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "AllowHTTP" `
    -Description "Allow HTTP traffic" -Access "Allow" -Protocol "Tcp" -Direction "Inbound" `
    -Priority 100 -SourceAddressPrefix "Internet" -SourcePortRange "*" `
    -DestinationAddressPrefix "*" -DestinationPortRange 80 -ErrorAction Stop

# Define the rule for SSH traffic on port 22
$sshRule = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "AllowSSH" `
    -Description "Allow SSH traffic" -Access "Allow" -Protocol "Tcp" -Direction "Inbound" `
    -Priority 110 -SourceAddressPrefix "Internet" -SourcePortRange "*" `
    -DestinationAddressPrefix "*" -DestinationPortRange 22 -ErrorAction Stop

# Update the NSG to include the new rules
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

# Output the updated NSG rules to verify
$nsgUpdated = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName
$nsgUpdated.SecurityRules | Format-Table Name, Access, Protocol, Direction, Priority, SourceAddressPrefix, DestinationPortRange

## 5. Attach NSG to Subnet: 

# This script attaches a NSG to appropriate subnets in the virtual networks created in 01-CreateVNET-and-subnet.ps1.
# This is the following subnets from the previous script:
# Subnets: 
# - $prefix-snet-mgmt-prod-uk-001
# - $prefix-snet-web-prod-uk-001
# - $prefix-snet-hrweb-prod-uk-001
# - $prefix-snet-hrweb-dev-uk-001

# Define subnet names to search for
$targetSubnets = @(
    "$prefix-snet-mgmt-prod-uk-001",
    "$prefix-snet-web-prod-uk-001",
    "$prefix-snet-hrweb-prod-uk-001",
    "$prefix-snet-hrweb-dev-uk-001"
)

# Fetch the NSG
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName

# Retrieve all VNETs in the resource group
$vNets = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName

# Iterate over each VNET
foreach ($vNet in $vNets) {
    # Iterate over each subnet in the current VNET
    foreach ($subnet in $vNet.Subnets) {
        # Check if the current subnet is one of the target subnets
        if ($targetSubnets -contains $subnet.Name) {
            # If so, attach the NSG to this subnet

            # Update the subnet configuration to include the NSG
            $subnetConfig = Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNet -Name $subnet.Name `
                            -AddressPrefix $subnet.AddressPrefix -NetworkSecurityGroup $nsg

            # Apply the updated configuration to the VNET
            $vNet | Set-AzVirtualNetwork
            
            Write-Output "Attached NSG $nsgName to subnet $($subnet.Name) in VNET $($vNet.Name)."
        }
    }
}

## 6. Create Resource Groups for VM's: 

# Create Resource Group for VMs with a function

# Define the prefix for the resource group and resources
function New-ResourceGroup {
    param (
        [string]$resourceGroupName,
        [string]$location
    )

    # Check if the Resource Group already exists
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    if (-not $resourceGroup) {
        # Resource Group does not exist, so create it
        New-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction Stop
        Write-Output "Created Resource Group: $resourceGroupName in $location"
    } else {
        Write-Output "Resource Group $resourceGroupName already exists."
    }
}

# Create the resource group, if it does not exist
New-ResourceGroup -resourceGroupName $resourceGroupName -location $location

## 7. Create VM's for testing: 

# This script creates four VMs in Azure using the Az module.
# The script defines three functions: New-AzurePublicIPs, New-AzureVMNICs, and New-AzureVMs.
# The New-AzurePublicIPs function creates public IP addresses.
# The New-AzureVMNICs function creates network interfaces (NICs) with associated public IP addresses and subnets.
# The New-AzureVMs function creates VMs with the specified NICs.

# Variables 
$prefix = "tab"
$resourceGroupName = "$prefix-rg-vm-001"
$location = "uksouth"
$resourceGroupNameVNET = "$prefix-rg-network-001"


function New-AzurePublicIPs {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable[]]$publicIPconfigs
    )

    foreach ($config in $publicIPconfigs) {
        try {
            # Attempt to create the Public IP Address
            $publicIP = New-AzPublicIpAddress -Name $config.Name `
                                              -ResourceGroupName $config.ResourceGroupName `
                                              -Location $config.Location `
                                              -AllocationMethod $config.AllocationMethod `
                                              -ErrorAction Stop
            Write-Output "Successfully created Public IP Address: $($publicIP.Name) in $($publicIP.Location)"
        }
        catch {
            Write-Error "Failed to create Public IP Address: $($config.Name). Error: $_"
        }
    }
}

function New-AzureVMNICs {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable[]]$nicConfigurations
    )

    foreach ($config in $nicConfigurations) {
        try {
            # Retrieve the Public IP Address object
            $publicIP = Get-AzPublicIpAddress -Name $config.PublicIpAddress -ResourceGroupName $config.ResourceGroupName
            if (-not $publicIP) {
                Write-Error "Public IP Address $($config.PublicIpAddress) not found."
                continue
            }

            # Attempt to retrieve the VNet that contains the target subnet
            $subnet = $null
            $vNets = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupNameVNET
            foreach ($vNet in $vNets) {
                $subnet = $vNet.Subnets | Where-Object { $_.Name -eq $config.Subnet }
                if ($subnet) {
                    break
                }
            }

            if (-not $subnet) {
                Write-Error "Subnet $($config.Subnet) not found."
                continue
            }

            # Create the NIC with the associated Public IP Address and Subnet
            $nic = New-AzNetworkInterface -Name $config.Name `
                                          -ResourceGroupName $config.ResourceGroupName `
                                          -Location $config.Location `
                                          -SubnetId $subnet.Id `
                                          -PublicIpAddressId $publicIP.Id `
                                          -ErrorAction Stop
            Write-Output "Successfully created NIC: $($nic.Name) in $($nic.Location)"
        }
        catch {
            Write-Error "Failed to create NIC: $($config.Name). Error: $_"
        }
    }
}

function New-AzureVMs {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable[]]$vmConfigurations
    )

    foreach ($config in $vmConfigurations) {
        # Retrieve the NIC for the VM
        $nic = Get-AzNetworkInterface -Name $config.NicName -ResourceGroupName $config.ResourceGroupName
        if (-not $nic) {
            Write-Error "NIC $($config.NicName) not found."
            continue
        }

        # Define the VM configuration
        try {
            # Create VM configuration
            $vmConfig = New-AzVMConfig -VMName $config.VMName -VMSize $config.VMSize
            $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $config.VMName -Credential $config.Credential
            $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $config.ImagePublisher -Offer $config.ImageOffer -Skus $config.ImageSku -Version $config.ImageVersion
            $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

            # Create the VM
            New-AzVM -ResourceGroupName $config.ResourceGroupName -Location $config.Location -VM $vmConfig -AsJob -Verbose
            Write-Output "Successfully created VM: $($config.VMName)"
        }
        catch {
            Write-Error "Failed to create VM: $($config.VMName). Error: $_"
        }
    }
}

# Variables for VMs
$vmName1 = "$prefix-vm-mgmt-prod-uk-001"
$vmName2 = "$prefix-vm-web-prod-uk-001"
$vmName3 = "$prefix-vm-hr-prod-uk-001"
$vmName4 = "$prefix-vm-hrdev-dev-uk-001"

# VM configurations - Change username and password
$vmSize = 'Standard_B1s'
$adminUsername = 'tab'
$adminPassword = 'EggEnzfY7sgl!_Fahho4!fsdf'
$secureAdminPassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
$image = 'debian-11'

# pip names
$publicIPName1 = "$prefix-pip-mgmt-prod-uk-001"
$publicIPName2 = "$prefix-pip-web-prod-uk-001"
$publicIPName3 = "$prefix-pip-hr-prod-uk-001"
$publicIPName4 = "$prefix-pip-hrdev-dev-uk-001"

# Subnet names
$subnetName1 = "$prefix-snet-mgmt-prod-uk-001"
$subnetName2 = "$prefix-snet-web-prod-uk-001"
$subnetName3 = "$prefix-snet-hrweb-prod-uk-001"
$subnetName4 = "$prefix-snet-hrweb-dev-uk-001"


    

# Public IP configurations
$publicIPconfigs = @( 
    @{
        Name = $publicIPName1
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }, 
    @{
        Name = $publicIPName2
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }, 
    @{
        Name = $publicIPName3
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }, 
    @{
        Name = $publicIPName4
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }
)

# NIC configurations
$nicConfigurations = @(
    @{
        Name = $vmName1 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName1
        Subnet = $subnetName1
    },
    @{
        Name = $vmName2 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName2
        Subnet = $subnetName2
    },
    @{
        Name = $vmName3 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName3
        Subnet = $subnetName3
    },
    @{
        Name = $vmName4 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName4
        Subnet = $subnetName4
    }
)

# Example VM configuration
$vmConfigurations = @(
    @{
        VMName = $vmName1
        NicName = "$vmName1-nic"
        ResourceGroupName = $resourceGroupName
        Location = $location
        VMSize = $vmSize
        Credential = (New-Object System.Management.Automation.PSCredential ($adminUsername, $secureAdminPassword))
        ImagePublisher = "debian"
        ImageOffer = $image
        ImageSku = "11"
        ImageVersion = "latest"
    },
    @{
        VMName = $vmName2
        NicName = "$vmName2-nic"
        ResourceGroupName = $resourceGroupName
        Location = $location
        VMSize = $vmSize
        Credential = (New-Object System.Management.Automation.PSCredential ($adminUsername, $secureAdminPassword))
        ImagePublisher = "debian"
        ImageOffer = $image
        ImageSku = "11"
        ImageVersion = "latest"
    },
    @{
        VMName = $vmName3
        NicName = "$vmName3-nic"
        ResourceGroupName = $resourceGroupName
        Location = $location
        VMSize = $vmSize
        Credential = (New-Object System.Management.Automation.PSCredential ($adminUsername, $secureAdminPassword))
        ImagePublisher = "debian"
        ImageOffer = $image
        ImageSku = "11"
        ImageVersion = "latest"
    },
    @{
        VMName = $vmName4
        NicName = "$vmName4-nic"
        ResourceGroupName = $resourceGroupName
        Location = $location
        VMSize = $vmSize
        Credential = (New-Object System.Management.Automation.PSCredential ($adminUsername, $secureAdminPassword))
        ImagePublisher = "debian"
        ImageOffer = $image
        ImageSku = "11"
        ImageVersion = "latest"
    }
)


# Call the function to create the Public IPs
New-AzurePublicIPs -publicIPconfigs $publicIPconfigs
Start-Sleep -Seconds 30

# Call the funtion to create the NICs
New-AzureVMNICs -nicConfigurations $nicConfigurations
Start-Sleep -Seconds 30

# Call the function to create the VM(s)
New-AzureVMs -vmConfigurations $vmConfigurations
Start-Sleep -Seconds 480

## 8. List all VM's and ip-addresses with subnets: 

# Retrieve all VMs in the subscription
$vms = Get-AzVM | Where-Object { $_.Name -like "$prefix*" }

# Loop through each VM found
foreach ($vm in $vms) {
    # Get the primary NIC of the VM
    $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id

    # Attempt to retrieve the public IP address associated with the NIC
    $publicIP = $null
    if ($nic.IpConfigurations[0].PublicIpAddress) {
        $publicIpId = $nic.IpConfigurations[0].PublicIpAddress.Id
        $publicIP = Get-AzPublicIpAddress -Name ($publicIpId.Split('/')[-1]) -ResourceGroupName $nic.ResourceGroupName
    }

    # Output VM name, Public IP Address, and Subnet
    $output = @{
        VMName = $vm.Name
        PublicIPAddress = if ($publicIP) { $publicIP.IpAddress } else { "None" }
        Subnet = $nic.IpConfigurations[0].Subnet.Id.Split('/')[-1] # Extract the subnet name
    }

    # Display the information
    $outputObj = New-Object -TypeName PSObject -Property $output
    Write-Output $outputObj
}