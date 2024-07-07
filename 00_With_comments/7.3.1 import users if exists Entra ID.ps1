## Legger først til noe ekstra (TAB) i displayName if exists, 
## og legger deretter til 123 på mail og mailnavn if exists (FUNKER): 

$TenantID = "3b4d7412-b405-4565-920a-a5ecce6638dd"
Connect-MgGraph -TenantId $TenantID -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

$users = Import-CSV -Path '/Users/torarnebirkeland/Downloads/CSV-Users.csv' -Delimiter ","

$PasswordProfile = @{
    Password = 'DemoPassword12345!'
}

foreach ($user in $users) {
    $UPN = $user.userPrincipalName + "@digsecgr1.onmicrosoft.com"
    $DisplayName = $user.displayName
    $MailNickname = $user.userPrincipalName

    # Fjern '-All' og korrekt bruk Get-MgUser for å sjekke DisplayName
    try {
        $UserCheck = Get-MgUser -Filter "displayName eq '$DisplayName'"
    } catch {
        Write-Warning "Unable to check for existing user: $_"
    }

    if ($null -ne $UserCheck) {
        $DisplayName += " (TAB)"
    }

    $Params = @{
        UserPrincipalName = $UPN
        DisplayName = $DisplayName
        GivenName = $user.GivenName
        Surname = $user.Surname
        MailNickname = $MailNickname
        AccountEnabled = $true
        PasswordProfile = $PasswordProfile
        Department = $user.Department
        CompanyName = "InfraIT Sec"
        Country = "Norway"
        City = "Trondheim"
    }

    try {
        New-MgUser @Params
    } catch {
        # Håndter feil relatert til UserPrincipalName eller MailNickname
        $Params.UserPrincipalName = $user.userPrincipalName + "123@" + "digsecgr1.onmicrosoft.com"
        $Params.MailNickname += "123"

        try {
            New-MgUser @Params
        } catch {
            Write-Warning "Failed to create user after adjustments: $_"
        }
    }
}
