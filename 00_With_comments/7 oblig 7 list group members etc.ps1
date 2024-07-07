

### 
# Tenant ID for Azure
$TenantID = "3b4d7412-b405-4565-920a-a5ecce6638dd"

# Connect to Microsoft Graph
Connect-MgGraph -TenantId $TenantID -Scopes "Group.Read.All", "User.Read.All"

# Get all groups
$groups = Get-MgGroup -All

# Initialize the list to hold group and member information
$groupMembersList = @()

# Iterate through each group to get its members
foreach ($group in $groups) {
    $members = Get-MgGroupMember -GroupId $group.Id -All
    
    foreach ($member in $members) {
        # Determine if the member is a user and has display information
        if ($member['@odata.type'].Contains("user")) {
            $userDetails = Get-MgUser -UserId $member.Id
            $displayName = $userDetails.DisplayName
            $email = $userDetails.Mail
        } else {
            $displayName = $member.DisplayName
            $email = $member.Mail
        }

        $groupMembersList += [PSCustomObject]@{
            GroupId = $group.Id
            GroupName = $group.DisplayName
            MemberId = $member.Id
            MemberType = $member['@odata.type'].Split('.')[-1]
            MemberDisplayName = $displayName
            MemberEmail = $email
        }
    }
}

# Define the path for the CSV file
$csvFilePath = "/Users/torarnebirkeland/Downloads/groupMembers.csv"

# Export the list to a CSV file
$groupMembersList | Export-Csv -Path $csvFilePath -NoTypeInformation

# Output a completion message
Write-Output "Export completed. The group and member data has been saved to $csvFilePath"


