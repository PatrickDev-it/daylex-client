#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef BuildNumber
  #define BuildNumber "1"
#endif
[Setup]
AppId={{CD74AD52-B8F4-43B6-925F-F488B5D6DB24}
AppName=Daylex
AppVersion={#AppVersion}
AppPublisher=Daylex
AppPublisherURL=https://daylex.it
DefaultDirName={localappdata}\Programs\Daylex
DefaultGroupName=Daylex
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\app\dist
OutputBaseFilename=Daylex-Setup-{#AppVersion}-b{#BuildNumber}-windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=paper_agent.exe
RestartApplications=no
UninstallDisplayIcon={app}\paper_agent.exe
[Files]
Source: "..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{autoprograms}\Daylex"; Filename: "{app}\paper_agent.exe"; WorkingDir: "{app}"
[Run]
Filename: "{app}\paper_agent.exe"; Description: "Avvia Daylex"; Flags: nowait postinstall skipifsilent
