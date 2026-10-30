param(
    [string]$Repo,
    [string]$HelperPath
)
$ErrorActionPreference = 'Stop'
if (-not $HelperPath) { $HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'windows_packaging.ps1' }
. $HelperPath

$script:failures = 0
function Assert-Equal {
    param([string]$Name, $Expected, $Actual)
    if ([string]$Expected -ne [string]$Actual) {
        Write-Output "FAIL $Name expected=[$Expected] actual=[$Actual]"
        $script:failures++
    } else {
        Write-Output "ok $Name"
    }
}
function Assert-True {
    param([string]$Name, [bool]$Condition)
    if (-not $Condition) {
        Write-Output "FAIL $Name"
        $script:failures++
    } else {
        Write-Output "ok $Name"
    }
}
function Assert-Throws {
    param([string]$Name, [scriptblock]$Block, [string]$Pattern)
    try {
        & $Block
        Write-Output "FAIL $Name expected an exception"
        $script:failures++
    } catch {
        if ($Pattern -and $_.Exception.Message -notmatch $Pattern) {
            Write-Output "FAIL $Name wrong message: $($_.Exception.Message)"
            $script:failures++
        } else {
            Write-Output "ok $Name"
        }
    }
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('valhalla-packaging-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
try {
    $pubspec = Join-Path $root 'pubspec.yaml'
    Set-Content -LiteralPath $pubspec -Value "name: valhalla`nversion: 1.0.25+26`n" -Encoding ASCII

    $v = Get-ValhallaWindowsVersionInfo -Project $root
    Assert-Equal 'version from pubspec' '1.0.25' $v.Version
    Assert-Equal 'build from pubspec' '26' $v.Build
    Assert-Equal 'full version' '1.0.25+26' $v.Full
    Assert-Equal 'msix version' '1.0.25.0' $v.Msix
    Assert-Equal 'version info' '1.0.25.26' $v.VersionInfo

    $names = Get-ValhallaWindowsArtifactNames -VersionInfo $v
    Assert-Equal 'setup base name' 'valhalla-1.0.25-windows-x64-setup' $names.SetupBase
    Assert-Equal 'setup exe name' 'valhalla-1.0.25-windows-x64-setup.exe' $names.SetupExe
    Assert-Equal 'portable zip name' 'valhalla-v1.0.25-windows-x64.zip' $names.PortableZip
    Assert-Equal 'store msix name' 'valhalla-1.0.25.0-windows-x64-store.msix' $names.StoreMsix
    Assert-Equal 'manifest name' 'store-AppxManifest.xml' $names.Manifest

    $short = Get-ValhallaWindowsVersionInfo -Project $root -Version '1.0.25'
    Assert-Equal 'short version keeps pubspec build' '1.0.25+26' $short.Full
    $full = Get-ValhallaWindowsVersionInfo -Project $root -Version '1.0.25+26'
    Assert-Equal 'explicit full version accepted' '1.0.25+26' $full.Full
    Assert-Throws 'explicit version must match pubspec' { Get-ValhallaWindowsVersionInfo -Project $root -Version '1.0.24+25' } 'does not match'
    Assert-Throws 'explicit build must match pubspec' { Get-ValhallaWindowsVersionInfo -Project $root -Version '1.0.25+25' } 'does not match'
    Assert-Throws 'malformed version rejected' { Get-ValhallaWindowsVersionInfo -Project $root -Version '1.0' } 'Invalid version'
    Assert-Throws 'zero build rejected' { Get-ValhallaWindowsVersionInfo -Project $root -Version '1.0.25+0' } 'does not match|between 1 and 65535'

    $bad = Join-Path $root 'bad'
    New-Item -ItemType Directory -Path $bad | Out-Null
    Set-Content -LiteralPath (Join-Path $bad 'pubspec.yaml') -Value "version: 1.0.25`n" -Encoding ASCII
    Assert-Throws 'pubspec without build rejected' { Get-ValhallaWindowsVersionInfo -Project $bad } 'stable semantic version'
    Assert-Throws 'missing pubspec and missing version rejected' { Get-ValhallaWindowsVersionInfo -Project (Join-Path $root 'missing') } 'does not contain'

    if (-not $Repo) { $Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    $identity = Get-ValhallaWindowsStoreIdentity -Project $Repo
    Assert-Equal 'store name' 'Norns.Valhalla-' $identity.Name
    Assert-Equal 'store publisher' 'CN=257586C2-E7B0-47F3-BAED-A744A66748A1' $identity.Publisher
    Assert-Equal 'store publisher display name' 'Norns' $identity.PublisherDisplayName
    $expectedDisplayName = 'Valhalla-' + [char]0x670D + [char]0x52A1 + [char]0x5668 + [char]0x8FD0 + [char]0x7EF4 + [char]0x7BA1 + [char]0x7406 + [char]0x5DE5 + [char]0x5177
    Assert-Equal 'store display name' $expectedDisplayName $identity.DisplayName

    $manifest = New-ValhallaWindowsMsixManifest -Identity $identity -VersionInfo $v
    $doc = New-Object System.Xml.XmlDocument
    $doc.LoadXml($manifest)
    $identityNode = $doc.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
    Assert-Equal 'manifest identity name' 'Norns.Valhalla-' $identityNode.GetAttribute('Name')
    Assert-Equal 'manifest publisher' 'CN=257586C2-E7B0-47F3-BAED-A744A66748A1' $identityNode.GetAttribute('Publisher')
    Assert-Equal 'manifest version' '1.0.25.0' $identityNode.GetAttribute('Version')
    Assert-Equal 'manifest architecture' 'x64' $identityNode.GetAttribute('ProcessorArchitecture')
    $properties = $doc.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Properties']")
    Assert-Equal 'manifest display name' $expectedDisplayName $properties.SelectSingleNode("*[local-name()='DisplayName']").InnerText
    Assert-Equal 'manifest publisher display name' 'Norns' $properties.SelectSingleNode("*[local-name()='PublisherDisplayName']").InnerText
    $application = $doc.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Applications']/*[local-name()='Application']")
    Assert-Equal 'manifest executable' 'valhalla.exe' $application.GetAttribute('Executable')
    Assert-Equal 'manifest entry point' 'Windows.FullTrustApplication' $application.GetAttribute('EntryPoint')
    $capability = $doc.SelectSingleNode("//*[local-name()='Capability']")
    Assert-Equal 'manifest capability' 'runFullTrust' $capability.GetAttribute('Name')

    $bundle = Join-Path $root 'bundle'
    New-Item -ItemType Directory -Path $bundle | Out-Null
    $empty = Get-ValhallaWindowsPayloadStatus -Bundle $bundle
    Assert-True 'empty bundle reports missing files' ($empty.Missing.Count -eq $empty.Required.Count)
    Assert-Equal 'empty bundle reports missing runtime' '3' $empty.MissingRuntime.Count
    foreach ($relative in $empty.Required) {
        $path = Join-Path $bundle $relative
        $parent = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Set-Content -LiteralPath $path -Value 'test' -Encoding ASCII
    }
    $complete = Get-ValhallaWindowsPayloadStatus -Bundle $bundle
    Assert-Equal 'complete payload has no missing files' '0' $complete.Missing.Count
    Assert-Equal 'runtime still reported optional/missing' '3' $complete.MissingRuntime.Count
    foreach ($relative in $complete.Runtime) { Set-Content -LiteralPath (Join-Path $bundle $relative) -Value 'test' -Encoding ASCII }
    $withRuntime = Get-ValhallaWindowsPayloadStatus -Bundle $bundle
    Assert-Equal 'runtime present' '0' $withRuntime.MissingRuntime.Count

    $makeappx = Resolve-ValhallaMakeAppx
    Assert-True 'makeappx discovered on this machine' (Test-Path -LiteralPath $makeappx)
    Assert-Equal 'makeappx leaf name' 'makeappx.exe' (Split-Path -Leaf $makeappx)
    Write-Output "makeappx=$makeappx"
    Assert-Throws 'explicit missing ISCC rejected' { Resolve-ValhallaInnoCompiler -Compiler 'C:\definitely-missing\ISCC.exe' } 'not found'
    try {
        $iscc = Resolve-ValhallaInnoCompiler
        Assert-True 'inno compiler discovered on this machine' (Test-Path -LiteralPath $iscc)
        Write-Output "iscc=$iscc"
    } catch {
        Write-Output "INNO_MISSING $($_.Exception.Message)"
    }
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:failures -gt 0) {
    Write-Output "FAILED $($script:failures) assertion(s)"
    exit 1
}
Write-Output 'ALL WINDOWS PACKAGING TESTS PASSED'
exit 0
