# REMEMER TO READ THE COMMENTS - THIS IS NOT A SCRIPT TO RUN FROM START TO END :) 
# This commands are used to find the commands that are related to Active Directory
Get-Command -Module ActiveDirectory | Where-Object {$_.name -like "*user*"}
Get-Command -Module ActiveDirectory | Where-Object {$_.name -like "*group*"}
Get-Command -Module ActiveDirectory | Where-Object {$_.name -like "*OrganizationalUnit*"}

#############################################################################
#                                                                           #
#     I denne gjennomgangen skal vi gjøre følgende fra MGR:                 #
#       1. Opprette OU-struktur i AD for brukere, maskiner og grupper       #
#       2. Opprette grupper som skal representere en eksempelbedrift        #
#       3. Opprette brukere som skal:                                       #
#             - Plasseres i ønsket OU                                       #
#             - Meldes inn i tiltenkt gruppe for tilganger                  #
#             - Sørge for at de for logget seg inn på ønsket maskin (cl1)   #
#                                                                           #
#                                                                           #
#                                                                           #
#                                                                           #
#############################################################################

New-ADOrganizationalUnit "TestOU" `
            -Description "TEst for å sjekk at cmdlet fungerer" `
            -ProtectedFromAccidentalDeletion:$false
Get-ADOrganizationalUnit -Filter * | Select-Object name
Get-Help Remove-ADOrganizationalUnit -Online
Get-ADOrganizationalUnit -Filter * | Where-Object {$_.name -eq "TestOU"} | Remove-ADOrganizationalUnit -Recursive -Confirm:$false

# Eksempelbedrift - LearnIT - MERK!!! Video brukt i 2023, navn vil variere fra tidligere gjennomgang
# HUSK Å TA STILLING TIL HVOR DU VIL LAGRE OU-ER, GRUPPER OG BRUKERE OG NAVN DERE BRUKER
$lit_users = "LearnIT_Users"
$lit_groups = "LearnIT_Groups"
$lit_computers = "LearnIT_Computers"

$topOUs = @($lit_users,$lit_groups,$lit_computers )
$departments = @('hr','it','consultants','sales','finance')

foreach ($ou in $topOUs) {
    New-ADOrganizationalUnit $ou -Description "Top OU for LearnIT" -ProtectedFromAccidentalDeletion:$false
    #Frem til hit i loopen er selve opprettelsen av OUene (lit_users osv)
    $topOU = Get-ADOrganizationalUnit -Filter * | Where-Object {$_.name -eq "$ou"}
    #Get-ADOrganizationalUnit -Filter * | Where-Object {$_.name -eq $ou} | Remove-ADOrganizationalUnit -Recursive -Confirm:$false
        foreach ($department in $departments) {
            New-ADOrganizationalUnit $department `
                        -Path $topOU.DistinguishedName `
                        -Description "Deparment OU for $department in topOU $topOU" `
                        -ProtectedFromAccidentalDeletion:$false
        }
}

# Opprette grupper
# ----Group Structure----- #

# Finne ut hvilke kommandoer som er tilgjengelig for å opprette grupper - ONLINE
Get-Help New-ADGroup -Online

New-ADGroup -Name "g_TestGruppe" `
            -SamAccountName g_TestGruppe `
            -GroupCategory Security `
            -GroupScope Global `
            -DisplayName "Test" `
            -Path "CN=Users,DC=core,DC=sec" `
            -Description "Test"

##Denne oppretter globale grupper under samtlige departments , feks g_HR: 

foreach ($department in $departments) {
    $path = Get-ADOrganizationalUnit -Filter * | 
            Where-Object {($_.name -eq "$department") `
            -and ($_.DistinguishedName -like "OU=$department,OU=$InfraIT_groups,*")}
    New-ADGroup -Name "g_$department" `
                -SamAccountName "g_$department" `
                -GroupCategory Security `
                -GroupScope Global `
                -DisplayName "g_$department" `
                -Path $path.DistinguishedName `
                -Description "$department group"
}

