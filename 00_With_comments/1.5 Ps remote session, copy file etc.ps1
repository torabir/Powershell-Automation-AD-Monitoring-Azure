# TEST PSREMOTE: Connect-PSRemoting -ComputerName FROM MGR TO WORKSTATIONS/SERVERS IN DOMAIN
Enter-PSSession -ComputerName dc1
Enter-PSSession -ComputerName srv1
Enter-PSSession -ComputerName cl1

# Exit-PSSession

# Her er det mer som må gjøres, blant annet opprette "install" mappe på dc1. se notater. 

# Install PowerShell 7.x on remote machine.
# Enable-PSRemoting -Force <- This command must be run as administrator on remote machine if PSRemote dont work.
# Enable-PSRemoting -Force kjøres på klienter, altså cl1 
$session = New-PSSession -ComputerName dc1 # Følgende legges til etterpå, etter alt annet, og hele linja kjøres så igjen: -ConfigurationName PowerShell.7


## Kopierer fila fra mgr til dc1: 
Copy-Item -Path "C:\install\PowerShell-7.4.1-win-x64.msi" -Destination "C:\install" -ToSession $session
#installerer fila: 
Invoke-Command -Session $session -ScriptBlock {
    Start-Process "msiexec.exe" -ArgumentList "/i C:\install\PowerShell-7.4.1-win-x64.msi /quiet /norestart" -Wait
}
# kjør denne først før neste linje, på nytt: $session = New-PSSession -ComputerName dc1 -ConfigurationName PowerShell.7
# Det er for å bruke PSversion 7 ... 
Invoke-Command -Session $session -ScriptBlock { $PSVersionTable }


# IF PSREMOTE DONT WORK, THIS COMMANDS MUST BE RUN AS ADMINISTRATOR ON VM'S WITH WINDOWS 10/11 
# Enable PSRemote: Enable-PSRemoting -Force
Enable-PSRemoting -Force
winrm set winrm/config/service/auth '@{Kerberos="true"}' 
# List auth: 
winrm get winrm/config/service/auth

# info: 
get-PsSessionConfiguration

# etter 