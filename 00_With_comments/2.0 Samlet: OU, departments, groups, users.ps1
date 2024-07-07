


# Define the root organizational units (OUs)
$rootOU = "InfraIT"
$infrait_users = "InfraIT_Users"
$infrait_groups = "InfraIT_Groups"
$infrait_computers = "InfraIT_Computers"

$topOUs = @($infrait_users,$infrait_groups,$infrait_computers )

# Define the departmental OUs
$departments = @('HR', 'IT', 'Consultants', 'Sales', 'Finance')

# Create the root and departmental OUs
New-ADOrganizationalUnit -Name $rootOU -ProtectedFromAccidentalDeletion:$false
foreach ($ou in @($infrait_users, $infrait_groups, $infrait_computers)) {
    $ouPath = "OU=$rootOU,DC=InfraIT,DC=sec"
    New-ADOrganizationalUnit -Name $ou -Path $ouPath -ProtectedFromAccidentalDeletion:$false
    foreach ($dept in $departments) {
        $deptOUPath = "OU=$ou,$ouPath"
        New-ADOrganizationalUnit -Name $dept -Path $deptOUPath -ProtectedFromAccidentalDeletion:$false
    }
}

# Create the departmental groups in InfraIT_Groups OU
foreach ($dept in $departments) {
    $groupPath = "OU=$infrait_groups,OU=$rootOU,DC=InfraIT,DC=sec"
    New-ADGroup -Name "g_$dept" `
                -SamAccountName "g_$dept" `
                -GroupCategory Security `
                -GroupScope Global `
                -DisplayName "$dept" `
                -Path $groupPath `
                -Description "$dept group"
}

## Alt over dette var for oblig 2. Resten er litt ymse. 

# Assume your user data is well-prepared in a CSV file
$csvPath = "C:\Users\torabir\dcst1005 git\dcst1005\02-01-Users.csv"

# Import user data from CSV file and create user accounts
$users = Import-Csv -Path $csvPath
foreach ($user in $users) {
    $userOUPath = "OU=$($user.Department),OU=$infrait_users,OU=$rootOU,DC=InfraIT,DC=sec"
    $userPassword = ConvertTo-SecureString -String $user.Password -AsPlainText -Force
    New-ADUser -Name "$($user.givenName) $($user.surName)" `
                -GivenName $user.givenName `
                -Surname $user.surName `
                -SamAccountName $user.username `
                -UserPrincipalName $user.UserPrincipalName `
                -Path $userOUPath `
                -AccountPassword $userPassword `
                -Enabled $true
    # Add the user to the corresponding department group
    Add-ADGroupMember -Identity "g_$dept" -Members $user.username
}

# Verify the structure
Get-ADOrganizationalUnit -Filter 'Name -like "InfraIT*"' | Select-Object Name, DistinguishedName
Get-ADGroup -Filter 'Name -like "g_*"' | Select-Object Name, GroupScope, GroupCategory, DistinguishedName


## groups. Ikke kjørt, har benyttet den i 2.1: 

# Define the root and top level organizational units (OUs) variables already defined
$rootOU = "InfraIT"
$infrait_groups = "InfraIT_Groups"

# Define the departmental OUs - assuming these are already created
$departments = @('HR', 'IT', 'Consultants', 'Sales', 'Finance')

# Base path for the groups OU
$groupsOUPath = "OU=$infrait_groups,OU=$rootOU,DC=InfraIT,DC=sec"

# Iterate over each department to create a group inside InfraIT_Groups
foreach ($dept in $departments) {
    # Define the group name using your naming convention
    $groupName = "g_$dept"
    
    # Check if the group already exists to avoid duplication errors
    $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $groupsOUPath
    
    if ($existingGroup) {
        Write-Host "Group $groupName already exists in $groupsOUPath."
    } else {
        # Create the new AD group under the specific department in InfraIT_Groups
        New-ADGroup -Name $groupName `
                    -SamAccountName $groupName `
                    -GroupCategory Security `
                    -GroupScope Global `
                    -DisplayName $dept `
                    -Path $groupsOUPath `
                    -Description "$dept department group"
                    
        Write-Host "Created group $groupName in $groupsOUPath."
    }
}


##### ANGRE DEN OVER (slette grupper): 

# Define the root and groups organizational units (OUs) variables
$rootOU = "InfraIT"
$infrait_groups = "InfraIT_Groups"

# Define the departmental groups - assuming you want to delete these
$departments = @('HR', 'IT', 'Consultants', 'Sales', 'Finance')

# Base path for the groups OU
$groupsOUPath = "OU=$infrait_groups,OU=$rootOU,DC=InfraIT,DC=sec"

# Iterate over each department to find and delete the group in InfraIT_Groups
foreach ($dept in $departments) {
    # Define the group name using your naming convention
    $groupName = "g_$dept"
    
    # Try to retrieve the group from AD
    $group = Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $groupsOUPath
    
    # Check if the group exists and delete it
    if ($group) {
        # Remove the group
        Remove-ADGroup -Identity $group -Confirm:$false
        Write-Host "Removed group $groupName from $groupsOUPath."
    } else {
        Write-Host "Group $groupName does not exist in $groupsOUPath."
    }
}


###### script for å opprette all_employes, boardmembers og headofdepartments: 

# Definerte OU variabler
$OU = "InfraIT_Groups"
$ouPath = Get-ADOrganizationalUnit -Filter "Name -eq '$OU'" | Select-Object -ExpandProperty DistinguishedName

# Definerer og oppretter nye grupper
$additionalGroups = @("BoardMembers", "HeadsOfDepartments", "AllEmployees")

foreach ($group in $additionalGroups) {
    $groupName = "g_$group"
    
    # Sjekker om gruppen eksisterer
    $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $ouPath

    if (-not $existingGroup) {
        New-ADGroup -Name $groupName `
                    -SamAccountName $groupName `
                    -GroupCategory Security `
                    -GroupScope Global `
                    -DisplayName $groupName `
                    -Path $ouPath `
                    -Description "$group group"
        Write-Host "Created group $groupName."
    } else {
        Write-Host "Group $groupName already exists."
    }
}

## Angre scriptet over: 

# Definerte OU variabler
$OU = "InfraIT_Groups"
$ouPath = Get-ADOrganizationalUnit -Filter "Name -eq '$OU'" | Select-Object -ExpandProperty DistinguishedName

# Definerer gruppene som skal slettes
$groupsToDelete = @("g_BoardMembers", "g_HeadsOfDepartments", "g_AllEmployees")

foreach ($group in $groupsToDelete) {
    $existingGroup = Get-ADGroup -Filter "Name -eq '$group'" -SearchBase $ouPath

    if ($existingGroup) {
        Remove-ADGroup -Identity $existingGroup -Confirm:$false
        Write-Host "Removed group $group."
    } else {
        Write-Host "Group $group does not exist."
    }
}