### Denne oppretter globale manager groups for hver department: 

# Definerer rot-OU og gruppe-OU variabler
$rootOU = "InfraIT"
$infrait_groups = "InfraIT_Groups"

# Definerer avdelings-OUer
$departments = @('HR', 'IT', 'Consultants', 'Sales', 'Finance')

foreach ($dept in $departments) {
    # Angir banen til avdelings-spesifikke OUer under InfraIT_Groups
    $deptGroupOUPath = "OU=$dept,OU=$infrait_groups,OU=$rootOU,DC=InfraIT,DC=sec"
    
    # Definerer gruppenavn for ledere innen hver avdeling
    $managerGroupName = "g_${dept}_Managers"
    
    # Sjekker om gruppen allerede eksisterer for å unngå duplikater
    $existingGroup = Get-ADGroup -Filter "Name -eq '$managerGroupName'" -SearchBase $deptGroupOUPath
    
    # Oppretter gruppen hvis den ikke eksisterer
    if (-not $existingGroup) {
        New-ADGroup -Name $managerGroupName `
                    -SamAccountName $managerGroupName `
                    -GroupCategory Security `
                    -GroupScope Global `
                    -DisplayName "$dept Managers" `
                    -Path $deptGroupOUPath `
                    -Description "Managers for $dept department"
        Write-Host "Created group $managerGroupName in $deptGroupOUPath."
    } else {
        Write-Host "Group $managerGroupName already exists in $deptGroupOUPath."
    }
}

### Opprette lokale grupper direkte under InfraIT_groups (for tilganger etc), oppretter først en ny mappe "resources", så de lokale gruppene:

# Definerte OU-variabler
$rootOU = "InfraIT"
$infrait_resources = "InfraIT_Resources"

# Sjekker om ressurs-OU eksisterer, og oppretter hvis den ikke finnes
$existingResourceOU = Get-ADOrganizationalUnit -Filter "Name -eq '$infrait_resources'" -SearchBase "OU=$rootOU,DC=InfraIT,DC=sec"
if (-not $existingResourceOU) {
    New-ADOrganizationalUnit -Name $infrait_resources -Path "OU=$rootOU,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion:$false
}

# Definerer base-OU-path for ressursgrupper
$resourceOUPath = "OU=$infrait_resources,OU=$rootOU,DC=InfraIT,DC=sec"

# Definerer og oppretter lokale grupper for filressursdeling og annet
$localGroups = @("FileShareAll_Read", "FileShareAll_Write", "Printers_ManageAccess", "Printers_Access", "FrontDoor_Access")

foreach ($lg in $localGroups) {
    # Sjekker om gruppen eksisterer
    $existingGroup = Get-ADGroup -Filter "Name -eq '$lg'" -SearchBase $resourceOUPath

    if (-not $existingGroup) {
        New-ADGroup -Name $lg -GroupCategory Security -GroupScope DomainLocal -Path $resourceOUPath -Description "$lg group"
        Write-Host "Created local group $lg in $resourceOUPath."
    } else {
        Write-Host "Local group $lg already exists in $resourceOUPath."
    }
}

# Oppretter tilsvarende lokale grupper spesifikke for hver avdeling
$departments = @('HR', 'IT', 'Consultants', 'Sales', 'Finance')

foreach ($dept in $departments) {
    foreach ($accessType in @("Read", "Write")) {
        $groupName = "FileShare${dept}_${accessType}"
        
        # Sjekker om gruppen eksisterer
        $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $resourceOUPath

        if (-not $existingGroup) {
            New-ADGroup -Name $groupName -GroupCategory Security -GroupScope DomainLocal -Path $resourceOUPath -Description "$dept file share $accessType access group"
            Write-Host "Created local group $groupName in $resourceOUPath."
        } else {
            Write-Host "Local group $groupName already exists in $resourceOUPath."
        }
    }
}

