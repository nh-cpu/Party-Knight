param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$TemplateArchive = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$version = (& $Godot --version | Select-Object -First 1)
if ($version -notmatch '^4\.7\.2\.') { throw 'Use Godot 4.7.2 for matching client/server builds.' }
$templateDir = Join-Path $projectRoot '.cache/templates'
$requiredTemplates = @('windows_release_x86_64.exe', 'windows_release_x86_64_console.exe', 'linux_release.x86_64', 'version.txt')
if (!(Test-Path (Join-Path $templateDir 'linux_release.x86_64')) -or !(Test-Path (Join-Path $templateDir 'windows_release_x86_64.exe'))) {
    New-Item -ItemType Directory -Force -Path $templateDir | Out-Null
    if (!$TemplateArchive) { $TemplateArchive = Join-Path $projectRoot '.cache/godot-templates.tpz' }
    if (Test-Path $TemplateArchive) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $TemplateArchive))
        try {
            foreach ($name in $requiredTemplates) {
                $entry = $archive.GetEntry('templates/' + $name)
                if ($null -eq $entry) { throw "Archive is missing the standard export template $name" }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templateDir $name), $true)
            }
        } finally { $archive.Dispose() }
    } else {
        $installed = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
        foreach ($name in $requiredTemplates) {
            if (!(Test-Path (Join-Path $installed $name))) { throw 'Install standard Godot 4.7.2 export templates, or pass -TemplateArchive with the official non-mono .tpz archive.' }
            Copy-Item -LiteralPath (Join-Path $installed $name) -Destination (Join-Path $templateDir $name)
        }
    }
}
if ((Get-Content (Join-Path $templateDir 'version.txt') -Raw).Trim() -ne '4.7.2.stable') { throw 'The export templates must be version 4.7.2.stable.' }
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'builds/windows'), (Join-Path $projectRoot 'builds/linux') | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'builds/.gdignore') -Value ''
Set-Content -LiteralPath (Join-Path $projectRoot '.cache/.gdignore') -Value ''
& $Godot --headless --path $projectRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $Godot --headless --path $projectRoot --export-release 'Windows Desktop'
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed. Install matching 4.7.2 export templates.' }
& $Godot --headless --path $projectRoot --export-release 'Linux Dedicated Server'
if ($LASTEXITCODE -ne 0) { throw 'Linux export failed. Install matching 4.7.2 export templates.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'Free Medieval 3D People Low Poly Pack/License.txt') -Destination (Join-Path $projectRoot 'builds/windows/Character-Asset-License.txt')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PLAY.txt') -Destination (Join-Path $projectRoot 'builds/windows/PLAY.txt')
Write-Output 'Windows client and Linux server exports complete.'
