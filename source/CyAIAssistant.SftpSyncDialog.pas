unit CyAIAssistant.SftpSyncDialog;

// CyAIAssistant.SftpSyncDialog.pas
//
// UI for configuring and controlling SFTP project sync.
// Settings are persisted in CyAiAssistant.sync in the project folder.

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs,
  ToolsAPI,
  GDIPOBJ, GDIPAPI,
  SSHPascal.Ssh2Client,
  CyAIAssistant.SftpSync;

type
  TSftpSyncDialog = class(TForm)
    // -- Layout ----------------------------------------------------------
    PanelTop: TPanel;
    LabelTitle: TLabel;
    LabelStatus: TLabel;
    PanelBottom: TPanel;
    BtnStartStop: TButton;
    BtnTestConnection: TButton;
    BtnPushAll: TButton;
    BtnPullAll: TButton;
    BtnClose: TButton;
    PageControl: TPageControl;
    // Tab: Connection
    TabConnection: TTabSheet;
    LabelHost: TLabel;
    LabelPort: TLabel;
    LabelUser: TLabel;
    LabelPass: TLabel;
    LabelKeyPath: TLabel;
    LabelKeyNote: TLabel;
    EditHost: TEdit;
    EditPort: TEdit;
    EditUser: TEdit;
    EditPass: TEdit;
    EditKeyPath: TEdit;
    BtnBrowseKey: TButton;
    LabelPubKeyPath: TLabel;
    EditPubKeyPath: TEdit;
    BtnBrowsePubKey: TButton;
    // Tab: Paths
    TabPaths: TTabSheet;
    LabelLocalBase: TLabel;
    LabelRemoteBase: TLabel;
    LabelPathNote: TLabel;
    EditLocalBase: TEdit;
    BtnBrowseLocal: TButton;
    EditRemoteBase: TEdit;
    CheckIncludeSubDirs: TCheckBox;
    CheckAutoDetectProject: TCheckBox;
    // Tab: Options
    TabOptions: TTabSheet;
    LabelInterval: TLabel;
    LabelIntervalNote: TLabel;
    EditInterval: TEdit;
    CheckStartWithProject: TCheckBox;
    CheckBackupEnabled: TCheckBox;
    LabelQuietPeriod: TLabel;
    EditQuietPeriod: TEdit;
    LabelWatchedExts: TLabel;
    LabelWatchedExtsHint: TLabel;
    EditWatchedExts: TEdit;
    // User
    CheckPermUserRead: TCheckBox;
    CheckPermUserWrite: TCheckBox;
    CheckPermUserExec: TCheckBox;
    // Group
    CheckPermGroupRead: TCheckBox;
    CheckPermGroupWrite: TCheckBox;
    CheckPermGroupExec: TCheckBox;
    // Other
    CheckPermOtherRead: TCheckBox;
    CheckPermOtherWrite: TCheckBox;
    CheckPermOtherExec: TCheckBox;
    // Tab: Log
    TabLog: TTabSheet;
    MemoLog: TRichEdit;
    PanelLogBtns: TPanel;
    BtnClearLog: TButton;
    GroupBoxPermissions: TGroupBox;
    PaintBox1: TPaintBox;
    // -- Events ----------------------------------------------------------
    procedure BtnStartStopClick(Sender: TObject);
    procedure BtnTestConnectionClick(Sender: TObject);
    procedure BtnPushAllClick(Sender: TObject);
    procedure BtnPullAllClick(Sender: TObject);
    procedure BtnBrowseKeyClick(Sender: TObject);
    procedure BtnBrowsePubKeyClick(Sender: TObject);
    procedure BtnBrowseLocalClick(Sender: TObject);
    procedure BtnClearLogClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure PaintBox1Paint(Sender: TObject);
  private
    StatusColor: Cardinal;
    procedure UpdateStatusUI;
    procedure LogAppend(const AMsg: string);
    procedure OnSyncLog(const AMsg: string);
    procedure NotifyIDEIfOpen(const ALocalPath: string);
    procedure LoadSettings;
    procedure SaveSettings;
    function GetActiveProjectPath: string;
    function GetConfigFilePath: string;
    function ParseWatchedExts(const AText: string): TArray<string>;
    function GetPermissions: TFilePermissions;
    procedure SetPermissions(APerms: TFilePermissions);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.dfm}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.IOUtils,
  System.IniFiles,
  Vcl.Graphics,
  CyAIAssistant.IDETheme,
  SSHPascal.SftpClient;

