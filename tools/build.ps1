param(
    [ValidateSet('All', 'Windows', 'Web')][string]$Target = 'All',
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$version = (Get-Content -LiteralPath (Join-Path $projectRoot '.godot-version') -Raw).Trim()
$releaseMatch = Select-String -LiteralPath (Join-Path $projectRoot 'project.godot') -Pattern '^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
if (-not $releaseMatch) { throw 'A semantic project version is required for versioned Windows output.' }
$releaseVersion = $releaseMatch.Matches[0].Groups[1].Value
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectRoot ".tools/godot/Godot_v$($version)-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Run tools/setup_godot.ps1 -IncludeTemplates first, or supply -GodotPath.' }
$installedVersion = (& $GodotPath --headless --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $installedVersion.StartsWith("$version.stable.official.")) {
    throw "Expected Godot $version stable, got: $installedVersion"
}
$templateRoot = Join-Path $projectRoot ".tools/export_templates/$version.stable"
$requiredTemplates = @('version.txt')
if ($Target -in @('All', 'Windows')) { $requiredTemplates += 'windows_release_x86_64.exe' }
if ($Target -in @('All', 'Web')) { $requiredTemplates += 'web_nothreads_release.zip' }
foreach ($template in $requiredTemplates) {
    if (-not (Test-Path -LiteralPath (Join-Path $templateRoot $template))) { throw "Missing $template. Run tools/setup_godot.ps1 -IncludeTemplates." }
}
if ((Get-Content -LiteralPath (Join-Path $templateRoot 'version.txt') -Raw).Trim() -ne "$version.stable") { throw 'Export template version mismatch.' }
$nodeModules = Join-Path $projectRoot 'node_modules'
if (Test-Path -LiteralPath $nodeModules -PathType Container) {
    [IO.File]::WriteAllText((Join-Path $nodeModules '.gdignore'), '')
}
foreach ($generated in @('exports', 'captures', 'artifacts')) {
    $generatedPath = Join-Path $projectRoot $generated
    New-Item -ItemType Directory -Path $generatedPath -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $generatedPath '.gdignore'), '')
}
function Invoke-GodotChecked {
    param([string]$Stage, [string[]]$Arguments)
    $stageOutput = @(& $GodotPath @Arguments 2>&1)
    $stageExitCode = $LASTEXITCODE
    $stageText = ($stageOutput | Out-String)
    [IO.File]::WriteAllText((Join-Path $projectRoot "artifacts/build-$Stage.log"), $stageText)
    $stageOutput | Write-Output
    # Godot can report GDScript errors while still returning exit code zero.
    if ($stageExitCode -ne 0 -or $stageText -match '(?m)^\s*(?:SCRIPT ERROR|ERROR):') {
        throw "Godot $Stage failed; see artifacts/build-$Stage.log."
    }
}
Invoke-GodotChecked -Stage 'import' -Arguments @('--headless', '--path', $projectRoot, '--editor', '--import')
$targets = if ($Target -eq 'All') { @('Windows', 'Web') } else { @($Target) }
foreach ($platform in $targets) {
    $folder = if ($platform -eq 'Windows') { "windows-v$releaseVersion" } else { 'web' }
    $preset = if ($platform -eq 'Windows') { 'Windows Desktop' } else { 'Web' }
    $outDir = Join-Path $projectRoot "exports/$folder"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $entry = if ($platform -eq 'Windows') { 'Scrapstorm.exe' } else { 'index.html' }
    Invoke-GodotChecked -Stage $folder -Arguments @('--headless', '--path', $projectRoot, '--export-release', $preset, (Join-Path $outDir $entry))
    Copy-Item -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.md') -Destination $outDir -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/OFL.txt') -Destination (Join-Path $outDir 'FONT-LICENSE.txt') -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/Rajdhani-OFL.txt') -Destination (Join-Path $outDir 'RAJDHANI-LICENSE.txt') -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/licenses/GODOT_LICENSE.txt') -Destination $outDir -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/licenses/GODOT_COPYRIGHT.txt') -Destination $outDir -Force
    foreach ($notice in @('CREDITS.md', 'PRIVACY.md', 'README-PLAY.txt', 'LICENSE')) {
        $noticePath = Join-Path $projectRoot $notice
        if (Test-Path -LiteralPath $noticePath) { Copy-Item -LiteralPath $noticePath -Destination $outDir -Force }
    }
    if ($platform -eq 'Windows') {
        foreach ($launcher in @('Play.cmd', 'Play.ps1')) {
            Copy-Item -LiteralPath (Join-Path $projectRoot $launcher) -Destination $outDir -Force
        }
    }
    $expected = if ($platform -eq 'Windows') { @('Scrapstorm.exe', 'Scrapstorm.pck') } else { @('index.html', 'index.js', 'index.wasm', 'index.pck') }
    foreach ($file in $expected) {
        if (-not (Test-Path -LiteralPath (Join-Path $outDir $file)) -or (Get-Item -LiteralPath (Join-Path $outDir $file)).Length -eq 0) { throw "Missing or empty export output: $file" }
    }
    $manifest = [ordered]@{ project_version = $releaseVersion; engine = $installedVersion; built_at_utc = [DateTime]::UtcNow.ToString('o'); files = @() }
    foreach ($file in (Get-ChildItem -LiteralPath $outDir -File | Where-Object { $_.Name -ne 'build-manifest.json' -and $_.Extension -ne '.tmp' })) {
        $manifest.files += [ordered]@{ name = $file.Name; bytes = $file.Length; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outDir 'build-manifest.json') -Encoding utf8
    Write-Output "Built $platform -> $outDir"
}
