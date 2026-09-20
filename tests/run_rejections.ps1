param([Parameter(Mandatory = $true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$reportDir = Join-Path $projectRoot '.godot/rejections'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$started = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
function Start-CheckProcess([string]$Label, [string[]]$Extra) {
    $log = Join-Path $reportDir "$Label.log"
    Set-Content -LiteralPath $log -Value ''
    $arguments = @('--headless', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $log + '"'), '--') + $Extra
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -WindowStyle Hidden
    $started.Add($process)
    return $process
}
function Wait-Marker([string]$Label, [string]$Marker, [int]$Seconds = 15) {
    $log = Join-Path $reportDir "$Label.log"
    $deadline = (Get-Date).AddSeconds($Seconds)
    while (!(Select-String -LiteralPath $log -Pattern $Marker -Quiet)) {
        if ((Get-Date) -gt $deadline) { throw "Missing marker $Marker in $log" }
        Start-Sleep -Milliseconds 100
    }
}
function Stop-Checks {
    foreach ($process in $started) {
        if (!$process.HasExited) { Stop-Process -Id $process.Id }
    }
    $started.Clear()
}
try {
    $null = Start-CheckProcess 'version-server' @('--server', '--port', '7190')
    Wait-Marker 'version-server' 'SERVER_READY'
    $null = Start-CheckProcess 'version-client' @('--test-client', '--port', '7190', '--wrong-version', '--expect-reject', '--reject-text', 'Version')
    Wait-Marker 'version-client' 'EXPECTED_REJECTION.*Version'
    Stop-Checks

    $null = Start-CheckProcess 'full-server' @('--server', '--port', '7191')
    Wait-Marker 'full-server' 'SERVER_READY'
    for ($index = 0; $index -lt 4; $index++) {
        $null = Start-CheckProcess "holder-$index" @('--test-client', '--port', '7191', '--hold-lobby', '--name', "Holder$index")
    }
    Wait-Marker 'full-server' 'players=4'
    $null = Start-CheckProcess 'full-client' @('--test-client', '--port', '7191', '--expect-reject', '--reject-text', 'full')
    Wait-Marker 'full-client' 'EXPECTED_REJECTION.*full'
    Stop-Checks

    $null = Start-CheckProcess 'load-server' @('--server', '--port', '7192', '--test-fast')
    Wait-Marker 'load-server' 'SERVER_READY'
    $null = Start-CheckProcess 'good-client' @('--test-client', '--port', '7192', '--players', '2', '--name', 'Good')
    $null = Start-CheckProcess 'load-client' @('--test-client', '--port', '7192', '--players', '2', '--withhold-load', '--expect-reject', '--reject-text', 'loading')
    Wait-Marker 'load-server' 'phase=INSTRUCTIONS'
    $null = Start-CheckProcess 'late-client' @('--test-client', '--port', '7192', '--expect-reject', '--reject-text', 'progress')
    Wait-Marker 'late-client' 'EXPECTED_REJECTION.*progress'
    Wait-Marker 'load-client' 'EXPECTED_REJECTION.*loading' 30
    Wait-Marker 'load-server' 'phase=LOBBY.*players=1'
    Stop-Checks

    $null = Start-CheckProcess 'rotation-server' @('--server', '--port', '7193', '--test-fast')
    Wait-Marker 'rotation-server' 'SERVER_READY'
    $null = Start-CheckProcess 'rotation-good-a' @('--test-client', '--port', '7193', '--players', '3', '--name', 'GoodA')
    $null = Start-CheckProcess 'rotation-timeout' @('--test-client', '--port', '7193', '--players', '3', '--withhold-load', '--expect-reject', '--reject-text', 'loading')
    $null = Start-CheckProcess 'rotation-good-b' @('--test-client', '--port', '7193', '--players', '3', '--name', 'GoodB')
    Wait-Marker 'rotation-timeout' 'EXPECTED_REJECTION.*loading' 35
    Wait-Marker 'rotation-server' 'ROTATION_RESTART players=2'
    Wait-Marker 'rotation-server' 'phase=PLAYING.*players=2'
    Stop-Checks

    $restartServer = Start-CheckProcess 'restart-server' @('--server', '--port', '7194')
    Wait-Marker 'restart-server' 'SERVER_READY'
    $null = Start-CheckProcess 'restart-client' @('--test-client', '--port', '7194', '--hold-lobby', '--expect-reject', '--reject-text', 'disconnected')
    Wait-Marker 'restart-server' 'players=1'
    Stop-Process -Id $restartServer.Id
    Wait-Marker 'restart-client' 'EXPECTED_REJECTION.*disconnected' 45
    Stop-Checks
    $null = Start-CheckProcess 'fresh-server' @('--server', '--port', '7194')
    Wait-Marker 'fresh-server' 'SERVER_READY'
    $null = Start-CheckProcess 'fresh-client' @('--test-client', '--port', '7194', '--hold-lobby')
    Wait-Marker 'fresh-server' 'players=1'
    Stop-Checks
    foreach ($log in Get-ChildItem $reportDir -Filter '*.log') {
        if (Select-String -LiteralPath $log.FullName -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) { throw "Errors in $($log.FullName)" }
    }
    Write-Output 'REJECTIONS_PASS version=true full=true late_join=true loading_timeout=true rotation_recovery=true restart=true'
} finally { Stop-Checks }
