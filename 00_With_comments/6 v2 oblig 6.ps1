$rootpath = "C:\install"
$htmlOutputFile = "$rootpath\performanceReport.html"

# Definere performance counter kategorier som skal samles
$counterList = @(
    '\Processor(_Total)\% Processor Time',
    '\Memory\% Committed Bytes In Use',
    '\Memory\Available MBytes',
    '\PhysicalDisk(_Total)\Disk Transfers/sec',
    '\PhysicalDisk(_Total)\% Disk Time',
    '\LogicalDisk(_Total)\% Free Space',
    '\LogicalDisk(_Total)\Free Megabytes',
    '\Network Interface(*)\Bytes Total/sec',
    '\Network Interface(*)\Current Bandwidth',
    '\Network Interface(*)\Bytes Received/sec'
)

# ScriptBlock for å samle data
$scriptBlock = {
    param($counterList)
    $data = @()
    foreach ($counter in $counterList) {
        $data += Get-Counter $counter | ForEach-Object { $_.CounterSamples }
    }
    return $data
}

# Kjøre datainnsamlingen hver time i 24 timer for DC1 og SRV1
$resultsDC1 = @()
$resultsSRV1 = @()

for ($i = 0; $i -lt 24; $i++) {
    $resultsDC1 += Invoke-Command -ComputerName DC1 -ScriptBlock $scriptBlock -ArgumentList $counterList
    $resultsSRV1 += Invoke-Command -ComputerName SRV1 -ScriptBlock $scriptBlock -ArgumentList $counterList
    Start-Sleep -Seconds 3600 # Vent i en time
}

# Samle inn og strukturere data for visualisering
function ConvertTo-JSArray ($results, $pathFilter) {
    $jsArray = @()
    foreach ($sample in $results) {
        if ($sample.Path -like $pathFilter) {
            $timestamp = $sample.Timestamp.ToString("MM/dd/yyyy HH:mm:ss")
            $jsArray += "[`"$timestamp`", $($sample.CookedValue)]"
        }
    }
    return $jsArray -join ", "
}

$processorTimeDataDC1 = ConvertTo-JSArray -results $resultsDC1 -pathFilter '*\Processor(_Total)\% Processor Time'
$memoryDataDC1 = ConvertTo-JSArray -results $resultsDC1 -pathFilter '*\Memory\% Committed Bytes In Use'
$diskDataDC1 = ConvertTo-JSArray -results $resultsDC1 -pathFilter '*\PhysicalDisk(_Total)\Disk Transfers/sec'

$processorTimeDataSRV1 = ConvertTo-JSArray -results $resultsSRV1 -pathFilter '*\Processor(_Total)\% Processor Time'
$memoryDataSRV1 = ConvertTo-JSArray -results $resultsSRV1 -pathFilter '*\Memory\% Committed Bytes In Use'
$diskDataSRV1 = ConvertTo-JSArray -results $resultsSRV1 -pathFilter '*\PhysicalDisk(_Total)\Disk Transfers/sec'

# Generere HTML rapport
$htmlTemplate = @"
<html>
<head>
    <title>Performance Report for DC1 and SRV1</title>
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <script type="text/javascript">
        google.charts.load('current', {'packages':['corechart']});
        google.charts.setOnLoadCallback(drawCharts);

        function drawCharts() {
            var processorTimeDataDC1 = [$processorTimeDataDC1];
            var memoryDataDC1 = [$memoryDataDC1];
            var diskDataDC1 = [$diskDataDC1];

            var processorTimeDataSRV1 = [$processorTimeDataSRV1];
            var memoryDataSRV1 = [$memoryDataSRV1];
            var diskDataSRV1 = [$diskDataSRV1];

            drawChart('processorTime_chart_dc1', 'DC1 - % Processor Time', processorTimeDataDC1);
            drawChart('memory_chart_dc1', 'DC1 - % Committed Bytes In Use', memoryDataDC1);
            drawChart('disk_chart_dc1', 'DC1 - Disk Transfers/sec', diskDataDC1);

            drawChart('processorTime_chart_srv1', 'SRV1 - % Processor Time', processorTimeDataSRV1);
            drawChart('memory_chart_srv1', 'SRV1 - % Committed Bytes In Use', memoryDataSRV1);
            drawChart('disk_chart_srv1', 'SRV1 - Disk Transfers/sec', diskDataSRV1);
        }

        function drawChart(elementId, title, dataRows) {
            var data = new google.visualization.DataTable();
            data.addColumn('string', 'Time');
            data.addColumn('number', title);
            data.addRows(dataRows);

            var options = {
                title: title,
                curveType: 'function',
                legend: { position: 'bottom' },
                hAxis: { title: 'Time' },
                vAxis: { title: 'Value' }
            };

            var chart = new google.visualization.LineChart(document.getElementById(elementId));
            chart.draw(data, options);
        }
    </script>
</head>
<body>
    <h1>Performance Report for DC1 and SRV1</h1>
    <div id="processorTime_chart_dc1" style="width: 700px; height: 300px;"></div>
    <div id="memory_chart_dc1" style="width: 700px; height: 300px;"></div>
    <div id="disk_chart_dc1" style="width: 700px; height: 300px;"></div>
    <div id="processorTime_chart_srv1" style="width: 700px; height: 300px;"></div>
    <div id="memory_chart_srv1" style="width: 700px; height: 300px;"></div>
    <div id="disk_chart_srv1" style="width: 700px; height: 300px;"></div>
</body>
</html>
"@

$htmlTemplate | Out-File -FilePath $htmlOutputFile -Force
Write-Host "Performance report saved to: $htmlOutputFile"