const
  CONFIG_FILE = 'CyAiAssistant.sync'; // stored in the active project folder
  CONFIG_SECTION = 'SftpSync';

const
  DEFAULT_PERMISSIONS: TFilePermissions = [fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupWrite, fpGroupExec, fpOtherRead, fpOtherExec];

  // TFilePermissions is a set of 9 values (ordinals 0..8).
  // Delphi stores sets as bit arrays sized to the smallest integer that fits:
  // 9 elements require 2 bytes (Word), not 1 (Byte).
  // We persist as Integer in the registry but only the low 16 bits are used.
function PermsToInt(APerms: TFilePermissions): Integer;
var
  W: Word;
begin
  W := 0;
  Move(APerms, W, SizeOf(TFilePermissions));
  Result := W;
end;

function IntToPerms(AInt: Integer): TFilePermissions;
var
  W: Word;
begin
  Result := [];
  W := Word(AInt);
  Move(W, Result, SizeOf(TFilePermissions));
end;

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------

constructor TSftpSyncDialog.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited Create(AOwner);
  SetPermissions(DEFAULT_PERMISSIONS); // applied before LoadSettings may override
  LoadSettings;

  // Replay buffered log lines from before this dialog was opened
  if GSftpSync.LogBuffer.Count > 0 then
    for i := 0 to GSftpSync.LogBuffer.Count - 1 do
      LogAppend(GSftpSync.LogBuffer[i]);

  GSftpSync.OnLog := OnSyncLog;
  GSftpSync.OnNotifyFile := NotifyIDEIfOpen;
  GSftpSync.OnStop := procedure begin UpdateStatusUI; end;
  UpdateStatusUI;
  ApplyIDETheme(Self);
end;

destructor TSftpSyncDialog.Destroy;
begin
  // Only detach the log callback -- do NOT stop the engine.
  // Sync continues running in the background after the dialog is closed.
  if Assigned(GSftpSync) then
  begin
    GSftpSync.OnLog := nil;
    GSftpSync.OnStop := nil;
    GSftpSync.OnNotifyFile := nil;
  end;
  inherited;
end;

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------

procedure TSftpSyncDialog.UpdateStatusUI;
var
  CanForce: Boolean;
begin
  if GSftpSync.IsRunning then
  begin
    LabelStatus.Caption := 'Active';
    LabelStatus.Font.Color := clLime;
    StatusColor := MakeColor(160, 0, 255, 0);
    PaintBox1.Repaint;
    BtnStartStop.Caption := 'Stop Sync';
    BtnStartStop.Font.Color := clMaroon;
    CanForce := False;
  end
  else
  begin
    LabelStatus.Caption := 'Inactive';
    LabelStatus.Font.Color := clSilver;
    StatusColor := MakeColor(160, 180, 180, 180);
    PaintBox1.Repaint;
    BtnStartStop.Caption := 'Start Sync';
    BtnStartStop.Font.Color := clWindowText;
    CanForce := not GSftpSync.IsBusy;
  end;
  BtnPushAll.Enabled := CanForce;
  BtnPullAll.Enabled := CanForce;
end;

procedure TSftpSyncDialog.LogAppend(const AMsg: string);
const
  // Upload lines
  COLOR_UP   = TColor($0040C040); // green
  // Download lines
  COLOR_DOWN = TColor($00C08020); // blue
  // Failures / errors
  COLOR_ERR  = TColor($002020D0); // red
  // Backup / info
  COLOR_INFO = TColor($0020A0C0); // amber
var
  T: string;
  C: TColor;
  StartPos, EndPos: Integer;
