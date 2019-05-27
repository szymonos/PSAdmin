<#
.Synopsis
.Description
.Example
.\VMsEnumerate.ps1 -SrvPrefix 'ServersA' -OutDir '.'
#>

param(
    [string]$SrvPrefix,
    [string]$OutDir = '.'
)

while ($SrvPrefix -eq '') {
    Write-Host "Missing servers name prefix to search for.`nPlease provide prefix w/o wildcards." -ForegroundColor Cyan
    $SrvPrefix = Read-Host
}

$outputCSV = Join-Path -Path $OutDir -ChildPath "Comps$SrvPrefix.csv"
$nonTrustedDomains = 'otherdomain.com'
$credsadm = try {
    Import-CliXml -Path "$($env:USERPROFILE)\adm.cred"
} catch {
    Get-Credential
}

$ErrorActionPreference = 'SilentlyContinue'
function Get-FQND {
    param (
        [string]$CompName,
        [array]$Domains = $nonTrustedDomains
    )
    try {
        $ipAddress = Resolve-DnsName $compName | Select-Object -ExpandProperty IPAddress
        $dName = Resolve-DnsName $ipAddress | Where-Object {$_.NameHost -notlike 'vtemp*'} | Select-Object -First 1 -ExpandProperty NameHost
        $fqdn = New-Object PSObject -Property @{DomainName = $dName; IsValidated = $true}
    } catch {
        foreach ($domain in $Domains) {
            $dName = $compName, $domain -join '.'
            if(Test-Connection $dName -Quiet) {
                $fqdn = New-Object PSObject -Property @{DomainName = $dName; IsValidated = $true}
            } else {
                $fqdn = New-Object PSObject -Property @{DomainName = $compName; IsValidated = $false}
            }
        }
    }
    Write-Output $fqdn
}

$vmHostsFilter = "$SrvPrefix*"
# Get cluster nodes
$vmHosts = Get-ADComputer -Filter {Name -like $vmHostsFilter}
$VMs = @()
foreach ($vmHost in $vmHosts.Name) {
    $VMs += Invoke-Command -ComputerName $vmHost -Credential $credsadm –ScriptBlock {Get-VM | Select-Object -Property ComputerName, Name, State, IsClustered, CreationTime}
}

$vmDomain =@()
foreach ($vm in $VMs) {
    $domainName = Get-FQND -CompName $vm.Name -Domains $nonTrustedDomains
    if($domainName.IsValidated) {
        $compRole = Invoke-Command -ComputerName $vm.Name -Credential $credsadm -ScriptBlock {
            $envComp = $env:ABCDATA_ENVIRONMENT_NAME
            $isSQL = if (Get-Item 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction SilentlyContinue) {
                Write-Output $true
            } else {
                Write-Output $false
            }
            $isOLAP = if (Get-Item 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\OLAP' -ErrorAction SilentlyContinue) {
                Write-Output $true
            } else {
                Write-Output $false
            }
            $isIIS = if (Get-Item 'HKLM:\SOFTWARE\Microsoft\InetStp' -ErrorAction SilentlyContinue) {
                Write-Output $true
            } else {
                Write-Output $false
            }
            $a = New-Object PSObject -Property @{Environment = $envComp; IsSQL = $isSQL; IsOLAP = $isOLAP; IsIIS = $isIIS}
            Write-Output $a
        }
    } else {
        $compRole = New-Object PSObject -Property @{Environment = $null; IsSQL = $null; IsOLAP = $null; IsIIS = $null}
    }
    $vmDomain += $vm | Select-Object -Property ComputerName, Name,
        @{Name = 'DomainName'; Expression = {$domainName.DomainName}},
        @{Name = 'IsValidated'; Expression = {$domainName.IsValidated}},
        @{Name = 'Env'; Expression = {$compRole.Environment}},
        @{Name = 'IsSQL'; Expression = {$compRole.IsSQL}},
        @{Name = 'IsOLAP'; Expression = {$compRole.IsOLAP}},
        @{Name = 'IsIIS'; Expression = {$compRole.IsIIS}},
        State, IsClustered, CreationTime
}
$vmDomain | Select-Object -Property * | Export-Csv $outputCSV -NoTypeInformation
Write-Host "`nResults have been saved to file:" -ForegroundColor Yellow
Write-Output (Resolve-Path $outputCSV).Path''
