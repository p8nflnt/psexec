<#
.SYNOPSIS
    Execute scriptblock within the current user context for a given host.

.NOTES
    Name: Invoke-PsExec
    Author: Payton Flint
    Version: 1.0
    DateCreated: 2024-Aug

.LINK
    https://github.com/p8nflnt/psexec/blob/main/Invoke-PsExec.ps1
#>

# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0

function Get-UserSessions {
    param (
        [string]$computerName
    )

    # invoke psexec to query user sessions on param-specified host
    # using .NET rather than Start-Process to return output w/ variable
    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = "psexec"
    $procInfo.RedirectStandardOutput = $true
    $procInfo.UseShellExecute = $false
    $procInfo.Arguments = "\\$computerName -nobanner -s -h query user"
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo
    $proc.Start() | Out-Null
    $proc.WaitForExit()
    $stdOut = $proc.StandardOutput.ReadToEnd()

    # split output by newline
    $lines = $stdOut -split "`r?`n"
    # trim first and last lines if result is returned
    if ($lines.Length -ge 3) {

        $lines = $lines[1..($lines.Length - 2)]

        # initialize sessions array
        $sessions = @()
        
        # for each line from returned result...
        $lines | ForEach-Object {

            # use regex to parse each line
            $_ -match '^(?:\s)(\S+)(?:\s+)(.+)(?:\s+)(\d+)(?:\s\s)(\S+)(?:\s+)(.+)(?:\s\s)(.+)$' | Out-Null

            # build custom objects with appropriate property/value pairs
            $obj = [PSCustomObject]@{
                Username    = $matches[1]
                SessionName = $matches[2]
                Id          = $matches[3]
                State       = $matches[4]
                IdleTime    = $matches[5]
                LogonTime   = $matches[6]
            }
            # add custom object to sessions array
            $sessions += $obj
        }
    } else {
        Write-Host -ForegroundColor Red "No user sessions found for $computerName"
    }
    # return session info
    return $sessions
}

function Invoke-PsExec {
    param (
        [string]$computerName,
        [int]$sessionId,
        [scriptBlock]$scriptBlock,
        [bool]$runAsSystem
    )
    
    # build arguments using system parameter
    if ($runAsSystem -eq $true) { 
        $psexecArgs = "\\$computerName -s -i $sessionId -nobanner powershell -nop -ep bypass -c `"$scriptBlock`""
    } else {
        $psexecArgs = "\\$computerName -i $sessionId -nobanner powershell -nop -ep bypass -c `"$scriptBlock`""
    }

    # invoke psexec to execute scriptblock on param-specified session
    # using .NET rather than Start-Process to return output w/ variable
    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = "psexec"
    $procInfo.RedirectStandardOutput = $true
    $procInfo.UseShellExecute = $false
    $procInfo.Arguments = $psexecArgs
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo
    $proc.Start() | Out-Null
    $proc.WaitForExit()
    $stdOut = $proc.StandardOutput.ReadToEnd()

    return $stdOut
}

$computerName = "<COMPUTER NAME>"

$sessions = Get-UserSessions -computerName $computerName
$sessions

$scriptBlock = {

    $textCommand = {
        
        whoami
    
        Write-Host "`r`nHello, World!`r`n"
    
    }

    powershell -noexit -c "$textCommand"

}

Invoke-PsExec -computerName $computerName -sessionId $($sessions[0].Id) -scriptBlock $scriptBlock -runAsSystem $true
