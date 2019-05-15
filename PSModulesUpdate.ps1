<#
.Description
Script checking all modules and install newer version and uninstall current version.
.Example
AdminMy\PSModulesUpdate.ps1 -UpdateModules 0    # check if there are outdated powershell modules
AdminMy\PSModulesUpdate.ps1 -UpdateModules 1    # update all modules (uninstalling outdated versions)
AdminMy\PSModulesUpdate.ps1 -UpdateModules 0 -ModuleName dbatools
AdminMy\PSModulesUpdate.ps1 -UpdateModules 1 -ModuleName dbatools
#>
param (
    [int]$UpdateModules = 0,
    [string]$ModuleName
)
Clear-Host

function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ($UpdateModules -eq 1) {
    if (Test-Administrator) {
        Write-Output 'This will remove old versions of installed modules and install the newest one'

        $mods = if ($ModuleName -eq '') { Get-InstalledModule } else { Get-InstalledModule $ModuleName }
        foreach ($mod in $mods) {
            Write-Host "Checking $($mod.Name)" -ForegroundColor Yellow
            $online = Find-Module -Name $mod.Name
            $specificMods = Get-InstalledModule $mod.Name -AllVersions
            $modsCnt = if ($null -eq $specificMods.count) { 1 } else { $specificMods.count }
            if ($mod.Version -eq $online.Version) { $modsCnt = $modsCnt - 1 }
            if ($modsCnt -gt 0) {
                Write-Output "$($modsCnt) outdated version(s) of this module found"
                foreach ($sm in $specificmods) {
                    if ($sm.Version -ne $online.Version) {
                        Write-Host " Uninstalling $($sm.Name) v$($sm.Version) [latest is $($online.Version)]" -ForegroundColor Magenta
                        $sm | Uninstall-Module -Force
                        Write-Host " Done uninstalling $($sm.Name) v$($sm.Version)" -ForegroundColor Green
                        Write-Output ' --------'
                    }
                }
            }
            if ($mod.Version -eq $online.Version) {
                Write-Host " Latest version $($mod.Name) v$($online.Version) installed" -ForegroundColor Green
            }
            else {
                Write-Host " Installing $($mod.Name) v$($online.Version)" -ForegroundColor Magenta
                Install-Module $online
                Write-Host ' Done installing newest version' -ForegroundColor Green
            }
            Write-Output ' ------------------------'
        }
        Write-Output 'Done'
    }
    else {
        Write-Host "Run the script with administrator privilages!`n" -ForegroundColor Yellow
    }
}
else {
    Write-Output "This will report outdated versions of installed modules.`n"

    $mods = if ($ModuleName -eq '') { Get-InstalledModule } else { Get-InstalledModule $ModuleName }
    foreach ($mod in $mods) {
        Write-Host "Checking $($mod.Name)" -ForegroundColor Yellow
        $online = Find-Module -Name $mod.Name
        $specificMods = Get-InstalledModule $mod.Name -AllVersions
        $modsCnt = if ($null -eq $specificMods.count) { 1 } else { $specificMods.count }
        if ($mod.Version -eq $online.Version) {
            Write-Host " Latest version $($mod.Name) v$($online.Version) installed" -ForegroundColor Green
            $modsCnt = $modsCnt - 1
        }
        if ($modsCnt -gt 0) {
            Write-Output " $($modsCnt) outdated version(s) of this module found"
            foreach ($sm in $specificMods) {
                if ($sm.Version -ne $online.Version) {
                    Write-Host " $($sm.Name) v$($sm.Version) [latest is $($online.Version)]" -ForegroundColor Magenta
                }
            }
            Write-Output ' ------------------------'
        }
    }
}
