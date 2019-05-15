<#
.Synopsis
Script querying list of SQL servers about their version, physical server name, SP, CU, KB, IP/Port
.Description
Script is querying all server specified in SQLServers.csv file. The file includes columns:
- SQLServer : SLQ Server Name
- Env       : Environment (Prod, Stage, Test, Dev)
- License   : SQL Server license type
- Desc      : Server description
At first sript invokes SQL query to retrieve information, if it fails it tries to get this the information from the registry.
If it finds SQL Server working in cluster it retrieves list of inactive nodes and query them too.
.Example
& ".\SQLServerVersions.ps1"
& ".\SQLServerVersions.ps1" -RegCheck 0 -OutTerminal 1
& ".\SQLServerVersions.ps1" -RegCheck 1 -OutTerminal 1
& ".\SQLServerVersions.ps1" -RegCheck 1 -OutTerminal 0 -CheckOtherNodes 1
& ".\SQLServerVersions.ps1" -RegCheck 0 -OutTerminal 1 -CheckOtherNodes 1
#>
param (
    [int]$RegCheck          = 0,    # 1 - checking remotely servers getting SQL information from registry
    [int]$OutTerminal       = 0,    # 1 - returns information on the terminal instead of CSV
    [int]$CheckOtherNodes   = 0     # 1 - returns information about inactive cluster nodes
)

<# Initial parameters required for the script to work correctly #>
$myAdminSQL = 'AdminSQLServer'      # Server name for table including all SQL Versions
$myAdminDB  = 'AdminDB'             # DB Name with table from sp_Blitz procect
$sqlServers = Import-Csv -Path '.\SQLServers.csv'
if ($RegCheck -eq 1 -or $CheckOtherNodes -eq 1) {
    $credsadm = Import-CliXml -Path "$($env:USERPROFILE)\adm.cred" # administrative credential required to log in to Windows Servers
}

$qrySrvInfo = "/* Check SQL Server Version, Edition and Hostname */
    select top 1
        serverproperty('ServerName') as SQLServerName
       ,isnull(serverproperty('InstanceName'), 'MSSQLSERVER') as InstanceName
       ,serverproperty('ComputerNamePhysicalNetBIOS') as MachineName
       ,case
               when charindex('-', @@version) < charindex('(', @@version) then left(@@version, charindex('-', @@version) - 2)
               else left(@@version, charindex('(', @@version) - 2)end as ServerVersion
       ,serverproperty('ProductLevel') as ProductLevel
       ,serverproperty('ProductUpdateLevel') as UpdateLevel
       ,serverproperty('ProductUpdateReference') as KB
       ,serverproperty('ProductVersion') as ProductVersion
       ,c.local_net_address as LocalAddress
       ,c.local_tcp_port as LocalPort
       ,serverproperty('Edition') as ServerEdition
       ,serverproperty('IsClustered') as IsClustered
       ,i.cpu_count as Cores
    from
        sys.dm_exec_connections as c
        cross join sys.dm_os_sys_info as i
    where
        c.local_tcp_port is not null"

function Invoke-SQL {
    param(
        [string] $ServerInstance,
        [string] $Database = 'master',
        [string] $Query
    )
    $connectionString = "Data Source=$ServerInstance; " +
                        "Integrated Security=SSPI; " +
                        "Initial Catalog=$Database"
    $connection = New-Object system.data.SqlClient.SQLConnection($connectionString)
    $command = New-Object system.data.sqlclient.sqlcommand($Query, $connection)
    $connection.Open()
    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    $connection.Close()
    $dataSet.Tables
}

