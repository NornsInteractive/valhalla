# Shared Windows packaging logic. Dot-source from packaging scripts.
# Keeps version, identity, payload and tool discovery behaviour in one place.

function Get-ValhallaWindowsVersionInfo {
    param(
        [Parameter(Mandatory = $true)][string]$Project,
        [string]$Version
    )
    $pubspec = Join-Path $Project 'pubspec.yaml'
    $pubVersion = $null
    $pubBuild = $null
    if (Test-Path -LiteralPath $pubspec) {
        $line = Select-String -LiteralPath $pubspec -Pattern '^version:\s*(\S+)\s*$' | Select-Object -First 1
        if ($line) {
            $value = $line.Matches[0].Groups[1].Value
            if ($value -notmatch '^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$') {
                throw "pubspec.yaml version must be stable semantic version+build, got: $value"
            }
            $pubVersion = $Matches[1]
            $pubBuild = [int]$Matches[2]
        }
    }

    if ([string]::IsNullOrWhiteSpace($Version)) {
        if ($null -eq $pubVersion) {
            throw 'No version supplied and pubspec.yaml does not contain a stable version+build line'
        }
        $versionPart = $pubVersion
        $buildPart = $pubBuild
    } else {
        $value = $Version.Trim()
        if ($value -match '^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$') {
            $versionPart = $Matches[1]
            $buildPart = [int]$Matches[2]
        } elseif ($value -match '^([0-9]+\.[0-9]+\.[0-9]+)$') {
            if ($null -eq $pubVersion) {
                throw 'A build number (+N) is required when pubspec.yaml is unavailable'
            }
            $versionPart = $Matches[1]
            $buildPart = $pubBuild
        } else {
            throw "Invalid version (expected X.Y.Z or X.Y.Z+N): $value"
        }
        if ($null -ne $pubVersion -and $versionPart -ne $pubVersion) {
            throw "Supplied version $versionPart does not match pubspec.yaml version $pubVersion"
        }
        if ($null -ne $pubBuild -and $buildPart -ne $pubBuild) {
            throw "Supplied build $buildPart does not match pubspec.yaml build $pubBuild"
        }
    }

    $parts = @($versionPart.Split('.') | ForEach-Object { [int]$_ })
    if ($parts[0] -lt 1) { throw "Major version must be at least 1: $versionPart" }
    foreach ($part in $parts) {
        if ($part -gt 65535) { throw "Version component exceeds 65535: $versionPart" }
    }
    if ($buildPart -lt 1 -or $buildPart -gt 65535) {
        throw "Build number must be between 1 and 65535, got: $buildPart"
    }

    [pscustomobject]@{
        Version     = $versionPart
        Build       = $buildPart
        Full        = "$versionPart+$buildPart"
        Msix        = "$versionPart.0"
        VersionInfo = "$versionPart.$buildPart"
    }
}

function Get-ValhallaWindowsArtifactNames {
    param([Parameter(Mandatory = $true)]$VersionInfo)
    $setupBase = "valhalla-$($VersionInfo.Version)-windows-x64-setup"
    [pscustomobject]@{
        SetupBase   = $setupBase
        SetupExe    = "$setupBase.exe"
        PortableZip = "valhalla-v$($VersionInfo.Version)-windows-x64.zip"
        StoreMsix   = "valhalla-$($VersionInfo.Msix)-windows-x64-store.msix"
        Manifest    = 'store-AppxManifest.xml'
    }
}

function Get-ValhallaWindowsStoreIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$Project,
        [string]$IdentityFile
    )
    if ([string]::IsNullOrWhiteSpace($IdentityFile)) {
        $IdentityFile = Join-Path $Project 'tool\windows_store_identity.json'
    }
    if (-not (Test-Path -LiteralPath $IdentityFile)) {
        throw "Store identity file is required: $IdentityFile"
    }
    $json = [IO.File]::ReadAllText($IdentityFile, [Text.Encoding]::UTF8)
    $identity = $json | ConvertFrom-Json
    foreach ($field in @('Name', 'Publisher', 'PublisherDisplayName', 'DisplayName')) {
        if ([string]::IsNullOrWhiteSpace([string]$identity.$field)) {
            throw "Store identity field is missing: $field"
        }
    }
    [pscustomobject]@{
        Name                 = [string]$identity.Name
        Publisher            = [string]$identity.Publisher
        PublisherDisplayName = [string]$identity.PublisherDisplayName
        DisplayName          = [string]$identity.DisplayName
    }
}

