<#
.Description
Get Physical Host Name from guest PC (virtualPC or Hyper-V)
.Example
Invoke-Command -ComputerName CompName -Credential $credsadm -FilePath .\PhysicalHostName.ps1
#>
$vmParam = Get-Item 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -ErrorAction 'SilentlyContinue'
Clear-Host
if ($null -eq $vmParam) {
    Write-Host 'Not a Virtual Machine' -ForegroundColor Magenta
}
else {
    $vmName = $vmParam.GetValue('VirtualMachineName')
    $vmHostName = $vmParam.GetValue('HostName')
    Write-Host 'Virtual Machine Name : ' -NoNewline; Write-Host $vmName -ForegroundColor Cyan
    Write-Host 'Physical Host Name   : ' -NoNewline; Write-Host $vmHostName -ForegroundColor Cyan
    Write-Output ''
}