begin
  T := Trim(AMsg);
  if (Pos('[UP]', T) > 0) or (Pos('[PUSH', T) > 0) then
    C := COLOR_UP
  else if (Pos('[DOWN]', T) > 0) or (Pos('[PULL', T) > 0) then
    C := COLOR_DOWN
  else if (Pos('FAILED', T) > 0) or (Pos('error', T) > 0) or
          (Pos('Error', T) > 0) or (Pos('Connect failed', T) > 0) then
    C := COLOR_ERR
  else if (Pos('[BACKUP]', T) > 0) or (Pos('Push All', T) > 0) or
          (Pos('Pull All', T) > 0) then
    C := COLOR_INFO
  else
    C := GetIDEThemeGetColor(MemoLog.Font.Color);

  MemoLog.SelStart  := MaxInt;
  StartPos := MemoLog.SelStart;
  MemoLog.SelLength := 0;
  MemoLog.SelText   := AMsg + #13#10;
  EndPos := MemoLog.SelStart;

  MemoLog.SelStart  := StartPos;
  MemoLog.SelLength := EndPos - StartPos;
  MemoLog.SelAttributes.Name  := MemoLog.Font.Name;
  MemoLog.SelAttributes.Color := C;
  MemoLog.SelLength := 0;
  MemoLog.SelStart  := EndPos;

  SendMessage(MemoLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TSftpSyncDialog.OnSyncLog(const AMsg: string);
begin
  // Always called on the main thread (TThread.Synchronize inside engine)
  LogAppend(AMsg);
end;

procedure TSftpSyncDialog.NotifyIDEIfOpen(const ALocalPath: string);
var
  ModSvc: IOTAModuleServices;
  Module: IOTAModule;
  I: Integer;
  NormTarget: string;
begin
  // Simulate an application deactivate/activate cycle so the Delphi IDE's
  // built-in external-file-change check fires immediately, without waiting
  // for the user to Alt-Tab away and back.  We post both messages so they
  // are processed after this procedure returns (safe from main thread).
  PostMessage(Application.Handle, WM_ACTIVATEAPP, WPARAM(False), GetCurrentThreadId);
  PostMessage(Application.Handle, WM_ACTIVATEAPP, WPARAM(True),  GetCurrentThreadId);

  // If the file is open in the editor, bring it to front so the IDE's
  // reload prompt appears on the right tab.
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
    Exit;
  NormTarget := LowerCase(TPath.GetFullPath(ALocalPath));
  for I := 0 to ModSvc.ModuleCount - 1 do
  begin
    Module := ModSvc.Modules[I];
    if Module = nil then
      Continue;
    if LowerCase(TPath.GetFullPath(Module.FileName)) <> NormTarget then
      Continue;
    try
      if Module.ModuleFileCount > 0 then
        Module.ModuleFileEditors[0].Show;
    except
    end;
    Break;
  end;
end;

function TSftpSyncDialog.GetActiveProjectPath: string;
var
  ModSvc: IOTAModuleServices;
  ProjGroup: IOTAProjectGroup;
  Project: IOTAProject;
  Module: IOTAModule;
  Mod2: IOTAModuleInfo;
  EditSvc: IOTAEditorServices;
  FileName: string;
  i, j, k: Integer;
begin
  Result := '';
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
    Exit;

  // --- Strategy 1: MainProjectGroup.ActiveProject -------------------------
  // IOTAModuleServices.MainProjectGroup returns the top-level project group.
  // ActiveProject within that group is what the IDE considers "current".
  ProjGroup := ModSvc.MainProjectGroup;
  if Assigned(ProjGroup) and Assigned(ProjGroup.ActiveProject) then
  begin
    Result := TPath.GetDirectoryName(ProjGroup.ActiveProject.FileName);
    Exit;
  end;

  // --- Strategy 2: match the open editor file to its owning project -------
  FileName := '';
  if Supports(BorlandIDEServices, IOTAEditorServices, EditSvc) then
    if Assigned(EditSvc.TopBuffer) then
      FileName := EditSvc.TopBuffer.FileName;

  if FileName <> '' then
  begin
    for i := 0 to ModSvc.ModuleCount - 1 do
    begin
      Module := ModSvc.Modules[i];
      if Supports(Module, IOTAProjectGroup, ProjGroup) then
      begin
        for j := 0 to ProjGroup.ProjectCount - 1 do
        begin
          Project := ProjGroup.Projects[j];
          if not Assigned(Project) then
            Continue;
          for k := 0 to Project.GetModuleCount - 1 do
          begin
            Mod2 := Project.GetModule(k);
            if Assigned(Mod2) and SameText(Mod2.FileName, FileName) then
            begin
              Result := TPath.GetDirectoryName(Project.FileName);
              Exit;
            end;
          end;
        end;
      end
      else if Supports(Module, IOTAProject, Project) then
      begin
        for k := 0 to Project.GetModuleCount - 1 do
        begin
          Mod2 := Project.GetModule(k);
          if Assigned(Mod2) and SameText(Mod2.FileName, FileName) then
          begin
            Result := TPath.GetDirectoryName(Project.FileName);
            Exit;
          end;
        end;
      end;
    end;
  end;

  // --- Strategy 3: first IOTAProject found --------------------------------
  for i := 0 to ModSvc.ModuleCount - 1 do
  begin
    Module := ModSvc.Modules[i];
    if Supports(Module, IOTAProject, Project) then
    begin
      Result := TPath.GetDirectoryName(Project.FileName);
      Exit;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Config file  (CyAiAssistant.sync in the project folder)
// ---------------------------------------------------------------------------

function TSftpSyncDialog.ParseWatchedExts(const AText: string): TArray<string>;
var
  Parts: TArray<string>;
  S: string;
  Ext: string;
  List: TList<string>;
begin
  List := TList<string>.Create;
  try
    // Accept space- or comma-separated entries, with or without leading dot
    Parts := AText.Replace(',', ' ').Split([' '], TStringSplitOptions.ExcludeEmpty);
    for S in Parts do
    begin
      Ext := LowerCase(Trim(S));
      if Ext = '' then
        Continue;
      if Ext[1] <> '.' then
        Ext := '.' + Ext;
      List.Add(Ext);
    end;
    if List.Count = 0 then
    begin
      // Fall back to defaults if the field is cleared
      List.Add('.pas');
      List.Add('.dfm');
      List.Add('.dpr');
      List.Add('.dpk');
      List.Add('.dproj');
      List.Add('.res');
      List.Add('.rc');
      List.Add('.txt');
      List.Add('.ini');
      List.Add('.xml');
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TSftpSyncDialog.GetConfigFilePath: string;
var
  ProjectPath: string;
begin
  ProjectPath := GetActiveProjectPath;
  if ProjectPath <> '' then
    Result := TPath.Combine(ProjectPath, CONFIG_FILE)
  else
    Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), CONFIG_FILE);
