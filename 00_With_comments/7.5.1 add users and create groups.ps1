# This script adds users to their department security group in Microsoft Entra Identity
# and creates the group if it does not exist.

# Scriptet krever at det ligger verdier inne på bl.a. Department. 
# Scriptet tar ikke høyde for store og små bokstaver eller små forskjeller som "consultant" og "consultants".


$TenantID = "3b4d7412-b405-4565-920a-a5ecce6638dd" # Change this to your own TenantID
Connect-MgGraph -TenantId $TenantID -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

$rootFolder = "/Users/torarnebirkeland/Downloads"
$prefix = "s_"
$suffix = "_group"

$usersAddedToGroup = @()
$usersNotAddedToGroup = @()
$groupsCreated = @()
$groupsNotCreated = @()

$users = Get-MgUser -All -Property Department, UserPrincipalName, Id |
    Where-Object { $_.Department -ne $null -and $_.Department -ne '' } | 
    Select-Object Department, UserPrincipalName, Id

foreach ($user in $users) {
    $groupDisplayName = $prefix + $user.Department + $suffix
    $existingGroup = Get-MgGroup -Filter "displayName eq '$groupDisplayName'"

    if (-not $existingGroup) {
        try {
            Write-Host "Creating group $groupDisplayName" -ForegroundColor Green
            $group = New-MgGroup -DisplayName $groupDisplayName -MailEnabled:$false -MailNickname $groupDisplayName -SecurityEnabled:$true
            $groupsCreated += $groupDisplayName
        }
        catch {
            Write-Host "Failed to create group $groupDisplayName" -ForegroundColor Red
            $groupsNotCreated += $groupDisplayName
            continue
        }
    }

    $groupId = $existingGroup.Id

    try {
        Write-Host "Adding user $($user.UserPrincipalName) to group $groupDisplayName" -ForegroundColor Green
        New-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id 
        $usersAddedToGroup += $user.UserPrincipalName
    }
    catch {
        Write-Host "Failed to add user $($user.UserPrincipalName) to group $groupDisplayName" -ForegroundColor Red
        $usersNotAddedToGroup += $user.UserPrincipalName
    }
}

# Convert to objects for CSV export
$groupsCreated | ForEach-Object { [PSCustomObject]@{GroupName = $_} } | Export-Csv "$rootFolder/groups_created.csv" -NoTypeInformation -Encoding UTF8
$groupsNotCreated | ForEach-Object { [PSCustomObject]@{GroupName = $_} } | Export-Csv "$rootFolder/groups_not_created.csv" -NoTypeInformation -Encoding UTF8
$usersAddedToGroup | ForEach-Object { [PSCustomObject]@{UserPrincipalName = $_} } | Export-Csv "$rootFolder/users_added_to_group.csv" -NoTypeInformation -Encoding UTF8
$usersNotAddedToGroup | ForEach-Object { [PSCustomObject]@{UserPrincipalName = $_} } | Export-Csv "$rootFolder/users_not_added_to_group.csv" -NoTypeInformation -Encoding UTF8