function New-ValhallaWindowsMsixManifest {
    param(
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)]$VersionInfo,
        [string[]]$Languages = @('en', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'de', 'fr', 'es', 'pt', 'ru', 'ar', 'hi', 'id', 'it', 'tr', 'vi', 'th')
    )
    if ($VersionInfo.Msix -notmatch '^[1-9][0-9]*\.[0-9]+\.[0-9]+\.0$') {
        throw "Store package version must have four parts and end in .0: $($VersionInfo.Msix)"
    }
    $nameXml = [Security.SecurityElement]::Escape([string]$Identity.Name)
    $publisherXml = [Security.SecurityElement]::Escape([string]$Identity.Publisher)
    $publisherDisplayXml = [Security.SecurityElement]::Escape([string]$Identity.PublisherDisplayName)
    $displayNameXml = [Security.SecurityElement]::Escape([string]$Identity.DisplayName)
    $versionXml = [Security.SecurityElement]::Escape([string]$VersionInfo.Msix)
    $resourceXml = ($Languages | ForEach-Object { "    <Resource Language=`"$_`" />" }) -join "`n"
    @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap rescap">
  <Identity Name="$nameXml" Publisher="$publisherXml" Version="$versionXml" ProcessorArchitecture="x64" />
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
}

function Get-ValhallaWindowsPayloadStatus {
    param([Parameter(Mandatory = $true)][string]$Bundle)
    if (-not (Test-Path -LiteralPath $Bundle)) {
        throw "Release bundle does not exist: $Bundle"
    }
    $required = @(
        'valhalla.exe',
        'flutter_windows.dll',
        'data\app.so',
        'data\icudtl.dat',
        'data\flutter_assets\LICENSE',
        'data\flutter_assets\NOTICE',
        'data\flutter_assets\PRIVACY.md',
        'data\flutter_assets\PRIVACY.en.md',
        'LICENSE',
        'NOTICE',
        'licenses\libsmb2\LICENCE-LGPL-2.1.txt',
        'zlib.dll'
    )
    $runtime = @('vcruntime140.dll', 'msvcp140.dll', 'vcruntime140_1.dll')
    $missing = @()
    $missingRuntime = @()
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $Bundle $relative))) {
            $missing += $relative
        }
    }
    foreach ($relative in $runtime) {
        if (-not (Test-Path -LiteralPath (Join-Path $Bundle $relative))) {
            $missingRuntime += $relative
        }
    }
    [pscustomobject]@{
        Required       = $required
        Runtime        = $runtime
        Missing        = $missing
        MissingRuntime = $missingRuntime
    }
}

function Resolve-ValhallaInnoCompiler {
    param([string]$Compiler)
    if (-not [string]::IsNullOrWhiteSpace($Compiler)) {
        if (-not (Test-Path -LiteralPath $Compiler)) {
            throw "Inno Setup compiler not found: $Compiler"
        }
        return (Resolve-Path -LiteralPath $Compiler).Path
    }
    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe',
        'C:\valhalla-build\tools\inno-setup\ISCC.exe',
        'C:\valhalla-build\inno-setup\ISCC.exe'
    )
    foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1'
    )) {
        if (Test-Path $key) {
            $location = (Get-ItemProperty $key -ErrorAction SilentlyContinue).InstallLocation
            if (-not [string]::IsNullOrWhiteSpace($location)) {
                $candidates += (Join-Path $location 'ISCC.exe')
            }
        }
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Inno Setup 6 compiler (ISCC.exe) not found. Install genuine Inno Setup 6 from https://jrsoftware.org or pass -Compiler.'
}

function Resolve-ValhallaMakeAppx {
    param(
        [string]$SdkBin,
        [string]$MakeAppx
    )
    if (-not [string]::IsNullOrWhiteSpace($MakeAppx)) {
        if (-not (Test-Path -LiteralPath $MakeAppx)) {
            throw "MakeAppx.exe not found: $MakeAppx"
        }
        return (Resolve-Path -LiteralPath $MakeAppx).Path
    }
    if (-not [string]::IsNullOrWhiteSpace($SdkBin)) {
        $candidate = Join-Path $SdkBin 'makeappx.exe'
        if (-not (Test-Path -LiteralPath $candidate)) {
            throw "MakeAppx.exe not found in -SdkBin: $SdkBin"
        }
        return (Resolve-Path -LiteralPath $candidate).Path
    }
    $command = Get-Command 'makeappx.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $roots = @(
        'C:\Program Files (x86)\Windows Kits\10\bin',
        'C:\Program Files\Windows Kits\10\bin',
        'C:\valhalla-build\windows-sdk-buildtools\bin'
    )
    $found = @()
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $candidate = Join-Path $_.FullName 'x64\makeappx.exe'
                if (Test-Path -LiteralPath $candidate) { $found += (Resolve-Path -LiteralPath $candidate).Path }
            }
        }
    }
    if ($found.Count -gt 0) {
        return ($found | Sort-Object -Descending | Select-Object -First 1)
    }
    throw 'Windows SDK MakeAppx.exe not found. Install the Windows SDK or pass -SdkBin/-MakeAppx.'
}