end;

procedure TSftpSyncDialog.LoadSettings;
var
  Ini: TIniFile;
  Path: string;
begin
  Path := GetConfigFilePath;
  if not TFile.Exists(Path) then
    Exit;
  Ini := TIniFile.Create(Path);
  try
    EditHost.Text := Ini.ReadString(CONFIG_SECTION, 'Host', '');
    EditPort.Text := Ini.ReadString(CONFIG_SECTION, 'Port', '22');
    EditUser.Text := Ini.ReadString(CONFIG_SECTION, 'User', '');
    EditPass.Text := Ini.ReadString(CONFIG_SECTION, 'Pass', '');
    EditKeyPath.Text := Ini.ReadString(CONFIG_SECTION, 'KeyPath', '');
    EditPubKeyPath.Text := Ini.ReadString(CONFIG_SECTION, 'PubKeyPath', '');
    EditLocalBase.Text := Ini.ReadString(CONFIG_SECTION, 'LocalBase', '');
    EditRemoteBase.Text := Ini.ReadString(CONFIG_SECTION, 'RemoteBase', '');
    EditInterval.Text := Ini.ReadString(CONFIG_SECTION, 'Interval', '5');
    CheckIncludeSubDirs.Checked := Ini.ReadBool(CONFIG_SECTION, 'SubDirs', True);
    CheckAutoDetectProject.Checked := Ini.ReadBool(CONFIG_SECTION, 'AutoDetect', True);
    CheckStartWithProject.Checked := Ini.ReadBool(CONFIG_SECTION, 'AutoStart', False);
    CheckBackupEnabled.Checked := Ini.ReadBool(CONFIG_SECTION, 'Backup', True);
    EditQuietPeriod.Text := Ini.ReadString(CONFIG_SECTION, 'QuietPeriod', '60');
    SetPermissions(IntToPerms(Ini.ReadInteger(CONFIG_SECTION, 'Permissions', PermsToInt(DEFAULT_PERMISSIONS))));
    EditWatchedExts.Text := Ini.ReadString(CONFIG_SECTION, 'WatchedExts', '.pas .dfm .dpr .dpk .dproj .res .rc .txt .ini .xml');
  finally
    Ini.Free;
  end;
