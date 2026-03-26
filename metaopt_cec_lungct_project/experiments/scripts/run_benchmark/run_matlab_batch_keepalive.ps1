param(
    [Parameter(Mandatory = $true)]
    [string]$BatchCommand,

    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = "",

    [Parameter(Mandatory = $false)]
    [int]$HeartbeatSeconds = 15
)

$ErrorActionPreference = 'Stop'

if ($HeartbeatSeconds -lt 5) {
    throw "HeartbeatSeconds must be >= 5"
}

if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $WorkingDirectory = (Get-Location).Path
}

if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
    throw "WorkingDirectory does not exist: $WorkingDirectory"
}

Push-Location $WorkingDirectory
try {
    $start = Get-Date
    Write-Output ("[runner] start=" + $start.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Output ("[runner] cwd=" + $WorkingDirectory)

    $proc = Start-Process -FilePath "matlab" -ArgumentList @('-batch', $BatchCommand) -PassThru
    Write-Output ("[runner] matlab_pid=" + $proc.Id)

    while (-not $proc.HasExited) {
        $elapsed = [int]((Get-Date) - $start).TotalSeconds
        Write-Output ("[keepalive] elapsed=" + $elapsed + "s")
        Start-Sleep -Seconds $HeartbeatSeconds
        $proc.Refresh()
    }

    $end = Get-Date
    $total = [int]($end - $start).TotalSeconds
    Write-Output ("[runner] end=" + $end.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Output ("[runner] total_seconds=" + $total)
    Write-Output ("[runner] exit_code=" + $proc.ExitCode)

    if ($proc.ExitCode -ne 0) {
        throw "MATLAB exited with code $($proc.ExitCode)"
    }
}
finally {
    Pop-Location
}
