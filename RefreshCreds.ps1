<#
.Synopsis
Script refreshing AD groups membership
.Description
Script stops explorer.exe process and then starts it again with account credentials to refresh AD groups membership
.Example
.\RefreshCreds.ps1
#>

$creds = Import-CliXml -Path "$($env:USERPROFILE)\my.cred"
taskkill.exe /F /IM explorer.exe
Start-Process explorer.exe -Credential $creds
