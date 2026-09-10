[CmdletBinding()]
param(
    [string]$Version = '',
    [switch]$IncludeTemplates,
    [string]$DownloadDirectory = ''
)
# Windows x64, PowerShell 5.1+, curl.exe. No administrator or global install.
# Cached and fresh archives must match the committed official checksum lock.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pinnedVersion = (Get-Content -LiteralPath (Join-Path $projectRoot '.godot-version') -Raw).Trim()
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'godot.lock.json') -Raw | ConvertFrom-Json
if (-not $Version) { $Version = $pinnedVersion }
if ($Version -ne $pinnedVersion -or $Version -ne $lock.version) {
    throw 'Engine version differs from .godot-version / tools/godot.lock.json. Review the official release and update both pins before changing engines.'
}
if (-not [Environment]::Is64BitOperatingSystem -or [Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'This installer targets Windows x64.' }
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { throw 'curl.exe is required (included with current Windows 10/11).' }
if (-not $DownloadDirectory) { $DownloadDirectory = Join-Path $projectRoot '.preproduction-local/downloads' }
$downloadRoot = [IO.Path]::GetFullPath($DownloadDirectory)
$engineRoot = Join-Path $projectRoot '.tools/godot'
$templatesRoot = Join-Path $projectRoot '.tools/export_templates'
$templateVersionRoot = Join-Path $templatesRoot "$Version.stable"
New-Item -ItemType Directory -Force -Path $downloadRoot, $engineRoot, $templateVersionRoot | Out-Null

function Assert-Archive([string]$Path, $Spec) {
    if ((Get-Item -LiteralPath $Path).Length -ne [long]$Spec.bytes) { throw "Archive size mismatch: $Path. Delete this archive and retry; it has not been extracted." }
    foreach ($algorithm in @('SHA256', 'SHA512')) {
        $expected = [string]$Spec.($algorithm.ToLowerInvariant())
        $actual = (Get-FileHash -LiteralPath $Path -Algorithm $algorithm).Hash.ToLowerInvariant()
        if ($actual -ne $expected) { throw "$algorithm mismatch: $Path. Delete this archive and retry; it has not been extracted." }
    }
}
function Receive-Archive($Spec) {
    $destination = Join-Path $downloadRoot $Spec.name
    if (Test-Path -LiteralPath $destination) {
        Assert-Archive $destination $Spec
        Write-Host "Verified cached archive: $($Spec.name)"
        return $destination
    }
    $partial = "$destination.part"
    Write-Host "Downloading official release: $($Spec.url)"
    & curl.exe --fail --location --retry 3 --connect-timeout 20 --max-time 1800 --speed-time 60 --speed-limit 1024 --continue-at - --output $partial $Spec.url
    if ($LASTEXITCODE -ne 0) { throw "Download failed (curl $LASTEXITCODE). Partial download retained: $partial" }
    Assert-Archive $partial $Spec
    Move-Item -LiteralPath $partial -Destination $destination
    return $destination
}
function Expand-Selected([string]$Archive, [string]$Destination, [string[]]$Names) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $resolvedRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $candidate = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $entry.FullName))
            if (-not $candidate.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe archive entry: $($entry.FullName)" }
        }
        foreach ($name in $Names) {
            $matches = @($zip.Entries | Where-Object { $_.Name -eq $name })
            if ($matches.Count -ne 1) { throw "Expected exactly one archive member: $name" }
            $target = Join-Path $resolvedRoot $name
            # Re-check installed bytes against the authenticated archive, too.
            $memberStream = $matches[0].Open()
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $memberHash = [BitConverter]::ToString($hasher.ComputeHash($memberStream)).Replace('-', '') }
            finally { $memberStream.Dispose(); $hasher.Dispose() }
            if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $memberHash) { continue }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($matches[0], $target, $true)
        }
    } finally { $zip.Dispose() }
}
$release = "$Version-stable"
$engineName = "Godot_v$($release)_win64.exe"
$consoleName = "Godot_v$($release)_win64_console.exe"
$engineArchive = Receive-Archive $lock.archives.engine
Expand-Selected $engineArchive $engineRoot @($engineName, $consoleName)
[IO.File]::WriteAllText((Join-Path $engineRoot '_sc_'), '')
$enginePath = Join-Path $engineRoot $consoleName
$actualVersion = ((& $enginePath --headless --version) | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $actualVersion.StartsWith("$Version.stable.official.")) { throw "Downloaded engine version mismatch: $actualVersion" }
$log = [ordered]@{
    prepared_at_utc = [DateTime]::UtcNow.ToString('o')
    version = $actualVersion
    executable_path = $enginePath
    gui_executable_path = (Join-Path $engineRoot $engineName)
    engine_source = $lock.archives.engine.url
    engine_archive_sha256 = $lock.archives.engine.sha256
    engine_archive_sha512 = $lock.archives.engine.sha512
    engine_executable_sha256 = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant()
    engine_gui_sha256 = (Get-FileHash -LiteralPath (Join-Path $engineRoot $engineName) -Algorithm SHA256).Hash.ToLowerInvariant()
    templates_root = $templatesRoot
    templates_verified_this_run = $false
    lock_sha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'godot.lock.json') -Algorithm SHA256).Hash.ToLowerInvariant()
}
if ($IncludeTemplates) {
    $templateArchive = Receive-Archive $lock.archives.templates
    Expand-Selected $templateArchive $templateVersionRoot @('windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'web_release.zip', 'web_debug.zip', 'web_nothreads_release.zip', 'web_nothreads_debug.zip', 'version.txt')
    $templateVersion = (Get-Content -LiteralPath (Join-Path $templateVersionRoot 'version.txt') -Raw).Trim()
    if ($templateVersion -ne "$Version.stable") { throw "Template version mismatch: $templateVersion" }
    $log.templates_verified_this_run = $true
    $log.templates_source = $lock.archives.templates.url
    $log.templates_archive_sha256 = $lock.archives.templates.sha256
    $log.templates_archive_sha512 = $lock.archives.templates.sha512
    Write-Host "Templates ready: $templateVersionRoot"
}
$logDirectory = Join-Path $projectRoot '.preproduction-local'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$log | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $logDirectory 'godot-install.json') -Encoding utf8
Write-Host "Godot ready: $actualVersion ($enginePath)"