function Get-SqlRegProperties {
    param(
        [string] $SrvName,
        [string] $InstName,
        [string] $Env,
        [string] $License,
        [string] $Desc
    )
    $sqlServersReg = Invoke-Command -ComputerName $SrvName -Credential $credsadm -ScriptBlock {
        $numCores = ((Get-CIMInstance -Class 'CIM_Processor').NumberOfLogicalProcessors | Measure-Object -Sum).Sum
        $MachineName = $env:COMPUTERNAME
        $sqlInstances = Get-Item 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction 'SilentlyContinue'
        if ($using:InstName -eq '') {
            $instanceNames = $sqlInstances.Property
        }
        else {
            $instanceNames = $using:InstName
        }
        foreach ($instance in $instanceNames) {
            if ($instance -eq 'MSSQLSERVER') {
                $inst = ''
            }
            else {
                $inst = '\' + $instance
            }
            $instanceValue = $sqlInstances.GetValue($instance)
            $Cluster = Get-Item "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($instanceValue)\Cluster" -ErrorAction 'SilentlyContinue'
            if ($null -ne $Cluster) {
                $SQLServerName = $Cluster.GetValue('ClusterName') + $inst
                $isClustered = 1
            }
            else {
                $SQLServerName = $MachineName + $inst
                $isClustered = 0
            }
            $sqlSetup = Get-Item "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($instanceValue)\Setup" -ErrorAction 'SilentlyContinue'
            $sqlSetup | Select-Object @{Name = 'SQLServerName'; Expression = { $SQLServerName } },
                @{Name = 'InstanceName'; Expression = { $instance } },
                @{Name = 'MachineName'; Expression = { $MachineName } },
                @{Name = 'IsClustered'; Expression = { $isClustered } },
                @{Name = 'Cores'; Expression = { $numCores } },
                @{Name = 'ProductVersion'; Expression = { $sqlSetup.GetValue('PatchLevel') } },
                @{Name = 'ServerEdition'; Expression = { $sqlSetup.GetValue('Edition') } }
        }
    }
    $sqlProperties = @()
    $sqlProperties += foreach ($sqlSrvReg in $sqlServersReg) {
        $verMajor = $sqlSrvReg.ProductVersion.substring(0, 2)
        $verMinor = $sqlSrvReg.ProductVersion.substring(5, 4)
        <# dbo.SQLServerVersions table from sp_Blitz project #>
        $qrySrvTable = "/* Check SQL Server Version SP and CU */
            select top 1
                'Microsoft ' + v.MajorVersionName as ServerVersion
               ,iif(charindex(' ', v.Branch) > 0, left(v.Branch, charindex(' ', v.Branch) - 1), v.Branch) as ProductLevel
               ,stuff(v.Branch, 1, charindex(' ', v.Branch), '') as UpdateLevel
            from
                dbo.SQLServerVersions as v
            where
                v.MajorVersionNumber = $verMajor
                and v.MinorVersionNumber <= $verMinor
            order by
                v.MinorVersionNumber desc"
        $srvVerLevel = Invoke-SQL -ServerInstance $myAdminSQL -Database $myAdminDB -Query $qrySrvTable
        $sqlSrvReg | Select-Object -Property @{Name = 'Env'; Expression = { $Env } },
            SQLServerName, InstanceName, MachineName, Cores,
            @{Name = 'License'; Expression = { $License } },
            @{Name = 'ServerVersion'; Expression = { $srvVerLevel.ServerVersion } },
            @{Name = 'ProductLevel'; Expression = { $srvVerLevel.ProductLevel } },
            @{Name = 'UpdateLevel'; Expression = { $srvVerLevel.UpdateLevel } },
            KB, ProductVersion, ServerEdition, LocalAddress, LocalPort, IsClustered,
            @{Name = 'Description'; Expression = { $Desc } },
            @{Name = 'IsActiveNode'; Expression = { $Desc } }
    }
    Write-Output $sqlProperties
}

$srvProperties = @()
$srvInactive = @()
foreach ($server in $sqlServers) {
    try {
        <# invoke SQL query to the servers #>
        $srvProperty = Invoke-SQL -ServerInstance $server.SQLServer -Query $qrySrvInfo
        $srvProperties += $srvProperty | Select-Object -Property @{Name = 'Env'; Expression = { $server.Env } },
            SQLServerName, InstanceName, MachineName, Cores,
            @{Name = 'License'; Expression = { $server.License } },
            ServerVersion, ProductLevel, UpdateLevel, KB, ProductVersion, ServerEdition, LocalAddress, LocalPort, IsClustered,
            @{Name = 'Description'; Expression = { $server.Desc } }
    }
    catch {
        if ($RegCheck -eq 1) {
            try {
                <# get SQL information from registry on remote server #>
                $srvProperties += Get-SqlRegProperties -SrvName $server.SQLServer -Env $server.Env -License $server.License -Desc $server.Desc
            }
            catch {
                Write-Host "Server $($server.SQLServer) is not accessible" -ForegroundColor 'Magenta'
                $srvInactive += New-Object PSObject -Property @{SrvName = $server.SQLServer }
            }
        }
        else {
            Write-Host "Server $($server.SQLServer) is not accessible" -ForegroundColor 'Red'
            $srvInactive += New-Object PSObject -Property @{SrvName = $server.SQLServer }
        }
    }
}

if ($CheckOtherNodes -eq 1) {
    <# enumerate inactive cluster nodes #>
    $clusterNodes = $srvProperties | Where-Object { $_.IsClustered -eq 1 } | Select-Object MachineName, InstanceName, Env
    foreach ($instance in $clusterNodes) {
        <# get SQL information from registry on inactive cluster nodes #>
        $otherNode = Invoke-Command -ComputerName $instance.MachineName -Credential $credsadm -ScriptBlock {
            Get-ClusterNode | Where-Object { $_.NodeName -ne $using:instance.MachineName } | Select-Object NodeName
        } -ErrorAction 'SilentlyContinue'
        try {
            $srvProperties += Get-SqlRegProperties -SrvName $otherNode.NodeName -InstName $instance.InstanceName -Env $instance.Env
        }
        catch {
            Write-Host "Server $($otherNode.NodeName) is not accessible" -ForegroundColor 'Yellow'
        }
    }
}

if ($OutTerminal -ne 1) {
    $srvProperties | Export-Csv .\SQLSrvProperties.csv  # table with SQL Servers information
    $srvInactive | Export-Csv .\SQLInactive.csv         # list of servers script couldn't connect to
}
else {
    $srvProperties | Format-Table -AutoSize -Property Env, SQLServerName, InstanceName, MachineName,
        Cores, ServerVersion, ProductLevel, UpdateLevel, ProductVersion, ServerEdition, IsClustered
}
