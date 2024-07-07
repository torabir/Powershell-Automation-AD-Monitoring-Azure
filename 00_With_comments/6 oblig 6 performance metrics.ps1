# Define the output folder and filename for performance metrics
$performanceOutputFile = "C:\install\infrastructure_metrics.csv"

# Define the output folder and filename for service status
$serviceOutputFile = "C:\install\service_status.csv"

# Define the counters for each performance metric
$counterList = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\% Committed Bytes In Use",
    "\Memory\Available MBytes",
    "\PhysicalDisk(_Total)\Disk Transfers/sec",
    "\PhysicalDisk(_Total)\% Disk Time",
    "\LogicalDisk(_Total)\% Free Space",
    "\LogicalDisk(_Total)\Free Megabytes",
    "\Network Interface(*)\Bytes Total/sec",
    "\Network Interface(*)\Current Bandwidth",
    "\Network Interface(*)\Bytes Received/sec",
    "\System\Processes",
    "\System\System Up Time"
)

# Collect counter data
$counterData = Get-Counter -Counter $counterList -SampleInterval 2 -MaxSamples 10

# Exporting only Path, CookedValue, and Timestamp for performance data
$counterData.CounterSamples | Select-Object Path, CookedValue, Timestamp | Export-Csv -Path $performanceOutputFile -NoTypeInformation

# Define the services to monitor for DC1 and SRV1
$servicesDC1 = "NTDS", "DNS", "Kdc", "DFSR", "Netlogon"
$servicesSRV1 = "DFS", "W3SVC"

# Collect and export service status for DC1
$serviceDataDC1 = Get-Service -ComputerName dc1 -Name $servicesDC1 | Select-Object Name, Status, DisplayName
$serviceDataDC1 | Select-Object @{Name='Path'; Expression={$_.DisplayName}}, @{Name='CookedValue'; Expression={$_.Status}}, @{Name='Timestamp'; Expression={Get-Date}} | Export-Csv -Path $serviceOutputFile -NoTypeInformation -Append

# Collect and export service status for SRV1
$serviceDataSRV1 = Get-Service -ComputerName srv1 -Name $servicesSRV1 | Select-Object Name, Status, DisplayName
$serviceDataSRV1 | Select-Object @{Name='Path'; Expression={$_.DisplayName}}, @{Name='CookedValue'; Expression={$_.Status}}, @{Name='Timestamp'; Expression={Get-Date}} | Export-Csv -Path $serviceOutputFile -NoTypeInformation -Append
