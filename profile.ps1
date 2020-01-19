function Prompt {
    filter repl1 { $_ -replace '\\', '\\' }
    filter repl2 { $_ -replace ($env:USERPROFILE | repl1), '~' }
    filter repl3 { $_ -replace '[c-z]:\\Users\\\w+', '~' }
    filter repl4 { $_ -replace 'Microsoft.PowerShell.Core\\FileSystem::', '' }
    if ((Get-History).Count -gt 0) {
        $executionTime = ((Get-History)[-1].EndExecutionTime - (Get-History)[-1].StartExecutionTime).Totalmilliseconds
        $time = [math]::Round($executionTime, 2)
    }
    else {
        $time = 0
    }
    Write-Host ('[') -NoNewline -ForegroundColor White
    Write-Host ($time, 'ms' -join ('')) -NoNewline -ForegroundColor Green
    Write-Host ('] ') -NoNewline -ForegroundColor White
    $promptPath = $PWD | repl2 | repl3 | repl4
    Write-Host $promptPath -NoNewline -ForegroundColor Cyan
    if ($branch = git branch --show-current 2>$null) {
        $symbolBranch = [char]0x2442    # ⑂
        $symbolPush = [char]0x2191      # ↑
        $symbolPull = [char]0x2193      # ↓
        $symbolPublish = [char]0x21EA   # ⇪

        if ($behind = git rev-list 'HEAD..@{u}' --count 2>$null) {
            $ahead = git rev-list '@{u}..HEAD' --count
        }
        Write-Host (' [') -NoNewline -ForegroundColor Magenta
        Write-Host ($symbolBranch) -NoNewline -ForegroundColor White
        if ($null -eq $behind) {
            Write-Host ($branch) -NoNewline -ForegroundColor Blue
            Write-Host (" $symbolPublish") -NoNewline -ForegroundColor Green
        }
        else {
            Write-Host ('origin/' + $branch) -NoNewline -ForegroundColor Blue
            if ($ahead -gt 0) {
                Write-Host (" $symbolPush") -NoNewline -ForegroundColor White
                Write-Host ($ahead) -NoNewline -ForegroundColor Green
            }
            if ($behind -gt 0) {
                Write-Host (" $symbolPull") -NoNewline -ForegroundColor Yellow
                Write-Host ($behind) -NoNewline -foregroundcolor Yellow
            }
        }
        Write-Host (']') -NoNewline -ForegroundColor Magenta
    }
    Write-Host "`nPS" -NoNewline -ForegroundColor Green
    return ('>' * ($nestedPromptLevel + 1)) + ' '
}
function Get-Uptime {
    $LastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $Uptime = (Get-Date) - $LastBoot
    'BootUp: ' + $LastBoot.ToString() + ' | Uptime: ' + $Uptime.Days + ' days, ' + $Uptime.Hours + ' hours, ' + $Uptime.Minutes + ' minutes'
}
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8bom'
[void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
Clear-Host
Write-Output ('PowerShell ' + $PSVersionTable.PSVersion.ToString())
Get-Uptime
