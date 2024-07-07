$departmentShares = @("HR-Share", "Consultant-Share", "Finance-Share", "IT-Share", "Sales-Share")
$sharedShare = "Shared-Share"
$serverName = "srv1"
$baseFilePath = "\\infrait.sec\files"

# Itererer gjennom hver avdelingsmappe for å sette tilgangskontroller
foreach ($share in $departmentShares) {
    $acl = Get-Acl -Path "$baseFilePath\$share"
    $department = $share -replace "-Share", ""
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("l_FileShare${department}_FullControll", "FullControl", "Allow")

    # Setter tilgangsregelen, endrer arv, og fjerner BUILTIN\Users tilgang
    $acl.SetAccessRule($accessRule)
    $acl.SetAccessRuleProtection($true, $true)
    $acl.Access | Where-Object {$_.IdentityReference -eq "BUILTIN\Users"} | ForEach-Object { $acl.RemoveAccessRuleSpecific($_) }
    Set-Acl -Path "$baseFilePath\$share" $acl
}

# Setter tilgang for den delte mappen slik at alle har tilgang
$aclShared = Get-Acl -Path "$baseFilePath\$sharedShare"
$aclShared.SetAccessRuleProtection($true, $true)
Set-Acl -Path "$baseFilePath\$sharedShare" $aclShared

# Verifiserer og viser ACL for hver mappe
foreach ($share in $departmentShares + $sharedShare) {
    $acl = Get-Acl -Path "$baseFilePath\$share"
    Write-Host "Access for $share:"
    $acl.Access | Format-Table IdentityReference, FileSystemRights, AccessControlType, IsInherited, InheritanceFlags -AutoSize
    Write-Host "--------------------------------"
}


## tildele tilgang til nettverk: 

# New-PSDrive -Name "H" -PSProvider "FileSystem" -Root "\\infrait.sec\files\HR-Share" -Persist

# ## gi tilgang til delte avdelingsmapper(bytte ut driveLetters): 

# $departments = @("HR", "Consultant", "Finance", "IT", "Sales")
# $driveLetters = @("F", "C", "L", "X", "B")  # Eksempel drevbokstaver, endre som nødvendig

# for ($i = 0; $i -lt $departments.Count; $i++) {
#     $department = $departments[$i]
#     $shareName = "$department-Share"
#     $driveLetter = $driveLetters[$i]
    
#     # Fjerner eksisterende tillatelser og legger til spesifikke for hver avdeling
#     Invoke-Command -ComputerName srv1 -ScriptBlock {
#         param($shareName, $department)
#         Remove-SmbShareAccess -Name $shareName -AccountName "Everyone" -Force -Confirm:$false
#         Grant-SmbShareAccess -Name $shareName -AccountName "InfraIT\$department" -AccessRight Full -Force
#     } -ArgumentList $shareName, $department

#     # Mapper nettverksdrev basert på avdeling
#     # Dette bør gjøres på hver bruker-PC eller via logon script/Group Policy
#     New-PSDrive -Name $driveLetter -PSProvider "FileSystem" -Root "\\infrait.sec\files\$shareName" -Persist
# }


# ## ??? funker ikke ? sjekke DFS replikasjon, på srv1 (backup):

# $departments | ForEach-Object {
#     $repGroup = "RepGrp$($_)-Share"
#     Get-DfsrState -GroupName $repGroup | Select-Object GroupName, State
# }

# Definer de delte mappene og deres respektive avdelingsgrupper
$shareToGroupMapping = @{
    "HR-Share" = "InfraIT\HR";
    "Consultant-Share" = "InfraIT\Consultants";
    "Finance-Share" = "InfraIT\Finance";
    "IT-Share" = "InfraIT\IT";
    "Sales-Share" = "InfraIT\Sales";
    # "Shared-Share" bør være tilgjengelig for alle ansatte, juster etter behov
}

# Iterer over hver mappe og oppdater tilgangene
foreach ($share in $shareToGroupMapping.Keys) {
    $group = $shareToGroupMapping[$share]
    
    # Fjern "Everyone" tilgang
    Remove-SmbShareAccess -Name $share -AccountName "Everyone" -Force -CimSession srv1

    # Legg til riktig gruppetilgang
    if ($share -ne "Shared-Share") {
        Grant-SmbShareAccess -Name $share -AccountName $group -AccessRight Full -CimSession srv1
    } else {
        # Anta at alle ansatte har en gruppe "InfraIT\AllEmployees"
        Grant-SmbShareAccess -Name $share -AccountName "InfraIT\AllEmployees" -AccessRight Full -CimSession srv1
    }
}
