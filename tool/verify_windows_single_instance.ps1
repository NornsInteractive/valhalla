param([string]$Executable)
$ErrorActionPreference = 'Stop'
if (-not $Executable) { $Executable = Join-Path (Split-Path -Parent $PSScriptRoot) 'build\windows\x64\runner\Release\valhalla.exe' }
if (Get-Process -Name valhalla -ErrorAction SilentlyContinue) { throw 'Close existing Valhalla windows before running this verification.' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ValhallaSingleInstanceTest {
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);
}
'@
$owned = [Collections.Generic.List[Diagnostics.Process]]::new()
function Launch-TestInstance {
    $process = Start-Process -FilePath $Executable -WorkingDirectory (Split-Path -Parent $Executable) -WindowStyle Hidden -PassThru
    $owned.Add($process)
    return $process
}
function Wait-TestWindow {
    for ($i = 0; $i -lt 40; $i++) {
        $running = @($owned | Where-Object { -not $_.HasExited })
        if ($running.Count -eq 1) {
            $running[0].Refresh()
            if ($running[0].MainWindowHandle -ne [IntPtr]::Zero) { return $running[0] }
        }
        Start-Sleep -Milliseconds 250
    }
    throw 'Expected one responsive application window.'
}
try {
    for ($i = 0; $i -lt 8; $i++) { $null = Launch-TestInstance }
    Start-Sleep -Seconds 3
    $primary = Wait-TestWindow
    $hwnd = $primary.MainWindowHandle
    if ([ValhallaSingleInstanceTest]::IsHungAppWindow($hwnd)) { throw 'Primary window is hung.' }
    Write-Output "Concurrent startup passed: one process, PID $($primary.Id)."
    $null = [ValhallaSingleInstanceTest]::ShowWindow($hwnd, 6)
    if (-not [ValhallaSingleInstanceTest]::IsIconic($hwnd)) { throw 'Failed to minimize test window.' }
    $secondary = Launch-TestInstance
    if (-not $secondary.WaitForExit(5000)) { throw 'Secondary process did not exit.' }
    Start-Sleep -Milliseconds 800
    $primary.Refresh()
    if ($primary.HasExited -or [ValhallaSingleInstanceTest]::IsIconic($hwnd)) { throw 'Existing window was not restored.' }
    Write-Output 'Repeated launch restored the original window and kept its process.'
    $null = [ValhallaSingleInstanceTest]::PostMessage($hwnd, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
    if (-not $primary.WaitForExit(5000)) { throw 'Application did not close normally.' }
    $null = Launch-TestInstance
    $restarted = Wait-TestWindow
    Write-Output 'Normal close and restart passed.'
    $restarted.Kill()
    $restarted.WaitForExit()
    $null = Launch-TestInstance
    $recovered = Wait-TestWindow
    if ([ValhallaSingleInstanceTest]::IsHungAppWindow($recovered.MainWindowHandle)) { throw 'Recovered window is hung.' }
    Write-Output 'Abnormal exit and restart passed.'
} finally {
    foreach ($process in $owned) {
        if (-not $process.HasExited) {
            $process.Refresh()
            $null = [ValhallaSingleInstanceTest]::PostMessage($process.MainWindowHandle, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
            if (-not $process.WaitForExit(5000)) { $process.Kill(); $process.WaitForExit() }
        }
    }
}
