; Compile after building and preparing the complete Windows Release bundle.
; tool/package_windows_exe.ps1 passes these values from pubspec.yaml (or a
; validated -Version), so no release version is hardcoded here.
#ifndef ValhallaAppVersion
  #error ValhallaAppVersion is required; run tool/package_windows_exe.ps1
#endif
#ifndef ValhallaAppBuild
  #define ValhallaAppBuild "0"
#endif
#ifndef ValhallaOutputBaseFilename
  #error ValhallaOutputBaseFilename is required; run tool/package_windows_exe.ps1
#endif

[Setup]
AppId={{B13B0A56-4DB8-4C33-9271-621B05A019D5}
AppName=Valhalla
AppVersion={#ValhallaAppVersion}
AppVerName=Valhalla {#ValhallaAppVersion}
AppPublisher=Norns
AppPublisherURL=https://norns.cc.cd
AppSupportURL=https://norns.cc.cd
AppUpdatesURL=https://norns.cc.cd
VersionInfoVersion={#ValhallaAppVersion}.{#ValhallaAppBuild}
SourceDir=..
DefaultDirName={localappdata}\Programs\Norns\Valhalla
DefaultGroupName=Valhalla
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir=build\windows-artifacts
OutputBaseFilename={#ValhallaOutputBaseFilename}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\valhalla.exe
LicenseFile=LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
UninstallDisplayName=Valhalla

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Valhalla"; Filename: "{app}\valhalla.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Valhalla"; Filename: "{app}\valhalla.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\valhalla.exe"; Description: "{cm:LaunchProgram,Valhalla}"; Flags: nowait postinstall skipifsilent
