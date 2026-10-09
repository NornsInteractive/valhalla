$ErrorActionPreference = 'Stop'
$project = (Split-Path -Parent $PSScriptRoot)
$fixture = Join-Path $project 'build\windows-artifacts\native-input-fixture'
$report = Join-Path $project ('build\windows-artifacts\native-input-results-' + [Guid]::NewGuid().ToString('N'))
if (Get-Process -Name valhalla -ErrorAction SilentlyContinue) { throw 'Close Valhalla before verification.' }
New-Item -ItemType Directory -Path $report -Force | Out-Null
$env:PYTHONPATH = 'D:\Data\Env\windows-smoke-deps'
$server = Start-Process -FilePath 'D:\Data\Env\uv-tools\portablemsvc\Scripts\python.exe' -ArgumentList @((Join-Path $PSScriptRoot 'windows_smoke_ssh.py'), $report) -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $report 'ssh-stderr.log')
$app = $null
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ValhallaNativeInput {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string name, string title);
 public delegate bool Callback(IntPtr window, IntPtr data);
 [DllImport("user32.dll")] public static extern bool EnumThreadWindows(uint thread, Callback callback, IntPtr data);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hwnd, Callback callback, IntPtr data);
 [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint mode);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder name, int size);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);
 public static IntPtr view;
 public static void WindowText(string value) {
  foreach(char c in value) {
   PostMessage(view, 0x100, (IntPtr)0xe7, (IntPtr)(1L | ((long)c<<16)));
   PostMessage(view, 0x102, (IntPtr)c, (IntPtr)1);
   PostMessage(view, 0x101, (IntPtr)0xe7, (IntPtr)(0xc0000001L | ((long)c<<16)));
   System.Threading.Thread.Sleep(100);
  }
 }
 public static void WindowKey(ushort vk, bool up) {
  uint bits = 1 | (MapVirtualKey(vk,0)<<16);
  if(up) bits |= 0xc0000000;
  PostMessage(view, up ? 0x101u : 0x100u, (IntPtr)vk, (IntPtr)(long)bits);
  System.Threading.Thread.Sleep(100);
 }
}
'@
try {
    for ($i = 0; $i -lt 40 -and -not (Test-Path (Join-Path $report 'ssh-ready')); $i++) { Start-Sleep -Milliseconds 250 }
    if (-not (Test-Path (Join-Path $report 'ssh-ready'))) { throw 'SSH fixture did not start' }
    $app = Start-Process -FilePath (Join-Path $fixture 'valhalla.exe') -ArgumentList $report -WorkingDirectory $fixture -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 60 -and -not (Test-Path (Join-Path $report 'ready')); $i++) {
        if ($app.HasExited) { throw 'Native fixture exited before becoming ready' }
        Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path (Join-Path $report 'ready'))) { throw 'Native fixture not ready' }
    $app.Refresh()
    $hwnd = $app.MainWindowHandle
    if ($hwnd -eq [IntPtr]::Zero) { $hwnd = [ValhallaNativeInput]::FindWindow('NORNS_VALHALLA_WIN32_WINDOW', $null) }
    if ($hwnd -eq [IntPtr]::Zero) {
        foreach ($thread in $app.Threads) {
            $callback = [ValhallaNativeInput+Callback]{ param($window, $data)
                $name = New-Object Text.StringBuilder 256
                $null = [ValhallaNativeInput]::GetClassName($window, $name, 256)
                Write-Host "Fixture thread window: $window class $name"
                if ($name.ToString() -eq 'NORNS_VALHALLA_WIN32_WINDOW') { $script:fixtureHandle = $window }
                return $true
            }
            $null = [ValhallaNativeInput]::EnumThreadWindows($thread.Id, $callback, [IntPtr]::Zero)
        }
        $hwnd = $script:fixtureHandle
    }
    if (-not $hwnd -or $hwnd -eq [IntPtr]::Zero) { throw 'Fixture has no main window' }
    $null = [ValhallaNativeInput]::ShowWindow($hwnd, 5)
    $null = [ValhallaNativeInput]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 300
    Write-Output "Native input target: PID $($app.Id), HWND $hwnd, foreground $([ValhallaNativeInput]::GetForegroundWindow())"
    $childCallback = [ValhallaNativeInput+Callback]{ param($window, $data)
        $name = New-Object Text.StringBuilder 256
        $null = [ValhallaNativeInput]::GetClassName($window, $name, 256)
        if ($name.ToString() -eq 'FLUTTERVIEW') { [ValhallaNativeInput]::view = $window }
        return $true
    }
    $null = [ValhallaNativeInput]::EnumChildWindows($hwnd, $childCallback, [IntPtr]::Zero)
    if ([ValhallaNativeInput]::view -eq [IntPtr]::Zero) { throw 'Flutter native view not found' }
    [ValhallaNativeInput]::WindowText('abc123')
    # Unicode input uses the real Windows engine text client, not Flutter test mocks.
    [ValhallaNativeInput]::WindowText([string][char]0x4e2d + [string][char]0x6587)
    [ValhallaNativeInput]::WindowKey(13, $false); [ValhallaNativeInput]::WindowKey(13, $true)
    [ValhallaNativeInput]::WindowKey(8, $false); [ValhallaNativeInput]::WindowKey(8, $true)
    [ValhallaNativeInput]::WindowKey(38, $false); [ValhallaNativeInput]::WindowKey(38, $true)
    [ValhallaNativeInput]::WindowKey(17, $false)
    [ValhallaNativeInput]::WindowKey(67, $false); [ValhallaNativeInput]::WindowKey(67, $true)
    [ValhallaNativeInput]::WindowKey(17, $true)
    Start-Sleep -Seconds 1
    $received = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $report 'ssh-input.bin')))
    foreach ($expected in @('abc123', ([string][char]0x4e2d + [string][char]0x6587))) {
        if (-not $received.Contains($expected)) { throw "Expected keyboard input not received over SSH: $expected" }
    }
    $errors = Get-Content (Join-Path $report 'errors.json') -Raw | ConvertFrom-Json
    if (@($errors).Count) { throw 'Native text input raised unhandled errors' }
    $reveal = Get-Content (Join-Path $report 'reveal.json') -Raw | ConvertFrom-Json
    if (-not ($reveal.existingFile -and $reveal.missingFileFallback -and $reveal.missingDirectory -and $reveal.nativeFailure)) { throw 'Native reveal verification failed' }
    Write-Output 'Native Windows WM_CHAR -> shared canvas -> localhost SSH passed: letters, numbers and Chinese Unicode.'
    Write-Output 'Real native revealFile passed: special path, deleted file fallback, missing directory and native error.'
    [ordered]@{ native_text_input='passed using targeted Unicode window messages'; local_ssh='passed'; unicode='passed'; unhandled_errors=0; native_reveal='passed'; ime_composition='covered by widget test, not physical IME'; physical_keyboard='not tested: target desktop cannot be activated' } | ConvertTo-Json | Set-Content (Join-Path $report 'verification.json') -Encoding UTF8
} finally {
    if ($app -and -not $app.HasExited) {
        $app.Refresh()
        $null = [ValhallaNativeInput]::PostMessage($app.MainWindowHandle, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
        if (-not $app.WaitForExit(3000)) { $app.Kill(); $app.WaitForExit() }
    }
    if (-not $server.HasExited) { $server.Kill(); $server.WaitForExit() }
    # Close only Explorer windows opened on this verification directory.
    $shell = New-Object -ComObject Shell.Application
    foreach ($window in @($shell.Windows())) {
        if ([uri]::UnescapeDataString($window.LocationURL).Replace('/', '\').Contains($report)) { $window.Quit() }
    }
}
