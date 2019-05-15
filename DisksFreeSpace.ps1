<#
.Synopsis
Scripc checking free space on remote servers
.Example
.\DriveFreeSpace.ps1
#>

$prodServers = 'server1', 'server2'

$diskSize = @()
foreach ($server in $prodServers) {
    $diskSize += Invoke-Command -ComputerName $server -Credential $credsadm -ScriptBlock {
        [System.IO.DriveInfo]::GetDrives() |
        Where-Object { $_.VolumeLabel -notlike '*dtc' -and $_.VolumeLabel -notlike '*wtns' -and $_.DriveType -eq 'Fixed' } |
        Select-Object -Property Name, DriveFormat, IsReady, AvailableFreeSpace, TotalSize, VolumeLabel
    }
}

$diskSize | Format-Table -AutoSize -Property PSComputerName, Name, VolumeLabel, @{Name = "Total (GB)"; Expression = { "{0:N0}" -f ($_.TotalSize / 1GB) }; Align = "Right" }, @{Name = "Available (GB)"; Expression = { "{0:N0}" -f ($_.AvailableFreeSpace / 1GB) }; Align = "Right" }, @{Name = "Free %"; Expression = { "{0:N0}" -f ($_.AvailableFreeSpace / $_.TotalSize * 100) }; Align = "Right" }

foreach ($disk in $diskSize) {
    $pctFree = [math]::Round($disk.AvailableFreeSpace / $disk.TotalSize * 100, 1)
    if ($pctFree -lt 10) {
        Write-Host "ERROR  : $pctFree% free on $($disk.PSComputerName) disk $($disk.Name) ($($disk.VolumeLabel))" -ForegroundColor Red
    }
    elseif ($pctFree -ge 10 -and $pctFree -lt 20) {
        Write-Warning "$pctFree% free on $($disk.PSComputerName) disk $($disk.Name) ($($disk.VolumeLabel))"
    }
}
Write-Output ''