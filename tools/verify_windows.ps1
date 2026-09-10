param([int]$TimeoutSeconds = 30)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releaseMatch = Select-String -LiteralPath (Join-Path $projectRoot 'project.godot') -Pattern '^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
if (-not $releaseMatch) { throw 'Expected a semantic project version.' }
$releaseVersion = $releaseMatch.Matches[0].Groups[1].Value
$releaseLabel = 'v' + $releaseVersion.Replace('.', '')
$artifactRoot = Join-Path $projectRoot 'artifacts'
$package = Get-Content -LiteralPath (Join-Path $artifactRoot "windows-v$releaseVersion-package.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$extractedRoot = [IO.Path]::GetFullPath($package.extracted)
if (-not $extractedRoot.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Verified ZIP directory must be inside project artifacts.'
}
$captureRoot = Join-Path $projectRoot "captures/$releaseLabel"
New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
$results = @()
foreach ($kind in @('export', 'zip')) {
    $directory = if ($kind -eq 'export') { Join-Path $projectRoot "exports/windows-v$releaseVersion" } else { $extractedRoot }
    $exe = Join-Path $directory 'Scrapstorm.exe'
    if ((Get-Item -LiteralPath $exe).VersionInfo.FileVersion -ne "$releaseVersion.0") { throw "EXE version differs from project: $kind" }
    if ((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne $package.files.'Scrapstorm.exe') { throw "EXE hash differs: $kind" }
    if ((Get-FileHash -LiteralPath (Join-Path $directory 'Scrapstorm.pck') -Algorithm SHA256).Hash -ne $package.files.'Scrapstorm.pck') { throw "PCK hash differs: $kind" }
    $picture = Join-Path $captureRoot "windows-$kind-final.png"
    $outputLog = Join-Path $artifactRoot "$releaseLabel-windows-$kind-native.log"
    $errorLog = Join-Path $artifactRoot "$releaseLabel-windows-$kind-native-stderr.log"
    $arguments = @('--position', '-1800,-1200', '--resolution', '1280x720', '--', '--test-settings', ('"--capture=' + $picture.Replace('\', '/') + '"'), '--capture-delay=4')
    if ($kind -eq 'zip') { $arguments += '--smoke-start' }
    # No --path: each EXE must load its own distributed PCK and isolated preferences.
    $child = Start-Process -FilePath $exe -WorkingDirectory $directory -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $outputLog -RedirectStandardError $errorLog
    # Keep a process handle before waiting: Windows PowerShell 5.1 can otherwise
    # lose ExitCode even after a successful native capture and process exit.
    $processHandle = $child.Handle
    if (-not $child.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $child.Id -ErrorAction SilentlyContinue
        throw "Only this verifier's child was stopped after timeout: $kind"
    }
    $child.WaitForExit()
    $exitCode = $child.ExitCode
    $outputText = Get-Content -LiteralPath $outputLog -Raw -Encoding UTF8
    $errorText = Get-Content -LiteralPath $errorLog -Raw -Encoding UTF8
    $captureLine = ($outputText -split "`r?`n" | Where-Object { $_.StartsWith('NATIVE_CAPTURE ') } | Select-Object -Last 1)
    if ($null -eq $exitCode -or $exitCode -ne 0 -or ($outputText + $errorText) -match '(?m)^\s*(SCRIPT ERROR|ERROR):' -or -not $captureLine) { throw "Native launch failed: $kind (exit=$exitCode, capture=$([bool]$captureLine))" }
    $capture = $captureLine.Substring('NATIVE_CAPTURE '.Length) | ConvertFrom-Json
    if ($capture.result -ne 0 -or -not (Test-Path -LiteralPath $picture)) { throw "Capture failed: $kind" }
    $results += [PSCustomObject]@{
        kind = $kind; executable = $exe; exit_code = $exitCode; file_version = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
        pck_sha256 = $package.files.'Scrapstorm.pck'; screenshot = $picture; mode = $capture.mode; locale = $capture.locale
        elapsed = $capture.stats.elapsed; enemies = $capture.stats.enemies; log = $outputLog; stderr = $errorLog
    }
}
$report = [PSCustomObject]@{ version = $releaseVersion; passed = $true; checks = $results; scope = 'Original export menu and extracted ZIP four-second legacy Demo combat via --smoke-start. Native renderer, no source path, isolated preferences; screenshot save and actual process exit verified separately. Quick is covered separately by browser entry checks.' }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $artifactRoot "$releaseLabel-windows-native-validation.json") -Encoding utf8
$report | ConvertTo-Json -Depth 8
