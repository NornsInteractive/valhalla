param(
    [string]$Version,
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
    $message = "VC++ runtime DLL(s) are not in the release bundle: $($payload.MissingRuntime -join ', '). Portable users need the Microsoft Visual C++ 2015-2022 x64 runtime. Pass -RequireVCRuntime to fail instead."
    if ($RequireVCRuntime) { throw $message }
    Write-Warning $message
}
$output = Join-Path $Project 'build\windows-artifacts'
$zip = Join-Path $output $names.PortableZip
if (Test-Path -LiteralPath $zip) {
    throw "Refusing to overwrite existing artifact: $zip"
}
if ($ValidateOnly) {
    Write-Output 'validate-only=zip'
    Write-Output "version=$($versionInfo.Full)"
    Write-Output "artifact=$zip"
    Write-Output "missing_runtime=$($payload.MissingRuntime -join ',')"
    Write-Output 'VALIDATE_OK'
    return
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip -CompressionLevel Optimal
if (-not (Test-Path -LiteralPath $zip)) { throw "ZIP packaging did not produce the expected artifact: $zip" }
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
"$hash  $([IO.Path]::GetFileName($zip))" | Set-Content -LiteralPath "$zip.sha256" -Encoding ASCII
Get-Item -LiteralPath $zip | Select-Object FullName, Length, LastWriteTime
Write-Output "Version: $($versionInfo.Full)"
Write-Output "SHA256: $hash"
