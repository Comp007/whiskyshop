; Script pour Inno Setup - Whiskyshop App

[Setup]
AppName=WhiskyShop App
AppVersion=1.0
AppPublisher=SiSoTech
DefaultDirName={autopf}\WhiskyShop App
DefaultGroupName=WhiskyShop App
OutputBaseFilename=whiskyshop-app-setup-v1.0
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
; 1. Fichiers de votre application Flutter
Source: "C:\Users\carlo\Desktop\whiskyshop_app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "C:\Users\carlo\Desktop\whiskyshop_app\installer\whiskyshop_icon.ico"; DestDir: "{app}"; Flags: ignoreversion


; 2. Dépendances C++ (TRÈS IMPORTANT)
; VÉRIFIEZ CE CHEMIN sur votre PC. Il peut varier.
; Cherchez ces fichiers dans le dossier d'installation de Visual Studio Build Tools.
Source: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.44.35112\x64\Microsoft.VC143.CRT\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\WhiskyShop App"; Filename: "{app}\whiskyshop_app.exe"; IconFilename: "{app}\whiskyshop_icon.ico"
Name: "{commondesktop}\WhiskyShop App"; Filename: "{app}\whiskyshop_app.exe"; IconFilename: "{app}\whiskyshop_icon.ico"; Tasks: desktopicon


[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}";

[Run]
Filename: "{app}\whiskyshop_app.exe"; Description: "{cm:LaunchProgram,WhiskyShop App}"; Flags: nowait postinstall skipifsilent
