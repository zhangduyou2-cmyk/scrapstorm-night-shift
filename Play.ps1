[CmdletBinding()]
param([switch]$Editor, [switch]$PreferBuild, [switch]$Smoke)
$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$launcherLog = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Scrapstorm-Launcher/launcher.log'
trap {
    $message = $_.Exception.Message
    try {
        [IO.Directory]::CreateDirectory((Split-Path $launcherLog)) | Out-Null
        [IO.File]::AppendAllText($launcherLog, ([DateTime]::Now.ToString('s') + ' ' + $message + [Environment]::NewLine))
    } catch { }
    [Console]::Error.WriteLine('Could not open SCRAPSTORM: ' + $message)
    [Console]::Error.WriteLine('Launcher log: ' + $launcherLog)
    exit 1
}

function Start-VisibleGame {
    param([string]$Executable, [string]$Directory, [string[]]$Arguments = @(), [switch]$ReuseExisting)
    # Use the exact executable path: a separate recording build is never reused or closed.
    if (-not ('ScrapstormLauncherWindow' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ScrapstormLauncherWindow {
    private delegate bool EnumProc(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr window);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr window, uint command);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr window, int command);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
    public static IntPtr Find(int processId) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr window, IntPtr data) {
            uint pid; GetWindowThreadProcessId(window, out pid);
            StringBuilder kind = new StringBuilder(128);
            GetClassName(window, kind, kind.Capacity);
            // OpenGL drivers also create titled invisible windows in the game process.
            if (pid == processId && kind.ToString() == "Engine" && GetWindowTextLength(window) > 0 && GetWindow(window, 4) == IntPtr.Zero) {
                found = window; return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static void Reveal(IntPtr window) {
        ShowWindowAsync(window, IsIconic(window) ? 9 : 5);
        if (MonitorFromWindow(window, 0) == IntPtr.Zero)
            SetWindowPos(window, IntPtr.Zero, 100, 100, 0, 0, 0x45);
        SetForegroundWindow(window);
    }
}
'@
    }
    $fullPath = [IO.Path]::GetFullPath($Executable)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($fullPath.ToLowerInvariant())))).Replace('-', '') }
    finally { $hasher.Dispose() }
    $gate = New-Object Threading.Mutex($false, ('Local\ScrapstormLauncher-' + $key))
    $locked = $false
    try {
        try { $locked = $gate.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { throw 'Another launch is still in progress. Please try again shortly.' }
        $gameProcess = $null
        if ($ReuseExisting) {
            foreach ($candidate in [Diagnostics.Process]::GetProcessesByName([IO.Path]::GetFileNameWithoutExtension($fullPath))) {
                try {
                    if (-not $candidate.HasExited -and $candidate.MainModule.FileName -eq $fullPath) { $gameProcess = $candidate; break }
                } catch { }
            }
        }
        if ($null -eq $gameProcess) {
            $info = New-Object Diagnostics.ProcessStartInfo
            $info.FileName = $fullPath
            $info.WorkingDirectory = $Directory
            $info.Arguments = $Arguments -join ' '
            $info.UseShellExecute = $true
            $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Normal
            $gameProcess = [Diagnostics.Process]::Start($info)
        }
        $deadline = [DateTime]::UtcNow.AddSeconds(15)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($gameProcess.HasExited) { throw ('Game exited before opening a window (exit ' + $gameProcess.ExitCode + '). Check that Scrapstorm.exe and Scrapstorm.pck are together.') }
            $window = [ScrapstormLauncherWindow]::Find($gameProcess.Id)
            if ($window -ne [IntPtr]::Zero) {
                [ScrapstormLauncherWindow]::Reveal($window)
                [Threading.Thread]::Sleep(100)
                if ([ScrapstormLauncherWindow]::IsWindowVisible($window)) {
                    Write-Output ('SCRAPSTORM window ready (PID ' + $gameProcess.Id + ').')
                    return
                }
            }
            [Threading.Thread]::Sleep(100)
        }
        throw 'The game process exists but no window appeared within 15 seconds. It has been left running; try Play.cmd again or inspect the game log.'
    } finally {
        if ($locked) { $gate.ReleaseMutex() }
        $gate.Dispose()
    }
}

# The small player ZIP contains the EXE beside this script and needs no editor.
$portableGame = Join-Path $gameRoot 'Scrapstorm.exe'
if (-not $Editor -and -not $Smoke -and (Test-Path -LiteralPath $portableGame)) {
    if (-not (Test-Path -LiteralPath (Join-Path $gameRoot 'Scrapstorm.pck'))) { throw 'Scrapstorm.pck is missing. Extract the complete ZIP before playing.' }
    Start-VisibleGame -Executable $portableGame -Directory $gameRoot -ReuseExisting
    return
}
$version = (Get-Content -LiteralPath (Join-Path $gameRoot '.godot-version') -Raw).Trim()
$releaseMatch = Select-String -LiteralPath (Join-Path $gameRoot 'project.godot') -Pattern '^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$'
if (-not $releaseMatch) { throw 'Missing semantic project version.' }
$releaseVersion = $releaseMatch.Matches[0].Groups[1].Value
$package = Join-Path $gameRoot "exports/windows-v$releaseVersion/Scrapstorm.exe"
if ($PreferBuild -and -not $Editor -and -not $Smoke -and (Test-Path -LiteralPath $package)) {
    if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($package, '.pck')))) { throw 'The Windows build is missing Scrapstorm.pck.' }
    Start-VisibleGame -Executable $package -Directory (Split-Path $package) -ReuseExisting
    return
}
$engineRoot = Join-Path $gameRoot '.tools/godot'
$engine = Join-Path $engineRoot "Godot_v$version-stable_win64_console.exe"
$gui = Join-Path $engineRoot "Godot_v$version-stable_win64.exe"
if (-not (Test-Path -LiteralPath $engine) -or -not (Test-Path -LiteralPath $gui)) {
    & (Join-Path $gameRoot 'tools/setup_godot.ps1')
}
$actualVersion = (& $engine --headless --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $actualVersion.StartsWith("$version.stable.official.")) { throw "Expected pinned Godot $version, got $actualVersion" }
$nodeModules = Join-Path $gameRoot 'node_modules'
if (Test-Path -LiteralPath $nodeModules -PathType Container) {
    [IO.File]::WriteAllText((Join-Path $nodeModules '.gdignore'), '')
}
if (-not $Editor) {
    # A source download has no imported textures, font caches or class registry.
    $importOutput = @(& $engine --headless --path $gameRoot --editor --import 2>&1)
    $importExit = $LASTEXITCODE
    $importText = $importOutput | Out-String
    if ($importExit -ne 0 -or $importText -match '(?m)^\s*(SCRIPT ERROR|ERROR):') { $importOutput | Write-Output; throw 'Source import failed.' }
}
if ($Smoke) {
    $output = @(& $engine --headless --path $gameRoot --quit-after 5 -- --test-settings 2>&1)
    $runExit = $LASTEXITCODE
    $text = $output | Out-String
    $output | Write-Output
    if ($runExit -ne 0 -or $text -match '(?m)^\s*(SCRIPT ERROR|ERROR):') { throw 'Isolated source startup failed.' }
    Write-Output 'SOURCE_STARTUP_OK (five headless frames; not gameplay or rendering acceptance)'
    return
}
$launchArgs = @('--path', ('"' + $gameRoot + '"'))
if ($Editor) { $launchArgs += '--editor' }
Start-VisibleGame -Executable $gui -Directory $gameRoot -Arguments $launchArgs
