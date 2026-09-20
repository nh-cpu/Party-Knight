param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [ValidateRange(1, 4)][int]$Players = 2,
    [int]$Port = 7100,
    [int]$LatencyMs = 0,
    [int]$LossPercent = 0,
    [string]$Games = 'ballista,lance,coins',
    [switch]$RandomOrder,
    [switch]$Presentation,
    [ValidateRange(1, 2)][int]$Matches = 1
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$reportSuffix = if ($LatencyMs -gt 0) { '-impaired' } else { '' }
if ($Presentation) { $reportSuffix += '-presentation' }
if ($Matches -gt 1) { $reportSuffix += '-rematch' }
$reportDir = Join-Path $projectRoot ".godot/network-$Players$reportSuffix"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$started = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$expectedRounds = 0
foreach ($game in $Games.Split(',')) {
    if ($game -eq 'ballista') { $expectedRounds += $Players } else { $expectedRounds += 3 }
}
try {
    $serverLog = Join-Path $reportDir 'server.log'
    if (Test-Path $serverLog) { Set-Content -LiteralPath $serverLog -Value '' }
    $serverArgs = @('--headless', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $serverLog + '"'), '--', '--server', '--port', $Port, '--test-fast')
    $server = Start-Process -FilePath $Godot -ArgumentList $serverArgs -PassThru -WindowStyle Hidden
    $started.Add($server)
    $readyDeadline = (Get-Date).AddSeconds(20)
    while (!(Test-Path $serverLog) -or !(Select-String -LiteralPath $serverLog -Pattern 'SERVER_READY' -Quiet)) {
        if ($server.HasExited -or (Get-Date) -gt $readyDeadline) { throw 'Server failed to start.' }
        Start-Sleep -Milliseconds 200
    }
    $clients = @()
    for ($index = 0; $index -lt $Players; $index++) {
        $clientPort = $Port
        if ($LatencyMs -gt 0 -or $LossPercent -gt 0) {
            $clientPort = $Port + 100 + $index
            $proxyScript = Join-Path $PSScriptRoot 'udp_proxy.cjs'
            $proxy = Start-Process -FilePath 'node' -ArgumentList @(('"' + $proxyScript + '"'), '--listen', $clientPort, '--target', $Port, '--delay', $LatencyMs, '--loss', $LossPercent) -WindowStyle Hidden -PassThru
            $started.Add($proxy)
        }
        $clientLog = Join-Path $reportDir "client-$index.log"
        $clientArgs = @('--headless', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $clientLog + '"'), '--', '--test-client', '--port', $clientPort, '--players', $Players, '--name', "Tester$index", '--character', $index)
        $clientArgs += @('--games', $Games)
        $clientArgs += @('--matches', $Matches)
        if ($Presentation) { $clientArgs = $clientArgs | ForEach-Object { if ($_ -eq '--test-client') { '--presentation-client' } else { $_ } } }
        if ($RandomOrder) { $clientArgs += '--random-order' }
        $client = Start-Process -FilePath $Godot -ArgumentList $clientArgs -PassThru -WindowStyle Hidden
        $clients += $client
        $started.Add($client)
    }
    $deadline = (Get-Date).AddSeconds(720 * $Matches)
    while (@($clients | Where-Object { !$_.HasExited }).Count -gt 0) {
        if ((Get-Date) -gt $deadline) { throw 'Network match timed out.' }
        Start-Sleep -Milliseconds 500
    }
    $reference = $null
    for ($index = 0; $index -lt $Players; $index++) {
        $clientLog = Join-Path $reportDir "client-$index.log"
        $content = Get-Content -LiteralPath $clientLog -Raw
        if ($content -notmatch "CLIENT_MATCH_COMPLETE rounds=$expectedRounds " -or $content -match '(SCRIPT ERROR|ERROR:)') {
            throw "Client $index failed. Inspect $clientLog"
        }
        if ($Presentation -and $content -notmatch 'PRESENTATION_PASS') { throw "Client $index did not verify presentation prediction." }
        if ([regex]::Matches($content, 'CLIENT_MATCH_COMPLETE').Count -ne $Matches) { throw "Client $index did not complete $Matches matches." }
        if ($Matches -gt 1 -and $content -notmatch 'CLIENT_REMATCH_RESET') { throw "Client $index did not verify rematch reset." }
        $rounds = @((Get-Content -LiteralPath $clientLog) | Where-Object { $_ -like 'CLIENT_ROUND*' -or $_ -like 'CLIENT_MATCH_COMPLETE*' })
        $serialized = $rounds -join "`n"
        if ($null -ne $reference -and $serialized -ne $reference) { throw 'Clients disagreed on round results or game order.' }
        $reference = $serialized
    }
    $serverContent = Get-Content -LiteralPath $serverLog -Raw
    if ($serverContent -match '(SCRIPT ERROR|ERROR:)') { throw "Server errors. Inspect $serverLog" }
    Write-Output "NETWORK_PASS players=$Players rounds=$expectedRounds matches=$Matches identical_results=true reports=$reportDir"
} finally {
    foreach ($process in $started) {
        if (!$process.HasExited) { Stop-Process -Id $process.Id }
    }
}