end;

procedure TSftpSyncDialog.SaveSettings;
var
  Ini: TIniFile;
  Path: string;
begin
  Path := GetConfigFilePath;
  Ini := TIniFile.Create(Path);
  try
    Ini.WriteString(CONFIG_SECTION, 'Host', Trim(EditHost.Text));
    Ini.WriteString(CONFIG_SECTION, 'Port', Trim(EditPort.Text));
    Ini.WriteString(CONFIG_SECTION, 'User', Trim(EditUser.Text));
    Ini.WriteString(CONFIG_SECTION, 'Pass', EditPass.Text);
    Ini.WriteString(CONFIG_SECTION, 'KeyPath', Trim(EditKeyPath.Text));
    Ini.WriteString(CONFIG_SECTION, 'PubKeyPath', Trim(EditPubKeyPath.Text));
    Ini.WriteString(CONFIG_SECTION, 'LocalBase', Trim(EditLocalBase.Text));
    Ini.WriteString(CONFIG_SECTION, 'RemoteBase', Trim(EditRemoteBase.Text));
    Ini.WriteString(CONFIG_SECTION, 'Interval', Trim(EditInterval.Text));
    Ini.WriteBool(CONFIG_SECTION, 'SubDirs', CheckIncludeSubDirs.Checked);
    Ini.WriteBool(CONFIG_SECTION, 'AutoDetect', CheckAutoDetectProject.Checked);
    Ini.WriteBool(CONFIG_SECTION, 'AutoStart', CheckStartWithProject.Checked);
    Ini.WriteBool(CONFIG_SECTION, 'Backup', CheckBackupEnabled.Checked);
    Ini.WriteString(CONFIG_SECTION, 'QuietPeriod', Trim(EditQuietPeriod.Text));
    Ini.WriteInteger(CONFIG_SECTION, 'Permissions', PermsToInt(GetPermissions));
    Ini.WriteString(CONFIG_SECTION, 'WatchedExts', Trim(EditWatchedExts.Text));
  finally
    Ini.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Start / Stop
// ---------------------------------------------------------------------------

procedure TSftpSyncDialog.BtnStartStopClick(Sender: TObject);
var
  LocalBase: string;
  Port: Word;
  Interval: Integer;
  FolderName: string;
  RemBase: string;
  RemotePath: string;
