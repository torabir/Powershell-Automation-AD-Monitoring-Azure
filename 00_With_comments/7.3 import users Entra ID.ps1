$TenantID = "3b4d7412-b405-4565-920a-a5ecce6638dd"
Connect-MgGraph -TenantId $TenantID -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

$users = Import-CSV -Path '/Users/torarnebirkeland/Downloads/CSV-Users.csv' -Delimiter ","

$PasswordProfile = @{
    Password = 'DemoPassword12345!'
    }
foreach ($user in $users) {
    $Params = @{
        UserPrincipalName = $user.userPrincipalName + "@digsecgr1.onmicrosoft.com"
        DisplayName = $user.displayName
        GivenName = $user.GivenName
        Surname = $user.Surname
        MailNickname = $user.userPrincipalName
        AccountEnabled = $true
        PasswordProfile = $PasswordProfile
        Department = $user.Department
        CompanyName = "InfraIT Sec"
        Country = "Norway"
        City = "Trondheim"
    }
    $Params
    New-MgUser @Params
}


## v gpt: 

$TenantID = "3b4d7412-b405-4565-920a-a5ecce6638dd"
Connect-MgGraph -TenantId $TenantID -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

$users = Import-CSV -Path '/Users/torarnebirkeland/Downloads/CSV-Users.csv' -Delimiter ","

$PasswordProfile = @{
    Password = 'DemoPassword12345!'
    ForceChangePasswordNextSignIn = $false
}

foreach ($user in $users) {
    $Params = @{
        UserPrincipalName = $user.userPrincipalName + "@digsecgr1.onmicrosoft.com"
        DisplayName = $user.displayName
        GivenName = $user.givenName
        Surname = $user.surName
        MailNickname = $user.userLogonName
        AccountEnabled = $true
        PasswordProfile = $PasswordProfile
        Department = if($user.department) { $user.department } else { "Unknown" }
        CompanyName = if($user.company) { $user.company } else { "InfraIT Sec" }
        Country = "Norway"
        City = "Trondheim"
    }

    try {
        New-MgUser @Params
    } catch {
        Write-Warning "Failed to create user $($Params.UserPrincipalName): $_"
        # Håndter feilen etter behov
    }
}
