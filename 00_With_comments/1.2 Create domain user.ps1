# THIS SCRIPT MUST BE RUN AS ADMINISTRATOR ON DC1

# Define new user parameters
$username = "torabir" # Change this to the desired username, kjør denne
$Password = Read-Host -Prompt 'Enter Password' -AsSecureString ## så denne, så resten
$userPrincipalName = $username + "@" # Change to your domain, 
$displayName = "Tor Arne Birkeland" # Change this to the desired display name
$description = "TAB Domain admin" # Change this to a suitable description
$path = "CN=Users,DC=InfraIT,DC=sec"  # Change the path to the appropriate OU in your AD structure

## finne path: 
Get-ADUser -Filter * | ft ## se på distinguishedname
## Endre path til: $path = "CN=Users,DC=InfraIT,DC=sec" 

# Create the new user, kjør denne: 
New-ADUser -Name $displayName `
            -GivenName $username `
            -UserPrincipalName $userPrincipalName `
            -SamAccountName $username `
            -AccountPassword $password `
            -DisplayName $displayName `
            -Description $description `
            -Path $path `
            -Enabled $true

# Add the new user to the Domain Admins group 
# Denne legger til brukeren $username i gruppa "Domain admins" (tildeler administratorrettigheter)
Add-ADGroupMember -Identity "Domain Admins" -Members $username

## sjekke tilhørighet / admin rettigheter: 
## servermanager --> active directory users and computers, finne brukeren eller "Domain admins", og se "member off" eller "members"


Write-Host "User $username created and added to Domain Admins group." ## kun info