begin
  if GSftpSync.IsRunning then
  begin
    GSftpSync.SaveCacheTo(GetConfigFilePath); // persist cache before stopping
    GSftpSync.Stop;
    SaveSettings;
    UpdateStatusUI;
    Exit;
  end;

  // -- Validate ------------------------------------------------------------

  if Trim(EditHost.Text) = '' then
  begin
    ShowMessage('Please enter an SFTP host or IP address.');
    PageControl.ActivePage := TabConnection;
    EditHost.SetFocus;
    Exit;
  end;

  if Trim(EditUser.Text) = '' then
  begin
    ShowMessage('Please enter a username.');
    PageControl.ActivePage := TabConnection;
    EditUser.SetFocus;
    Exit;
  end;

  if (Trim(EditPass.Text) = '') and (Trim(EditKeyPath.Text) = '') then
  begin
    ShowMessage('Please enter a password or select a private key file.');
    PageControl.ActivePage := TabConnection;
    EditPass.SetFocus;
    Exit;
  end;

  Port := Word(StrToIntDef(EditPort.Text, 22));

  // Auto-detect local folder from active IDE project if requested
  LocalBase := Trim(EditLocalBase.Text);
  if (LocalBase = '') and CheckAutoDetectProject.Checked then
    LocalBase := GetActiveProjectPath;

  if LocalBase = '' then
  begin
    ShowMessage('Could not determine the local project folder.' + sLineBreak + 'Please enter it manually on the Paths tab, or open a project first.');
    PageControl.ActivePage := TabPaths;
    EditLocalBase.SetFocus;
    Exit;
  end;

  if not TDirectory.Exists(LocalBase) then
  begin
    ShowMessage('Local project folder not found:' + sLineBreak + LocalBase);
    PageControl.ActivePage := TabPaths;
    EditLocalBase.SetFocus;
    Exit;
  end;

  // Default remote base to /
  if Trim(EditRemoteBase.Text) = '' then
    EditRemoteBase.Text := '/';

  // When auto-detecting the local folder, mirror its name on the remote side.
  // E.g. local = C:\Projects\MyApp  remote base /  ->  /MyApp
  // local = C:\Projects\MyApp  remote base /var/www  ->  /var/www/MyApp
  if CheckAutoDetectProject.Checked then
  begin
    FolderName := TPath.GetFileName(ExcludeTrailingPathDelimiter(LocalBase));
    if FolderName <> '' then
    begin
      RemBase := Trim(EditRemoteBase.Text);
      // Strip trailing slash (but keep bare /)
      while (Length(RemBase) > 1) and (RemBase[Length(RemBase)] = '/') do
        RemBase := Copy(RemBase, 1, Length(RemBase) - 1);
      // Only append if the base does not already end with the folder name
      if not SameText(TPath.GetFileName(RemBase), FolderName) then
        RemBase := RemBase + '/' + FolderName;
      EditRemoteBase.Text := RemBase;
      EditLocalBase.Text := LocalBase; // show resolved path in the field
    end;
  end;

  // -- Sanitise remote base path ---------------------------------------------
  // Backslashes -> forward slashes
  // Collapse any run of // down to a single /
  // Always ensure it starts with exactly one /
  // Strip trailing slash unless the path is bare /
  RemotePath := StringReplace(Trim(EditRemoteBase.Text), '\', '/', [rfReplaceAll]);
  while Pos('//', RemotePath) > 0 do
    RemotePath := StringReplace(RemotePath, '//', '/', [rfReplaceAll]);
  if (RemotePath = '') or (RemotePath[1] <> '/') then
    RemotePath := '/' + RemotePath;
  while (Length(RemotePath) > 1) and (RemotePath[Length(RemotePath)] = '/') do
    RemotePath := Copy(RemotePath, 1, Length(RemotePath) - 1);
  EditRemoteBase.Text := RemotePath;
  // -------------------------------------------------------------------------

  Interval := StrToIntDef(EditInterval.Text, 5);

  SaveSettings;

  // -- Start ------------------------------------------------------------------
  // Restore timestamp cache so first cycle skips already-synced files.
  GSftpSync.LoadCacheFrom(GetConfigFilePath);

  GSftpSync.BackupEnabled := CheckBackupEnabled.Checked;
  GSftpSync.RemoteQuietPeriodSecs := StrToIntDef(EditQuietPeriod.Text, 60);
  GSftpSync.Start(Trim(EditHost.Text), Port, Trim(EditUser.Text), EditPass.Text, Trim(EditKeyPath.Text), Trim(EditPubKeyPath.Text), EditRemoteBase.Text,
    LocalBase, CheckIncludeSubDirs.Checked, Interval, GetPermissions, ParseWatchedExts(EditWatchedExts.Text));

  UpdateStatusUI;
  PageControl.ActivePage := TabLog;
end;

// ---------------------------------------------------------------------------
// Push All / Pull All
// ---------------------------------------------------------------------------

procedure TSftpSyncDialog.BtnPushAllClick(Sender: TObject);
var
  LocalBase: string;
  Port: Word;
  RemotePath: string;
begin
  if MessageDlg('Push All will overwrite ALL files on the remote server with your local versions.' + sLineBreak + sLineBreak + 'Continue?', mtWarning,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;

  LocalBase := Trim(EditLocalBase.Text);
  if (LocalBase = '') and CheckAutoDetectProject.Checked then
    LocalBase := GetActiveProjectPath;
  if (LocalBase = '') or not TDirectory.Exists(LocalBase) then
  begin
    ShowMessage('Local project folder not found. Check the Paths tab.');
    Exit;
  end;

  Port := Word(StrToIntDef(EditPort.Text, 22));
  RemotePath := Trim(EditRemoteBase.Text);
  if RemotePath = '' then
    RemotePath := '/';

  SaveSettings;
  GSftpSync.BackupEnabled := CheckBackupEnabled.Checked;
  GSftpSync.RemoteQuietPeriodSecs := StrToIntDef(EditQuietPeriod.Text, 60);
  GSftpSync.Configure(Trim(EditHost.Text), Port, Trim(EditUser.Text), EditPass.Text, Trim(EditKeyPath.Text), Trim(EditPubKeyPath.Text), RemotePath, LocalBase,
    CheckIncludeSubDirs.Checked, GetPermissions, ParseWatchedExts(EditWatchedExts.Text));

  BtnPushAll.Enabled := False;
  BtnPullAll.Enabled := False;
  PageControl.ActivePage := TabLog;
  GSftpSync.ForcePushAll(
    procedure
    begin
      UpdateStatusUI;
    end);
end;

procedure TSftpSyncDialog.BtnPullAllClick(Sender: TObject);
var
  LocalBase: string;
  Port: Word;
  RemotePath: string;
begin
  if MessageDlg('Pull All will overwrite ALL local files with the remote versions.' + sLineBreak + 'Local changes not yet pushed will be lost.' + sLineBreak +
    sLineBreak + 'Continue?', mtWarning, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  LocalBase := Trim(EditLocalBase.Text);
  if (LocalBase = '') and CheckAutoDetectProject.Checked then
    LocalBase := GetActiveProjectPath;
  if (LocalBase = '') or not TDirectory.Exists(LocalBase) then
  begin
    ShowMessage('Local project folder not found. Check the Paths tab.');
    Exit;
  end;

  Port := Word(StrToIntDef(EditPort.Text, 22));
  RemotePath := Trim(EditRemoteBase.Text);
  if RemotePath = '' then
    RemotePath := '/';

  SaveSettings;
  GSftpSync.BackupEnabled := CheckBackupEnabled.Checked;
  GSftpSync.RemoteQuietPeriodSecs := StrToIntDef(EditQuietPeriod.Text, 60);
  GSftpSync.Configure(Trim(EditHost.Text), Port, Trim(EditUser.Text), EditPass.Text, Trim(EditKeyPath.Text), Trim(EditPubKeyPath.Text), RemotePath, LocalBase,
    CheckIncludeSubDirs.Checked, GetPermissions, ParseWatchedExts(EditWatchedExts.Text));

  BtnPushAll.Enabled := False;
  BtnPullAll.Enabled := False;
  PageControl.ActivePage := TabLog;
  GSftpSync.ForcePullAll(
    procedure
    begin
      UpdateStatusUI;
    end);
end;

// ---------------------------------------------------------------------------
// Test connection
// ---------------------------------------------------------------------------

procedure TSftpSyncDialog.BtnTestConnectionClick(Sender: TObject);
var
  Session: ISshSession;
  Port: Word;
  AuthOK: Boolean;
begin
  if Trim(EditHost.Text) = '' then
  begin
    ShowMessage('Please enter an SFTP host first.');
    Exit;
  end;

  Port := Word(StrToIntDef(EditPort.Text, 22));
  BtnTestConnection.Enabled := False;
  BtnTestConnection.Caption := 'Connecting...';
  Application.ProcessMessages;
  try
    Session := CreateSession(Trim(EditHost.Text), Port);
    Session.ConfigKnownHostCheckPolicy(False, DefKnownHostCheckPolicy);
    Session.Connect;

    if Trim(EditKeyPath.Text) <> '' then
      AuthOK := Session.UserAuthKey(Trim(EditUser.Text), Trim(EditPubKeyPath.Text), // public key
      Trim(EditKeyPath.Text)) // private key
    else
      AuthOK := Session.UserAuthPass(Trim(EditUser.Text), EditPass.Text);

    Session.Disconnect;
    Session := nil;

    if AuthOK then
      ShowMessage('[OK]  Connection and authentication successful!')
    else
      ShowMessage('[FAILED]  Connected but authentication failed.' + sLineBreak + 'Check username / password / key.');
  except
    on E: Exception do
      ShowMessage('[FAILED]  Connection failed:' + sLineBreak + E.Message);
  end;
  BtnTestConnection.Caption := 'Test Connection';
  BtnTestConnection.Enabled := True;
end;

// ---------------------------------------------------------------------------
// Browse buttons
// ---------------------------------------------------------------------------

procedure TSftpSyncDialog.BtnBrowseKeyClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'Select private key file';
    Dlg.Filter := 'Key files (*.pem;*.ppk;*.key)|*.pem;*.ppk;*.key|All files (*.*)|*.*';
    if Trim(EditKeyPath.Text) <> '' then
      Dlg.InitialDir := TPath.GetDirectoryName(Trim(EditKeyPath.Text));
    if Dlg.Execute then
      EditKeyPath.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TSftpSyncDialog.BtnBrowsePubKeyClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'Select public key file';
    Dlg.Filter := 'Key files (*.pub;*.pem)|*.pub;*.pem|All files (*.*)|*.*';
    if Trim(EditPubKeyPath.Text) <> '' then
      Dlg.InitialDir := TPath.GetDirectoryName(Trim(EditPubKeyPath.Text));
    if Dlg.Execute then
      EditPubKeyPath.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TSftpSyncDialog.BtnBrowseLocalClick(Sender: TObject);
var
  Dlg: TFileOpenDialog;
begin
  Dlg := TFileOpenDialog.Create(nil);
  try
    Dlg.Title := 'Select local project folder';
    Dlg.Options := [fdoPickFolders];
    if Trim(EditLocalBase.Text) <> '' then
      Dlg.DefaultFolder := Trim(EditLocalBase.Text);
    if Dlg.Execute then
      EditLocalBase.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TSftpSyncDialog.BtnClearLogClick(Sender: TObject);
begin
  MemoLog.Clear;
end;

// ---------------------------------------------------------------------------
// Permission helpers
// ---------------------------------------------------------------------------

function TSftpSyncDialog.GetPermissions: TFilePermissions;
begin
  Result := [];
  if CheckPermUserRead.Checked then
    Include(Result, fpUserRead);
  if CheckPermUserWrite.Checked then
    Include(Result, fpUserWrite);
  if CheckPermUserExec.Checked then
    Include(Result, fpUserExec);
  if CheckPermGroupRead.Checked then
    Include(Result, fpGroupRead);
  if CheckPermGroupWrite.Checked then
    Include(Result, fpGroupWrite);
  if CheckPermGroupExec.Checked then
    Include(Result, fpGroupExec);
  if CheckPermOtherRead.Checked then
    Include(Result, fpOtherRead);
  if CheckPermOtherWrite.Checked then
    Include(Result, fpOtherWrite);
  if CheckPermOtherExec.Checked then
    Include(Result, fpOtherExec);
end;

procedure TSftpSyncDialog.SetPermissions(APerms: TFilePermissions);
begin
  CheckPermUserRead.Checked := fpUserRead in APerms;
  CheckPermUserWrite.Checked := fpUserWrite in APerms;
  CheckPermUserExec.Checked := fpUserExec in APerms;
  CheckPermGroupRead.Checked := fpGroupRead in APerms;
  CheckPermGroupWrite.Checked := fpGroupWrite in APerms;
  CheckPermGroupExec.Checked := fpGroupExec in APerms;
  CheckPermOtherRead.Checked := fpOtherRead in APerms;
  CheckPermOtherWrite.Checked := fpOtherWrite in APerms;
  CheckPermOtherExec.Checked := fpOtherExec in APerms;
end;

procedure TSftpSyncDialog.BtnCloseClick(Sender: TObject);
begin
  Close; // triggers FormClose -> caFree; sync keeps running
end;

procedure TSftpSyncDialog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Detach callbacks -- engine keeps running in background
  if Assigned(GSftpSync) then
  begin
    GSftpSync.OnLog := nil;
    GSftpSync.OnStop := nil;
    GSftpSync.OnNotifyFile := nil;
  end;
  Action := caFree; // free the form instance on close
end;

procedure TSftpSyncDialog.PaintBox1Paint(Sender: TObject);
var
   g: TGPGraphics;
   GPBrush: TGPBrush;
begin
   g := TGPGraphics.Create(PaintBox1.Canvas.Handle);
   try
     g.SetSmoothingMode(SmoothingModeAntiAlias);
     GPBrush := TGPSolidBrush.Create(StatusColor);
     try
       g.FillPie(GPBrush, MakeRect(1,1, PaintBox1.Width-2, PaintBox1.Height-2), 0, 360);
     finally
       GPBrush.Free;
     end;
   finally
     g.Free;
   end;
end;

end.
