param(
    [string]$Version,
    [string]$Compiler,
    [string]$Project,
    [switch]$RequireVCRuntime,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows_packaging.ps1')
if (-not $Project) { $Project = Split-Path -Parent $PSScriptRoot }
$versionInfo = Get-ValhallaWindowsVersionInfo -Project $Project -Version $Version
$names = Get-ValhallaWindowsArtifactNames -VersionInfo $versionInfo
$bundle = Join-Path $Project 'build\windows\x64\runner\Release'
$payload = Get-ValhallaWindowsPayloadStatus -Bundle $bundle
if ($payload.Missing.Count -gt 0) {
    throw "Missing release file(s): $($payload.Missing -join ', ')"
}
if ($payload.MissingRuntime.Count -gt 0) {
    throw "VC++ runtime DLL(s) are not in the release bundle: $($payload.MissingRuntime -join ', '). The installer requires the Microsoft Visual C++ 2015-2022 x64 runtime. Install the official Microsoft VC++ redistributable x64 DLLs from installed VS redist to stage in the isolated bundle."
}
$Compiler = Resolve-ValhallaInnoCompiler -Compiler $Compiler
$output = Join-Path $Project 'build\windows-artifacts'
$installer = Join-Path $output $names.SetupExe
if (Test-Path -LiteralPath $installer) {
    throw "Refusing to overwrite existing artifact: $installer"
}
if ($ValidateOnly) {
    Write-Output 'validate-only=setup'
    Write-Output "version=$($versionInfo.Full)"
    Write-Output "setup_version=$($versionInfo.Version)"
    Write-Output "version_info=$($versionInfo.VersionInfo)"
    Write-Output "artifact=$installer"
    Write-Output "compiler=$Compiler"
    Write-Output "missing_runtime=$($payload.MissingRuntime -join ',')"
    Write-Output 'VALIDATE_OK'
    return
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
& $Compiler "/DValhallaAppVersion=$($versionInfo.Version)" "/DValhallaAppBuild=$($versionInfo.Build)" "/DValhallaOutputBaseFilename=$($names.SetupBase)" (Join-Path $PSScriptRoot 'windows_installer.iss')
if ($LASTEXITCODE -ne 0) { throw 'EXE installer compilation failed' }
if (-not (Test-Path -LiteralPath $installer)) { throw "Inno Setup did not produce the expected artifact: $installer" }
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLower()
"$hash  $([IO.Path]::GetFileName($installer))" | Set-Content -LiteralPath "$installer.sha256" -Encoding ASCII
Get-Item -LiteralPath $installer | Select-Object FullName, Length, LastWriteTime
Write-Output "Version: $($versionInfo.Full)"
Write-Output "SHA256: $hash"
