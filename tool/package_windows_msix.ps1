param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,
    [string]$Project,
    [string]$SdkBin = 'D:\Data\Env\windows-sdk-buildtools\bin\10.0.26100.0\x64',
    [string]$PackageName = 'Norns.Valhalla-',
    [string]$Publisher = 'CN=257586C2-E7B0-47F3-BAED-A744A66748A1',
    [string]$PublisherDisplayName = 'Norns',
    [string]$Version = '1.0.3.0'
)
$ErrorActionPreference = 'Stop'
if (-not $Project) { $Project = Split-Path -Parent $PSScriptRoot }
if ([string]::IsNullOrWhiteSpace($DisplayName)) { throw 'The exact reserved Store display name is required' }
if ($Version -notmatch '^[1-9][0-9]*\.[0-9]+\.[0-9]+\.0$') {
    throw 'Store package version must have four parts and end in .0'
}
$makeappx = Join-Path $SdkBin 'makeappx.exe'
if (-not (Test-Path -LiteralPath $makeappx)) { throw 'Windows SDK MakeAppx is required' }
$bundle = Join-Path $Project 'build\windows\x64\runner\Release'
foreach ($required in @('valhalla.exe', 'flutter_windows.dll', 'data\app.so', 'data\flutter_assets\PRIVACY.md', 'data\flutter_assets\PRIVACY.en.md', 'vcruntime140.dll', 'msvcp140.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $required))) { throw "Missing release file: $required" }
}
$output = Join-Path $Project 'build\windows-artifacts'
$stage = Join-Path $output ('msix-staging-' + [Guid]::NewGuid().ToString('N'))
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

$nameXml = [Security.SecurityElement]::Escape($PackageName)
$publisherXml = [Security.SecurityElement]::Escape($Publisher)
$publisherDisplayXml = [Security.SecurityElement]::Escape($PublisherDisplayName)
$displayNameXml = [Security.SecurityElement]::Escape($DisplayName)
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
$familyName = [ValhallaPackageIdentity]::FamilyName($PackageName, $Publisher)
if ($PackageName -eq 'Norns.Valhalla-' -and $familyName -ne 'Norns.Valhalla-_sxt4q0tm9x2xr') {
    throw "Store identity mismatch: $familyName"
}
Write-Output "Package family name: $familyName"
$languages = @('en', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'de', 'fr', 'es', 'pt', 'ru', 'ar', 'hi', 'id', 'it', 'tr', 'vi', 'th')
$resourceXml = ($languages | ForEach-Object { "    <Resource Language=`"$_`" />" }) -join "`n"
$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap rescap">
  <Identity Name="$nameXml" Publisher="$publisherXml" Version="$Version" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>$displayNameXml</DisplayName>
    <PublisherDisplayName>$publisherDisplayXml</PublisherDisplayName>
    <Description>Remote server management, SSH terminals and file transfers.</Description>
    <Logo>Images\StoreLogo.png</Logo>
  </Properties>
  <Resources>
$resourceXml
  </Resources>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>
  <Applications>
    <Application Id="Valhalla" Executable="valhalla.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="$displayNameXml" Description="Remote server management, SSH terminals and file transfers."
          Square150x150Logo="Images\Square150x150Logo.png" Square44x44Logo="Images\Square44x44Logo.png" BackgroundColor="transparent" />
    </Application>
  </Applications>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
</Package>
"@
[IO.File]::WriteAllText((Join-Path $stage 'AppxManifest.xml'), $manifest, (New-Object Text.UTF8Encoding($false)))
$package = Join-Path $output "valhalla-$Version-windows-x64-store.msix"
& $makeappx pack /d $stage /p $package /h SHA256 /o
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx packaging/validation failed' }
$digest = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
"$digest  $([IO.Path]::GetFileName($package))" | Set-Content -LiteralPath "$package.sha256" -Encoding ASCII
Copy-Item -LiteralPath (Join-Path $stage 'AppxManifest.xml') -Destination (Join-Path $output 'store-AppxManifest.xml') -Force
Get-Item -LiteralPath $package | Select-Object FullName, Length, LastWriteTime
Write-Output "SHA256: $digest"
Write-Output 'Unsigned Store submission package. Microsoft signs the package after certification.'
