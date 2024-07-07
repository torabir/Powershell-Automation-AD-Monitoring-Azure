$tenantID = "3b4d7412-b405-4565-920a-a5ecce6638dd" # Remember to change this to your own TenantID
$subscrptionID = "0294d970-350c-4719-a1d1-43fdc76d3653" # Remember to change this to your own SubscriptionID

# Connect to Azure
Connect-AzAccount -Tenant $tenantID -Subscription $subscrptionID

# Define the prefix to search for VMs
$prefix = "tab"

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