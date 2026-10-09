$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $project 'build\windows\x64\runner\Release'
$backup = Join-Path $project ('build\windows-artifacts\production-before-native-smoke-' + [Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $backup) { throw 'Backup already exists' }
Copy-Item -LiteralPath $bundle -Destination $backup -Recurse
$config = Join-Path $project 'windows\flutter\ephemeral\generated_config.cmake'
Copy-Item -LiteralPath $config -Destination (Join-Path $backup 'generated_config.cmake')
$script = [IO.File]::ReadAllText('D:\Data\Env\build-valhalla-windows.ps1')
$script = $script.Replace('flutter build windows --release --no-pub', 'flutter build windows --release --no-pub --target tool/windows_native_smoke.dart')
$script = $script.Replace('build\windows-artifacts\build.log', 'build\windows-artifacts\native-smoke-build.log')
[IO.File]::WriteAllText('D:\Data\Env\compile-valhalla-smoke.ps1', $script)
try {
    & 'D:\Data\Env\compile-valhalla-smoke.ps1'
    if ($LASTEXITCODE -ne 0) { throw 'Fixture compilation failed' }
    $fixture = Join-Path $project 'build\windows-artifacts\native-input-fixture'
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    Get-ChildItem -LiteralPath $bundle | Copy-Item -Destination $fixture -Recurse -Force
    Write-Output "Fixture: $fixture"
} finally {
    # Restore every product file before packaging. The fixture is separate.
    Get-ChildItem -LiteralPath $backup | Where-Object { $_.Name -ne 'generated_config.cmake' } | Copy-Item -Destination $bundle -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $backup 'generated_config.cmake') -Destination $config -Force
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $backup 'data\app.so')).Hash
    if ($sourceHash -ne (Get-FileHash -LiteralPath (Join-Path $bundle 'data\app.so')).Hash) { throw 'Production AOT restore failed' }
    Write-Output 'Production bundle and default entrypoint restored.'
}
