<#
.Description
Adapted from https://gist.github.com/altrive/5329377
Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
.Example
Admin\RestartPending.ps1
Invoke-Command -ComputerName 'CompName' -Credential $credsadm -FilePath .\RestartPending.ps1
#>
function Test-PendingReboot
{
    if (Get-ChildItem 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction SilentlyContinue) {return $true}
    if (Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction SilentlyContinue) { return $true}
    if (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) { return $true}
    try {
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if(($null -ne $status) -and $status.RebootPending){
            return $true
        }
    } catch {}
    return $false
}

Test-PendingReboot
