# THIS SCRIPT MUST BE RUN AS ADMINISTRATOR ON SRV1, CLI1 and MGR
<# CHECKLIST:
    - Windows Update is up to date
    - Time zone is correct
        -  Set-TimeZone -id 'W. Europe Standard Time' 
    - Computer name is correct
    - IP address is correct (non relevant for this lab)
    - Keyboard layout is correct (Norwegian)
#>

# VM's for the lab needs DC1 IP-address as DNS server (must be done on VM's: SRV1, CLI1 and MGR)
# Why? Because the DNS server is the only one that knows about the domain

# Sett tidssonen til Vest-Europa
Set-TimeZone -Id 'W. Europe Standard Time'

## Må endre til riktig ip adresse (til DC1). kjør ipconfig i terminal på vm, eller finn i openstack (første del)
$ipaddressdc1 = "192.168.111.155" # IP-address of DC1 

Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $ipaddressdc1

# Check if configuration is correct
# Find DNS Servers . . . . . . . . . . . : IP.ADR.TIL.DC (192.168.x.x)
## Sjekk at DNS Servers samsvarer med ipadressen man la inn over: 
ipconfig /all

# Add the computer to the domain, endre domain name
$domainName = "InfraIT.sec"


# legge til brukernavn før @$domainName, skrive inn passord på prompt, 
$cred = Get-Credential -UserName "torabir@$domainName" -Message 'Provide credentials for a domain admin'
Add-Computer -Credential $cred -DomainName $domainName -PassThru -Verbose
Restart-Computer

# When restarted, the computer will be joinedto the domain, and you can log in with a domain admin or user account 

## For å sjekke om det funket, kjør etter restart: 

Get-ComputerInfo | Select-Object CsDomain
#output skal da være: 

# CsDomain   
# --------   
# InfraIT.sec

