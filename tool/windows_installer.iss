; Compile after building and preparing the complete Windows Release bundle.
[Setup]
AppId={{B13B0A56-4DB8-4C33-9271-621B05A019D5}
AppName=Valhalla
AppVersion=1.0.2
AppVerName=Valhalla 1.0.2
AppPublisher=Norns
AppPublisherURL=https://norns.cc.cd
AppSupportURL=https://norns.cc.cd
AppUpdatesURL=https://norns.cc.cd
VersionInfoVersion=1.0.2.3
SourceDir=..
DefaultDirName={localappdata}\Programs\Norns\Valhalla
DefaultGroupName=Valhalla
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir=build\windows-artifacts
OutputBaseFilename=valhalla-1.0.2-windows-x64-setup
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
