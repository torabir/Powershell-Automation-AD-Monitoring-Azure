# Definer OU for gruppene dine
$OU = "InfraIT_Groups"

# Definer base-OU-path
$ouPath = Get-ADOrganizationalUnit -Filter "Name -eq '$OU'" | Select-Object -ExpandProperty DistinguishedName

# Definer grupper
$globalGroups = @("HR", "IT", "Finance", "Sales", "Consultants", "Managers", "AllEmployees")
$localGroups = @("FileShareHR_Read", "FileShareHR_Write", "FileShareAll_Write", "FileShareAll_Read", "Printers_ManageAccess", "Printers_Access", "FrontDoor_Access")

# Opprett globale grupper
foreach ($group in $globalGroups) {
    $groupName = "g_$group"
    $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $ouPath

    if (-not $existingGroup) {
        New-ADGroup -Name $groupName -GroupCategory Security -GroupScope Global -Path $ouPath -Description "$group global group"
        Write-Host "Created global group: $groupName"
    } else {
        Write-Host "Global group $groupName already exists."
    }
}

# Opprett lokale grupper for hvert department og formål
foreach ($group in $localGroups) {
    foreach ($dept in $globalGroups) {
        if ($dept -eq "AllEmployees" -or $dept -eq "Managers") {
            continue  # Skipper AllEmployees og Managers for lokale ressursgrupper
        }

        $groupName = "$group" + "_$dept"
        $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $ouPath

        if (-not $existingGroup) {
            New-ADGroup -Name $groupName -GroupCategory Security -GroupScope DomainLocal -Path $ouPath -Description "$dept $group local group"
            Write-Host "Created local group: $groupName"
        } else {
            Write-Host "Local group $groupName already exists."
        }
    }
}

# Eksempel på å legge til en bruker i en gruppe basert på avdelingen deres
# Forutsetter at brukerobjektene har korrekt 'Department' attributt satt
foreach ($group in $globalGroups) {
    $groupName = "g_$group"
    $users = Get-ADUser -Filter "Department -eq '$group'" -Properties Department

    foreach ($user in $users) {
        Add-ADGroupMember -Identity $groupName -Members $user.SamAccountName
        Write-Host "Added $($user.SamAccountName) to $groupName"
    }
}


### Denne da? 

# Importer brukerdata fra CSV-filen
$csvPath = "C:\Users\torabir\Downloads\02-01-Users.csv"
$users = Import-Csv -Path $csvPath -Delimiter ";"

foreach ($user in $users) {
    # Konverterer brukerens passord til en sikker streng
    $securePassword = ConvertTo-SecureString -String $user.password -AsPlainText -Force
    
    # Oppretter den nye brukeren i AD
    New-ADUser -Name $user.DisplayName `
               -GivenName $user.GivenName `
               -Surname $user.Surname `
               -SamAccountName $user.username `
               -UserPrincipalName $user.UserPrincipalName `
               -Path $user.path `
               -AccountPassword $securePassword `
               -Department $user.department `
               -Enabled $true
}

# Oppdager unike avdelinger fra brukerlisten for å legge til brukerne i de respektive gruppene
$departments = $users | Select-Object -ExpandProperty department -Unique

foreach ($department in $departments) {
    # Identifiserer gruppenavn basert på avdelingen
    $group = "g_$department"
    
    # Henter alle brukere i den aktuelle avdelingen
    $ADUsers = Get-ADUser -Filter "Department -eq '$department'" -Properties Department
    
    foreach ($adUser in $ADUsers) {
        # Legger til hver bruker i den tilhørende avdelingsgruppen
        Add-ADGroupMember -Identity $group -Members $adUser
    }
}
