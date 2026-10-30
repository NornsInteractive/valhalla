param(
    [string]$Version,
    [string]$Project,
    [string]$SdkBin,
    [string]$MakeAppx,
    [string]$IdentityFile,
    [string]$PackageName,
    [string]$Publisher,
    [string]$PublisherDisplayName,
    [string]$DisplayName,
    [switch]$RequireVCRuntime,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows_packaging.ps1')
if (-not $Project) { $Project = Split-Path -Parent $PSScriptRoot }
$versionInfo = Get-ValhallaWindowsVersionInfo -Project $Project -Version $Version
$names = Get-ValhallaWindowsArtifactNames -VersionInfo $versionInfo
$identity = Get-ValhallaWindowsStoreIdentity -Project $Project -IdentityFile $IdentityFile
if (-not [string]::IsNullOrWhiteSpace($PackageName)) { $identity.Name = $PackageName }
if (-not [string]::IsNullOrWhiteSpace($Publisher)) { $identity.Publisher = $Publisher }
if (-not [string]::IsNullOrWhiteSpace($PublisherDisplayName)) { $identity.PublisherDisplayName = $PublisherDisplayName }
if (-not [string]::IsNullOrWhiteSpace($DisplayName)) { $identity.DisplayName = $DisplayName }
$makeappx = Resolve-ValhallaMakeAppx -SdkBin $SdkBin -MakeAppx $MakeAppx
$bundle = Join-Path $Project 'build\windows\x64\runner\Release'
$payload = Get-ValhallaWindowsPayloadStatus -Bundle $bundle
if ($payload.Missing.Count -gt 0) {
    throw "Missing release file(s): $($payload.Missing -join ', ')"
}
if ($payload.MissingRuntime.Count -gt 0) {
    throw "VC++ runtime DLL(s) are not in the release bundle: $($payload.MissingRuntime -join ', '). The Store package requires the Microsoft Visual C++ 2015-2022 x64 runtime. Install the official Microsoft VC++ redistributable x64 DLLs from installed VS redist to stage in the isolated bundle."
}
$output = Join-Path $Project 'build\windows-artifacts'
$package = Join-Path $output $names.StoreMsix
if (Test-Path -LiteralPath $package) {
    throw "Refusing to overwrite existing artifact: $package"
}
if ($ValidateOnly) {
    $manifest = New-ValhallaWindowsMsixManifest -Identity $identity -VersionInfo $versionInfo
    $doc = New-Object System.Xml.XmlDocument
    $doc.LoadXml($manifest)
    $identityNode = $doc.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
    Write-Output 'validate-only=msix'
    Write-Output "version=$($versionInfo.Full)"
    Write-Output "msix_version=$($versionInfo.Msix)"
    Write-Output "artifact=$package"
    Write-Output "makeappx=$makeappx"
    Write-Output "name=$($identityNode.GetAttribute('Name'))"
    Write-Output "publisher=$($identityNode.GetAttribute('Publisher'))"
    Write-Output "display_name=$($identity.DisplayName)"
    Write-Output "publisher_display_name=$($identity.PublisherDisplayName)"
    Write-Output "missing_runtime=$($payload.MissingRuntime -join ',')"
    Write-Output 'VALIDATE_OK'
    return
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
$stage = Join-Path $output ('msix-staging-' + [Guid]::NewGuid().ToString('N'))
$completed = $false
try {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Get-ChildItem -LiteralPath $bundle | Where-Object {
        $_.PSIsContainer -or $_.Extension -in @('.exe', '.dll')
    } | Copy-Item -Destination $stage -Recurse -Force

    foreach ($notice in @('LICENSE', 'NOTICE')) {
        Copy-Item -LiteralPath (Join-Path $Project $notice) -Destination $stage -Force
    }
    $smbNotices = Join-Path $stage 'licenses\libsmb2'
    $xtermNotices = Join-Path $stage 'licenses\xterm'
    New-Item -ItemType Directory -Path $xtermNotices -Force | Out-Null
    foreach ($notice in @('packages\xterm\LICENSE', 'packages\xterm\NOTICE')) {
        Copy-Item -LiteralPath (Join-Path $Project $notice) -Destination $xtermNotices -Force
    }
    New-Item -ItemType Directory -Path $smbNotices -Force | Out-Null
    foreach ($notice in @('packages\valhalla_smb\NOTICE', 'packages\valhalla_smb\vendor\libsmb2\COPYING', 'packages\valhalla_smb\vendor\libsmb2\LICENCE-LGPL-2.1.txt')) {
        Copy-Item -LiteralPath (Join-Path $Project $notice) -Destination $smbNotices -Force
    }

    # Generate Windows tile assets from the existing app icon, without new artwork.
    Add-Type -AssemblyName System.Drawing
    $images = Join-Path $stage 'Images'
    New-Item -ItemType Directory -Path $images | Out-Null
    $source = [Drawing.Image]::FromFile((Join-Path $Project 'assets\icons\valhalla_icon.png'))
    try {
        foreach ($asset in @(@('StoreLogo', 50), @('Square44x44Logo', 44), @('Square150x150Logo', 150))) {
            foreach ($scale in @(100, 125, 150, 200, 400)) {
                $size = [int]([int]$asset[1] * $scale / 100)
                $bitmap = New-Object Drawing.Bitmap($size, $size)
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                try {
                    $graphics.Clear([Drawing.Color]::Transparent)
                    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
                    $padding = [int]($size * 0.12)
                    $graphics.DrawImage($source, $padding, $padding, $size - 2 * $padding, $size - 2 * $padding)
                    $name = if ($scale -eq 100) { "$($asset[0]).png" } else { "$($asset[0]).scale-$scale.png" }
                    $bitmap.Save((Join-Path $images $name), [Drawing.Imaging.ImageFormat]::Png)
                } finally { $graphics.Dispose(); $bitmap.Dispose() }
            }
        }
    } finally { $source.Dispose() }

    # Ask Windows to derive the family name; this also catches copied identity typos.
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ValhallaPackageIdentity {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PackageId {
        public uint Reserved;
        public uint Architecture;
        public ulong Version;
        [MarshalAs(UnmanagedType.LPWStr)] public string Name;
        [MarshalAs(UnmanagedType.LPWStr)] public string Publisher;
        [MarshalAs(UnmanagedType.LPWStr)] public string ResourceId;
        [MarshalAs(UnmanagedType.LPWStr)] public string PublisherId;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern int PackageFamilyNameFromId(ref PackageId id, ref uint length, StringBuilder result);
    public static string FamilyName(string name, string publisher) {
        var id = new PackageId { Name = name, Publisher = publisher, ResourceId = "", Architecture = 9 };
        uint length = 256;
        var result = new StringBuilder((int)length);
        int error = PackageFamilyNameFromId(ref id, ref length, result);
        if (error != 0) throw new InvalidOperationException("PackageFamilyNameFromId: " + error);
        return result.ToString();
    }
}
'@
    $familyName = [ValhallaPackageIdentity]::FamilyName($identity.Name, $identity.Publisher)
    if ($identity.Name -eq 'Norns.Valhalla-' -and $familyName -ne 'Norns.Valhalla-_sxt4q0tm9x2xr') {
        throw "Store identity mismatch: $familyName"
    }
    Write-Output "Package family name: $familyName"

    $manifest = New-ValhallaWindowsMsixManifest -Identity $identity -VersionInfo $versionInfo
    $manifestPath = Join-Path $stage 'AppxManifest.xml'
    [IO.File]::WriteAllText($manifestPath, $manifest, (New-Object Text.UTF8Encoding($false)))
    & $makeappx pack /d $stage /p $package /h SHA256
    if ($LASTEXITCODE -ne 0) { throw 'MakeAppx packaging/validation failed' }
    if (-not (Test-Path -LiteralPath $package)) { throw "MakeAppx did not produce the expected artifact: $package" }
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $output $names.Manifest) -Force
    $completed = $true
} finally {
    if ($completed) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Warning "MSIX staging preserved for diagnosis: $stage"
    }
}
$digest = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
"$digest  $([IO.Path]::GetFileName($package))" | Set-Content -LiteralPath "$package.sha256" -Encoding ASCII
Get-Item -LiteralPath $package | Select-Object FullName, Length, LastWriteTime
Write-Output "Version: $($versionInfo.Full)"
Write-Output "SHA256: $digest"
Write-Output 'Unsigned Store submission package. Microsoft signs the package after certification.'
