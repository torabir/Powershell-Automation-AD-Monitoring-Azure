## 5.1

# Define the computer name for the remote session
$remoteComputerName = "srv1"

# Create a new PowerShell session to the remote computer
$session = New-PSSession -ComputerName $remoteComputerName

# Define the directory to be created on the remote computer
$newDirectory = "C:\shares\installfiles"

# Create the new directory on the remote computer
Invoke-Command -Session $session -ScriptBlock {
    param($newDirectory)
    
    # Check if the directory already exists
    if(-not (Test-Path $newDirectory)) {
        # Create the directory if it does not exist
        New-Item -ItemType Directory -Path $newDirectory
        Write-Output "Directory created: $newDirectory"
    } else {
        Write-Output "Directory already exists: $newDirectory"
    }
} -ArgumentList $newDirectory

# Close the PowerShell session
Remove-PSSession -Session $session

## 5.2

# Define the computer name for the remote session
$remoteComputerName = "srv1"

# Define the directory to be shared
$directoryPath = "C:\shares\installfiles"

# Define the share name
$shareName = "InstallFiles"

# Create a new PowerShell session to the remote computer
$session = New-PSSession -ComputerName $remoteComputerName

# Share the folder and set NTFS permissions
Invoke-Command -Session $session -ScriptBlock {
    param($directoryPath, $shareName)
    
    # Share the folder on the network with read access for Everyone
    New-SmbShare -Name $shareName -Path $directoryPath -ReadAccess 'Everyone'
    
    <# Set NTFS permission to read-only for Everyone
    # Get the ACL of the directory
    $acl = Get-Acl $directoryPath
    # Create a new FileSystemAccessRule
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    # Add the FileSystemAccessRule to the ACL
    $acl.SetAccessRule($accessRule)
    # Set the modified ACL back to the directory
    Set-Acl -Path $directoryPath -AclObject $acl
    #>
    Write-Output "Folder shared with read access for Everyone."
} -ArgumentList $directoryPath, $shareName

# Close the PowerShell session
Remove-PSSession -Session $session

## 5.3

<#
Description: This script creates a shared folder and adds it as a folder target to a DFS Namespace folder.
If the shared folder already exists, it will be reused and added as a folder target to the DFS Namespace folder.
If it is already shared, the script will add it as a folder target to the DFS Namespace folder.
#>
# Define the folder name, shared folder path, and share name
$folderName = "installfiles"
$sharedFolderPath = "C:\shares\installfiles"
$shareName = "installfiles" # The share name should match the DFS folder target share name

# Define the DFS Namespace path and the target path for the DFS folder
$dfsNamespace = "\\infrait.sec\files" # Adjust this to your actual DFS Namespace root
$dfsFolderPath = "$dfsNamespace\$folderName"
$targetPath = "\\srv1\$shareName"

# Script block to check if the folder is already shared, create the shared folder, and add it as a DFSN folder target
$scriptBlock = {
    param($folderName, $sharedFolderPath, $shareName, $dfsFolderPath, $targetPath)

    # Check if the shared folder already exists
    $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue

    # Create the directory if it does not exist
    if (-not (Test-Path -Path $sharedFolderPath)) {
        New-Item -ItemType Directory -Path $sharedFolderPath
    }

    # Share the directory if it is not already shared
    if ($null -eq $existingShare) {
        New-SmbShare -Name $shareName -Path $sharedFolderPath -FullAccess 'Everyone'
        Write-Host "Folder shared as $shareName."
    } else {
        Write-Host "Folder is already shared as $shareName."
    }

    # Check if the DFS folder target already exists
    $existingDfsTarget = Get-DfsnFolderTarget -Path $dfsFolderPath -ErrorAction SilentlyContinue

    # Add the folder target to DFS Namespace if it does not exist
    if ($existingDfsTarget -eq $null) {
        New-DfsnFolder -Path $dfsFolderPath -TargetPath $targetPath -ErrorAction SilentlyContinue
        New-DfsnFolderTarget -Path $dfsFolderPath -TargetPath $targetPath
        Write-Host "DFS folder target added for $shareName."
    } else {
        Write-Host "DFS folder target for $shareName already exists."
    }
}

# Execute the script block on the remote server srv1 with the defined parameters
Invoke-Command -ComputerName srv1 -ScriptBlock $scriptBlock -ArgumentList $folderName, $sharedFolderPath, $shareName, $dfsFolderPath, $targetPath

## 5.4

# Define the URL of the file to download
$fileUrl = "https://www.7-zip.org/a/7z2401-x64.msi"

# Define the destination path on the remote server
$destinationPath = "C:\shares\installfiles\7z2401-x64.msi"

# Define the remote server name
$remoteServerName = "srv1"

# Script block to download the file
$scriptBlock = {
    param($fileUrl, $destinationPath)
    
    # Use Invoke-WebRequest to download the file
    Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
    Write-Host "File downloaded to $destinationPath"
}

# Execute the script block on the remote server
Invoke-Command -ComputerName $remoteServerName -ScriptBlock $scriptBlock -ArgumentList $fileUrl, $destinationPath