
#define MyAppName "MIMI.FM"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "MIMI.FM"
#define MyAppExeName "desktop_music_player.exe"

[Setup]
AppId={{B72A8D41-5F62-4E89-9D13-8C6A21F340B1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\MIMI.FM
DefaultGroupName=MIMI.FM
UninstallDisplayIcon={app}\icon.ico
OutputDir=installer_output
OutputBaseFilename=MIMI.FM
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
SetupIconFile=assets\icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "assets\icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\MIMI.FM"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\icon.ico"
Name: "{autodesktop}\MIMI.FM"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\icon.ico"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch MIMI.FM"; Flags: postinstall skipifsilent
