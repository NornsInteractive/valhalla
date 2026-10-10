param(
    [string]$Compiler = 'D:\Data\Env\inno-setup\ISCC.exe'
)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $project 'build\windows\x64\runner\Release'
foreach ($required in @('valhalla.exe', 'flutter_windows.dll', 'data\app.so', 'data\flutter_assets\LICENSE', 'data\flutter_assets\NOTICE', 'data\flutter_assets\PRIVACY.md', 'data\flutter_assets\PRIVACY.en.md', 'LICENSE', 'NOTICE', 'licenses\libsmb2\LICENCE-LGPL-2.1.txt', 'vcruntime140.dll', 'msvcp140.dll', 'zlib.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $required))) {
        throw "Missing release file: $required"
    }
}
if (-not (Test-Path -LiteralPath $Compiler)) { throw 'Inno Setup compiler is required' }
& $Compiler (Join-Path $PSScriptRoot 'windows_installer.iss')
if ($LASTEXITCODE -ne 0) { throw 'EXE installer compilation failed' }
$installer = Join-Path $project 'build\windows-artifacts\valhalla-1.0.3-windows-x64-setup.exe'
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLower()
"$hash  $([IO.Path]::GetFileName($installer))" | Set-Content -LiteralPath "$installer.sha256" -Encoding ASCII
Get-Item -LiteralPath $installer | Select-Object FullName, Length, LastWriteTime
Write-Output "SHA256: $hash"
