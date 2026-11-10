#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#ifndef BundleDir
  #define BundleDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{5A56D4EE-F203-42F0-BD09-507866F2A4BD}
AppName=Audrix
AppVersion={#AppVersion}
AppPublisher=auren0
AppPublisherURL=https://github.com/auren0/Audrix
DefaultDirName={localappdata}\Programs\Audrix
DefaultGroupName=Audrix
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=Audrix-windows-x64-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Audrix.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=no
UsePreviousAppDir=yes
DisableProgramGroupPage=yes

[Files]
Source: "{#BundleDir}\*"; Excludes: "*.zip,*.pdb"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Audrix"; Filename: "{app}\Audrix.exe"

[Run]
Filename: "{app}\Audrix.exe"; Description: "Launch Audrix"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{userappdata}\auren0\Audrix"
Type: filesandordirs; Name: "{localappdata}\auren0\Audrix"
