<#
.Synopsis
Script used to import invoices from SQL Server to Azure Cosmos DB

.Description
Script does work in 3 steps:
1. Imports documents splited by months from the current to oldest specified period to json file.
2. Fixes json formating for nested document lines and saves fixed json file.
3. Exports fixed json file to specified collection in Azure Cosmos DB.
   It creates log files for every month for error debugging purposes (empty log files are deleted).

DocumentDB Data Migration Tool required for the script to work
https://docs.microsoft.com/en-us/azure/cosmos-db/import-data

.Example
.\CosmosDbImport.ps1
#>

# DocumentDB Data Migration Tool path
$dt = 'C:\usr\drop\dt.exe'
if (!(Test-Path $dt)) {
    $dt = Get-ChildItem -Path 'C:\' -Filter 'dt.exe' -File -Recurse -Exclude 'C:\Windows' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if ($null -eq $dt) {
    Write-Host "Error: dt.exe not found.`nPlease install DocumentDB Data Migration Tool from https://aka.ms/csdmtool." -ForegroundColor Red
    Break
}

## Common parameters for exporting data from SQL and importing to CosmosDB
# specify server and database to connect to
$connectionString = 'Server=SqlServerName;Database=DbName;Trusted_Connection=True;'
# specify AccountEndpont (obtained in Keys section of Azure Cosmos DB)
$accountEndpoint = 'https://cosmos-db.documents.azure.com:443/;AccountKey=AccountEndpointKey==;Database=DbName'
# specify collection name
$colName = 'Collection'
# specify local directory where json files will be imported and processed
$workingDir = 'D:\Source\CosmosDbImport'
$loggDir = Join-Path -Path $workingDir -ChildPath 'logs'
## Clean directory with error logs
Get-ChildItem -Path $loggDir -Filter 'errorlog_*.csv' | Remove-Item -Force -ErrorAction SilentlyContinue

## Create list of periods to proceed
$i = 0
[array]$periodsArray = @()
[datetime]$firstPeriod = '2000-01-01'   # earliest period to proceed
[datetime]$lastPeriod = (Get-Date).ToString('yyyy-MM-') + '01'
[datetime]$startDate = Get-Date         # initialize startDate for the loop
while ($startDate -gt $firstPeriod) {
    [datetime]$startDate = $lastPeriod.AddMonths(-$i)
    [datetime]$endDate = ($lastPeriod.AddMonths(-$i + 1)).AddDays(-1)
    $prop = [ordered]@{
        StartDate = $startDate;
        EndDate   = $endDate
    }
    $periodsArray += New-Object -TypeName psobject -Property $prop
    $i = $i + 1
}

## Transfer data from SQL Server to Cosmos DB
foreach ($period in $periodsArray) {
    #$period = $periodsArray[0]
    [string]$startDate = $period.StartDate.ToString('yyyyMMdd')
    [string]$endDate = $period.EndDate.ToString('yyyyMMdd')
    Write-Host ('Proceeding period: ' + $period.StartDate.ToString('yyyy.MM.dd') + ' - ' + $period.EndDate.ToString('yyyy.MM.dd')) -ForegroundColor Magenta
    # set parameters for SQL query
    $sqlQuery = "exec dbo.ImportDocs @startdate = '" + $startDate + "', @enddate = '" + $endDate + "'"
    # set working files names
    $dstFile = Join-Path -Path $workingDir -ChildPath ('dt_' + $startDate + '.json')
    $fixedFile = Join-Path -Path $workingDir -ChildPath ('dtfixed_' + $startDate + '.json')
    $errorLogFile = Join-Path -Path $loggDir -ChildPath ('errorlog_' + $startDate + '.csv')

    # import data from SQL Server for current period
    &$dt /s:SQL /s.ConnectionString:$connectionString /s.Query:$sqlQuery /t:JsonFile /t.File:$dstFile /t.Prettify /t.Overwrite

    # regexp filter definitions to fix json formating for nested invoice lines
    filter repl1 { $_ -replace '"CharColumn1": "\[', '"CharColumn1": [' }
    filter repl2 { $_ -replace '{\\"CharColumn2\\":\\"', '{"CharColumn2":"' }
    filter repl3 { $_ -replace '\\",\\"NumColumn1\\":', '","NumColumn1":' }
    filter repl4 { $_ -replace ',\\"NumColumn2\\":', ',"NumColumn2":' }
    filter repl5 { $_ -replace ',\\"CharColumn3\\":\\"', ',"CharColumn3":"' }
    filter repl6 { $_ -replace '\\"},{', '"},{' }
    filter repl7 { $_ -replace '\\"}]"', '"}]' }
    # clear fixed json file if exists
    if (Test-Path $fixedFile) { Clear-Content $fixedFile }
    Write-Host 'Fixing json formating for nested invoice lines ' -ForegroundColor Cyan -NoNewline
    # fix json formating for nested invoice lines
    $fixDuration = Measure-Command { Get-Content -Raw $dstFile | repl1 | repl2 | repl3 | repl4 | repl5 | repl6 | repl7 | Add-Content $fixedFile }
    Write-Host $fixDuration.ToString('hh\:mm\:ss\.fff') -ForegroundColor Yellow
    # force Garbage Collector to dispose data in memory
    [GC]::Collect()
    Remove-Item $dstFile -Force

    # import json to CosmosDB
    &$dt /s:JsonFile /s.Files:$fixedFile /t:DocumentDB /t.ConnectionString:AccountEndpoint=$accountEndpoint /t.ConnectionMode:Gateway /t.Collection:$colName /ErrorLog:$errorLogFile

    # remove error log file and fixed json file if there were no errors
    $emptyErrorLog = Get-Item -Path $errorLogFile | Where-Object { $_.Length -eq 0 }
    if ($null -ne $emptyErrorLog) {
        Remove-Item $errorLogFile -Force
        Remove-Item $fixedFile -Force
    }
    Write-Output ''
}