## opprette én ny gruppe:

New-ADGroup -name "g_all_employee" `
            -SamAccountName "g_all_employee" `
            -GroupCategory Security `
            -GroupScope Global `
            -DisplayName "g_all_employee" `
            -path "OU=LearnIT_Groups,DC=core,DC=sec" `
            -Description "all employee"


# ----Create Users ----- #
<#
The easy way or the "hard" way? (advanced - AD liker ikke æ,ø,å. Kanskje en også bør ha en navnestandard? 
Easy way - Brukere uten noen særnorske tegn og ingen vasking av input data
#>

Get-Help New-AdUSer -Online

## Opprett ÉN ny bruker: 

$password = Read-Host -Prompt "EnterPassword" -AsSecureString
New-ADUser -Name "Hans Hansen" `
            -GivenName "Hans" `
            -Surname "Hansen" `
            -SamAccountName "hhansen" `
            -UserPrincipalName "hhansen@InfraIT.sec" `
            -Path "OU=IT,OU=InfraIT_Users,OU=InfraIT,DC=InfraIT,DC=sec" `
            -AccountPassword $Password `
            -Enabled $true


## Opprette flere brukere fra cvs-fil: 
# HUSK å vis til egen csv fil med brukere (-path viser her en type windows-path)
$users = Import-Csv -Path "C:\Users\torabir\Downloads\02-01-Users.csv" -Delimiter ";"

foreach ($user in $users) {
    New-ADUser -Name $user.DisplayName `
                -GivenName $user.GivenName `
                -Surname $user.Surname `
                -SamAccountName  $user.username `
                -UserPrincipalName  $user.UserPrincipalName `
                -Path $user.path `
                -AccountPassword (convertto-securestring $user.password -AsPlainText -Force) `
                -Department $user.department `
                -Enabled $true
            }

# Legger til brukere i grupper basert på avdeling (department)
$ADUsers = @()

foreach ($department in $departments) {
    $ADUsers = Get-ADUser -Filter {Department -eq $department} -Properties Department
    #Write-Host "$ADUsers som er funnet under $department"

    foreach ($aduser in $ADUsers) {
        Add-ADPrincipalGroupMembership -Identity $aduser.SamAccountName -MemberOf "g_$department"
    }

}

## jeg endte opp med, for å legge brukere inn i grupper (etter å lagt de inn manuelt i users): 

$departments = 'HR', 'IT', 'Consultants', 'Sales', 'Finance'

foreach ($department in $departments) {
    # Definerer brukerens OU og gruppeens OU
    $userOUPath = "OU=$department,OU=InfraIT_Users,OU=InfraIT,DC=InfraIT,DC=sec"
    $groupOUPath = "OU=$department,OU=InfraIT_Groups,OU=InfraIT,DC=InfraIT,DC=sec"
    $groupName = "g_$department"

    # Henter alle brukere i den aktuelle OU og legger dem til i den tilsvarende gruppen
    $ADUsers = Get-ADUser -Filter * -SearchBase $userOUPath
    
    foreach ($adUser in $ADUsers) {
        # Konstruerer fullt kvalifisert gruppenavn (DN)
        $groupDN = "CN=$groupName,$groupOUPath"

        # Legger til hver bruker i den tilsvarende gruppen
        Add-ADGroupMember -Identity $groupDN -Members $adUser.SamAccountName
    }
}
 




# ---- Move Computer to correct OU ---- #
Get-ADComputer -Filter * | ft
Move-ADObject -Identity "CN=mgr,CN=Computers,DC=core,DC=sec" `
            -TargetPath "OU=it,OU=LearnIT_Computers,DC=core,DC=sec"

New-ADOrganizationalUnit "Servers" `
                -Description "OU for Servers" `
                -Path "OU=LearnIT_Computers,DC=core,DC=sec" `
                -ProtectedFromAccidentalDeletion:$false