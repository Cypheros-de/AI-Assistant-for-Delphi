unit CyAIAssistant.SftpSync;

{
  CyAIAssistant.SftpSync.pas

  Bidirectional SFTP sync engine for the Cypheros AI Assistant IDE plugin.

  Architecture
  ------------
  One background TTask runs on a timer (interval seconds).  Each cycle:

  1.  Collect local file list
  Walk FLocalBasePath recursively (if configured), collect all files
  matching watched extensions with their path, size and last-write time.

  2.  Connect to SFTP server
  CreateSession / UserAuth / CreateSftpClient.

  3.  Ensure remote base directory exists (ForceDirectories).

  4.  Collect remote file list
  Walk FRemoteBasePath via ISftpClient.DirContent, same extensions.

  5.  Compare and sync
  For each file present on BOTH sides: copy the newer version to the
  other side (1-second tolerance to avoid oscillation).
  For files present only locally: upload.
  For files present only remotely: download.

  6.  Disconnect.

  Local-change watcher (FindFirstChangeNotification) triggers an immediate
  extra sync cycle whenever any file in the project folder changes, so edits
  are synced within ~500 ms rather than waiting for the next timer tick.

  SSH-Pascal API  (Ssh2Client.pas / SftpClient.pas)
  -------------------------------------------------
  CreateSession(Host, Port)  : ISshSession
  .SetTimeout(ms)
  .ConfigKnownHostCheckPolicy(Enable, Policy)
  .Connect
  .UserAuthPass(User, Pass) : Boolean
  .UserAuthKey(User, PubKey, PrivKey) : Boolean
  .Disconnect

  CreateSftpClient(Session)  : ISftpClient
  .DirectoryExists(Dir)    : Boolean
  .ForceDirectories(Dir)   : Boolean
  .CreateDir(Dir, Permissions) : Boolean
  .DirContent(Dir)         : TSftpItems   (TSftpItem.FileName, .FileSize,
  .LastModificationTime, .ItemType)
  .ExtractFilePath(Path)   : string
  .Send(Local, Remote, Overwrite, Permissions)
  .Receive(Remote, Local, Overwrite)
}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.Threading, System.DateUtils,
  Winapi.Windows,
  Vcl.ExtCtrls,
  ToolsAPI,
  SSHPascal.Ssh2Client,
  SSHPascal.SftpClient;

type
  TSftpLogEvent = reference to procedure(const AMsg: string);

  { One entry in a file list }
  TSyncFileInfo = record
    RelPath: string; // path relative to base, forward slashes
    Size: Int64;
    MTime: TDateTime; // UTC on remote, local on local side
  end;

  TSftpSyncEngine = class
  private
    // -- Connection params --------------------------------------------------
    FHost: string;
    FPort: Word;
    FUserName: string;
    FPassword: string;
    FPrivateKeyPath: string;
    FPublicKeyPath: string;
    FRemoteBasePath: string;
    FLocalBasePath: string;
    FIncludeSubDirs: Boolean;
    FPermissions: TFilePermissions;
    FDirPermissions: TFilePermissions; // derived: exec bits added for traversal
    FIntervalMs: Integer;
    FWatchedExts: TArray<string>; // lower-case extensions e.g. ['.pas','.dfm']

    // -- Sync state ---------------------------------------------------------
    FSyncTimer: TTimer;
    FSyncBusy: Boolean;

    // -- Local file watcher -------------------------------------------------
    FWatchThread: TThread;
    FStopEvent: THandle;
    FImmediateSync: THandle; // signalled by watcher -> trigger extra cycle

    // -- Log ----------------------------------------------------------------
    FOnLog: TSftpLogEvent;
    FLogBuffer: TStringList;
    // Per-file cache of the last timestamp seen on BOTH sides after a sync.
    // Prevents re-syncing files that were just synced in the previous cycle.
    FLastSyncedMTime: TDictionary<string, TDateTime>;

    procedure Log(const AMsg: string);
    procedure OnSyncTimer(Sender: TObject);
    procedure DoSyncCycle;
    function ConnectSftp(out Session: ISshSession; out Sftp: ISftpClient): Boolean;
    procedure CollectLocalFiles(AList: TList<TSyncFileInfo>);
    procedure CollectRemoteFiles(Sftp: ISftpClient; const ARemoteDir: string; AList: TList<TSyncFileInfo>; ARecurse: Boolean);
    procedure SyncLists(Sftp: ISftpClient; Local, Remote: TList<TSyncFileInfo>);
    procedure UploadFile(const ARelPath: string; Sftp: ISftpClient);
    procedure DownloadFile(const ARelPath: string; Sftp: ISftpClient);
    procedure EnsureRemoteDir(const ARemoteDir: string; Sftp: ISftpClient);
    procedure NotifyIDEIfOpen(const ALocalPath: string);
    procedure StartWatchThread;
    procedure StopWatchThread;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Start(const AHost: string; APort: Word; const AUserName, APassword: string; const APrivateKeyPath, APublicKeyPath: string;
      const ARemoteBasePath, ALocalBasePath: string; AIncludeSubDirs: Boolean; AIntervalSeconds: Integer; APermissions: TFilePermissions;
      const AWatchedExts: TArray<string>);
    procedure Stop;
    function IsRunning: Boolean;

    // Cache persistence -- call from dialog's SaveSettings / LoadSettings
    procedure SaveCacheTo(const AFilePath: string);
    procedure LoadCacheFrom(const AFilePath: string);

    property LogBuffer: TStringList read FLogBuffer;
    property OnLog: TSftpLogEvent read FOnLog write FOnLog;
  end;

var
  GSftpSync: TSftpSyncEngine;

implementation

uses
  System.IOUtils,
  System.IniFiles,
  System.Math,
  System.StrUtils,
  System.Types,
  Vcl.Dialogs,
  Vcl.Forms;

{ ===========================================================================
  TMainThreadRunner
  =========================================================================== }

type
  TMainThreadRunner = class
  private
    FProc: TProc;
    procedure Run;
  public
    class procedure Queue(const AProc: TProc);
  end;

procedure TMainThreadRunner.Run;
begin
  try
    FProc;
  finally
    Free;
  end;
end;

class procedure TMainThreadRunner.Queue(const AProc: TProc);
var
  Runner: TMainThreadRunner;
begin
  Runner := TMainThreadRunner.Create;
  Runner.FProc := AProc;
  TThread.Queue(nil, Runner.Run);
end;

{ ===========================================================================
  TWatcherThread
  Fires FImmediateSync event when any project file changes locally.
  =========================================================================== }

type
  TWatcherThread = class(TThread)
  private
    FRootPath: string;
    FIncludeSubDirs: Boolean;
    FStopEvent: THandle;
    FImmediateSync: THandle;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARootPath: string; AIncludeSubDirs: Boolean; AStopEvent, AImmediateSync: THandle);
  end;

constructor TWatcherThread.Create(const ARootPath: string; AIncludeSubDirs: Boolean; AStopEvent, AImmediateSync: THandle);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FRootPath := ARootPath;
  FIncludeSubDirs := AIncludeSubDirs;
  FStopEvent := AStopEvent;
  FImmediateSync := AImmediateSync;
end;

procedure TWatcherThread.Execute;
const
  NOTIFY_FILTER = FILE_NOTIFY_CHANGE_LAST_WRITE or FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_SIZE;
var
  hChange: THandle;
  Handles: array [0 .. 1] of THandle;
  WaitRes: DWORD;
begin
  hChange := FindFirstChangeNotification(PChar(FRootPath), FIncludeSubDirs, NOTIFY_FILTER);
  if hChange = INVALID_HANDLE_VALUE then
    Exit;

  Handles[0] := hChange;
  Handles[1] := FStopEvent;
  try
    while not Terminated do
    begin
      WaitRes := WaitForMultipleObjects(2, @Handles[0], False, INFINITE);
      if (WaitRes = WAIT_OBJECT_0 + 1) or Terminated then
        Break;
      if WaitRes = WAIT_OBJECT_0 then
      begin
        Sleep(500); // let the write settle
        SetEvent(FImmediateSync);
        FindNextChangeNotification(hChange);
      end;
    end;
  finally
    FindCloseChangeNotification(hChange);
  end;
end;

{ ===========================================================================
  TSftpSyncEngine
  =========================================================================== }

constructor TSftpSyncEngine.Create;
begin
  inherited;
  FLogBuffer := TStringList.Create;
  FLastSyncedMTime := TDictionary<string, TDateTime>.Create;
  FStopEvent := CreateEvent(nil, True, False, nil);
  FImmediateSync := CreateEvent(nil, False, False, nil);

  FSyncTimer := TTimer.Create(nil);
  FSyncTimer.Enabled := False;
  FSyncTimer.OnTimer := OnSyncTimer;
end;

destructor TSftpSyncEngine.Destroy;
begin
  Stop;
  FSyncTimer.Free;
  CloseHandle(FImmediateSync);
  CloseHandle(FStopEvent);
  FLastSyncedMTime.Free;
  FLogBuffer.Free;
  inherited;
end;

function TSftpSyncEngine.IsRunning: Boolean;
begin
  Result := FSyncTimer.Enabled;
end;

procedure TSftpSyncEngine.Log(const AMsg: string);
var
  Line: string;
  Callback: TSftpLogEvent;
begin
  Line := '[' + FormatDateTime('hh:nn:ss', Now) + '] ' + AMsg;
  FLogBuffer.Add(Line);
  while FLogBuffer.Count > 500 do
    FLogBuffer.Delete(0);
  if Assigned(FOnLog) then
  begin
    Callback := FOnLog;
    TMainThreadRunner.Queue(
      procedure
      begin
        if Assigned(Callback) then
          Callback(Line);
      end);
  end;
end;

{ ---------------------------------------------------------------------------
  Start / Stop
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.Start(const AHost: string; APort: Word; const AUserName, APassword: string; const APrivateKeyPath, APublicKeyPath: string;
const ARemoteBasePath, ALocalBasePath: string; AIncludeSubDirs: Boolean; AIntervalSeconds: Integer; APermissions: TFilePermissions;
const AWatchedExts: TArray<string>);
begin
  Stop;

  FHost := AHost;
  FPort := APort;
  FUserName := AUserName;
  FPassword := APassword;
  FPrivateKeyPath := APrivateKeyPath;
  FPublicKeyPath := APublicKeyPath;
  FRemoteBasePath := ARemoteBasePath;
  FLocalBasePath := ExcludeTrailingPathDelimiter(ALocalBasePath);
  FIncludeSubDirs := AIncludeSubDirs;
  FPermissions := APermissions;
  // Derive directory permissions: for each class (user/group/other) that has
  // read or write access, also grant execute (= traversal for directories).
  FDirPermissions := APermissions;
  if (fpUserRead in APermissions) or (fpUserWrite in APermissions) then
    Include(FDirPermissions, fpUserExec);
  if (fpGroupRead in APermissions) or (fpGroupWrite in APermissions) then
    Include(FDirPermissions, fpGroupExec);
  if (fpOtherRead in APermissions) or (fpOtherWrite in APermissions) then
    Include(FDirPermissions, fpOtherExec);
  FIntervalMs := Max(1, AIntervalSeconds) * 1000;
  FWatchedExts := AWatchedExts;
  FSyncBusy := False;
  // FLastSyncedMTime is populated by LoadCacheFrom (called by dialog before
  // Start) -- do NOT clear it here or the restored cache is lost.

  ResetEvent(FStopEvent);
  ResetEvent(FImmediateSync);

  StartWatchThread;

  FSyncTimer.Interval := FIntervalMs;
  FSyncTimer.Enabled := True;

  Log('Sync started  ' + AHost + ':' + IntToStr(APort) + '  remote: ' + ARemoteBasePath + '  local: ' + ALocalBasePath);

  OnSyncTimer(nil);
end;

procedure TSftpSyncEngine.Stop;
begin
  FSyncTimer.Enabled := False;
  StopWatchThread;
  Log('Sync stopped.');
end;

procedure TSftpSyncEngine.StartWatchThread;
begin
  if (FLocalBasePath = '') or not TDirectory.Exists(FLocalBasePath) then
    Exit;
  FWatchThread := TWatcherThread.Create(FLocalBasePath, FIncludeSubDirs, FStopEvent, FImmediateSync);
end;

procedure TSftpSyncEngine.StopWatchThread;
begin
  SetEvent(FStopEvent);
  FWatchThread := nil;
end;

{ ---------------------------------------------------------------------------
  Timer -- checks if an immediate sync was requested, then runs cycle
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.OnSyncTimer(Sender: TObject);
begin
  if FSyncBusy then
    Exit;
  FSyncBusy := True;
  DoSyncCycle;
end;

{ ---------------------------------------------------------------------------
  SFTP connection helper
  --------------------------------------------------------------------------- }

function TSftpSyncEngine.ConnectSftp(out Session: ISshSession; out Sftp: ISftpClient): Boolean;
var
  Attempts: Integer;
begin
  Result := False;
  Session := nil;
  Sftp := nil;
  try
    Session := CreateSession(FHost, FPort);
    Session.ConfigKnownHostCheckPolicy(False, DefKnownHostCheckPolicy);
    Session.Connect;
    Session.SetTimeout(60000);

    if Session.SessionState <> session_Connected then
      raise ESshError.Create('SSH not connected');

    if FPrivateKeyPath <> '' then
    begin
      if not Session.UserAuthKey(FUserName, FPublicKeyPath, FPrivateKeyPath) then
        raise ESshError.Create('Key auth failed');
    end
    else
    begin
      if not Session.UserAuthPass(FUserName, FPassword) then
        raise ESshError.Create('Password auth failed');
    end;

    if Session.SessionState <> session_Authorized then
      raise ESshError.Create('SSH not authorized');

    Attempts := 0;
    repeat
      try
        Sftp := CreateSftpClient(Session);
      except
        Sftp := nil;
      end;
      if Assigned(Sftp) then
        Break;
      Inc(Attempts);
      if Attempts < 3 then
        Sleep(500);
    until Attempts >= 3;

    if not Assigned(Sftp) then
      raise ESshError.Create('SFTP subsystem unavailable after 3 attempts');

    Result := True;
  except
    on E: Exception do
    begin
      Log('Connect failed: ' + E.Message);
      try
        if Assigned(Session) then
          Session.Disconnect;
      except
      end;
      Session := nil;
      Sftp := nil;
    end;
  end;
end;

{ ---------------------------------------------------------------------------
  Collect local file list
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.CollectLocalFiles(AList: TList<TSyncFileInfo>);
var
  Files: TStringDynArray;
  F: string;
  Info: TSyncFileInfo;
  Rel: string;
  Ext: string;
  W: string;
  Match: Boolean;

  function GetFileSize(aFilename: String): Int64;
  var
    SR: TSearchRec;
  begin
    if FindFirst(aFilename, faAnyFile, SR) = 0 then
    begin
      Result := Int64(SR.FindData.nFileSizeHigh) shl 32 or Int64(SR.FindData.nFileSizeLow);
      System.SysUtils.FindClose(SR);
    end
    else
      Result := 0;
  end;

begin
  if FIncludeSubDirs then
    Files := TDirectory.GetFiles(FLocalBasePath, '*.*', TSearchOption.soAllDirectories)
  else
    Files := TDirectory.GetFiles(FLocalBasePath, '*.*', TSearchOption.soTopDirectoryOnly);

  for F in Files do
  begin
    Ext := LowerCase(TPath.GetExtension(F));
    Match := False;
    for W in FWatchedExts do
      if Ext = W then
      begin
        Match := True;
        Break;
      end;
    if not Match then
      Continue;

    // Build relative path with forward slashes
    if StartsText(FLocalBasePath + PathDelim, F) then
      Rel := Copy(F, Length(FLocalBasePath) + 2, MaxInt)
    else
      Rel := TPath.GetFileName(F);
    Rel := StringReplace(Rel, '\', '/', [rfReplaceAll]);

    Info.RelPath := Rel;
    Info.Size := GetFileSize(F); // Delphi 10 compatible //TFile.GetSize(F);
    Info.MTime := TFile.GetLastWriteTime(F); // local time
    AList.Add(Info);
  end;
end;

{ ---------------------------------------------------------------------------
  Collect remote file list
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.CollectRemoteFiles(Sftp: ISftpClient; const ARemoteDir: string; AList: TList<TSyncFileInfo>; ARecurse: Boolean);
var
  Items: TSftpItems;
  Item: TSftpItem;
  Info: TSyncFileInfo;
  Ext: string;
  W: string;
  Match: Boolean;
  Sub: string;
  // Strip remote base to produce a RelPath consistent with local side
  BaseLen: Integer;
begin
  BaseLen := Length(FRemoteBasePath);
  // Ensure no trailing slash in base for consistent stripping
  while (BaseLen > 1) and (FRemoteBasePath[BaseLen] = '/') do
    Dec(BaseLen);

  try
    Items := Sftp.DirContent(ARemoteDir);
  except
    Exit;
  end;

  for Item in Items do
  begin
    if (Item.FileName = '.') or (Item.FileName = '..') then
      Continue;

    Sub := ARemoteDir + '/' + Item.FileName;

    if Item.ItemType = sitDirectory then
    begin
      if ARecurse then
        CollectRemoteFiles(Sftp, Sub, AList, True);
      Continue;
    end;

    if not(Item.ItemType in [sitFile, sitUnknown]) then
      Continue;

    Ext := LowerCase(TPath.GetExtension(Item.FileName));
    Match := False;
    for W in FWatchedExts do
      if Ext = W then
      begin
        Match := True;
        Break;
      end;
    if not Match then
      Continue;

    // Build relative path: strip remote base prefix
    var
    FullRemote := Sub;
    var
      Rel: string;
    if (Length(FullRemote) > BaseLen) and (Copy(FullRemote, 1, BaseLen) = Copy(FRemoteBasePath, 1, BaseLen)) then
    begin
      Rel := Copy(FullRemote, BaseLen + 2, MaxInt); // +2 skips the /
    end
    else
      Rel := Item.FileName;

    Info.RelPath := Rel;
    Info.Size := Item.FileSize;
    Info.MTime := Item.LastModificationTime; // UTC from server
    AList.Add(Info);
  end;
end;

{ ---------------------------------------------------------------------------
  EnsureRemoteDir
  Creates each missing segment of ARemoteDir with FDirPermissions.
  SSH-Pascal's ForceDirectories ignores permissions; we walk the path
  manually and call CreateDir on each segment so the server receives
  the correct mode for every new directory.
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.EnsureRemoteDir(const ARemoteDir: string; Sftp: ISftpClient);
var
  Segments: TArray<string>;
  Current: string;
  I: Integer;
begin
  if ARemoteDir = '' then
    Exit;
  if Sftp.DirectoryExists(ARemoteDir) then
    Exit;

  // Split path on '/' and rebuild incrementally
  Segments := ARemoteDir.TrimLeft(['/']).Split(['/'], TStringSplitOptions.ExcludeEmpty);
  if Length(Segments) = 0 then
    Exit;

  Current := '';
  for I := 0 to High(Segments) do
  begin
    if ARemoteDir.StartsWith('/') then
      Current := Current + '/' + Segments[I]
    else
      Current := IfThen(Current = '', Segments[I], Current + '/' + Segments[I]);

    if not Sftp.DirectoryExists(Current) then
    begin
      try
        Sftp.CreateDir(Current, FDirPermissions);
      except
        // CreateDir failed -- fall back to ForceDirectories for the full path.
        Sftp.ForceDirectories(ARemoteDir);
        Exit;
      end;
    end;
  end;
end;

{ ---------------------------------------------------------------------------
  Upload / Download single file
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.UploadFile(const ARelPath: string; Sftp: ISftpClient);
var
  LocalPath: string;
  RemotePath: string;
  RemoteDir: string;
begin
  LocalPath := FLocalBasePath + PathDelim + StringReplace(ARelPath, '/', PathDelim, [rfReplaceAll]);
  RemotePath := FRemoteBasePath + '/' + ARelPath;
  RemoteDir := Sftp.ExtractFilePath(RemotePath);
  if (RemoteDir <> '') and not Sftp.DirectoryExists(RemoteDir) then
    EnsureRemoteDir(RemoteDir, Sftp);
  Sftp.Send(LocalPath, RemotePath, { Overwrite= } True, FPermissions);
end;

procedure TSftpSyncEngine.DownloadFile(const ARelPath: string; Sftp: ISftpClient);
var
  LocalPath: string;
  RemotePath: string;
  LocalDir: string;
begin
  LocalPath := FLocalBasePath + PathDelim + StringReplace(ARelPath, '/', PathDelim, [rfReplaceAll]);
  RemotePath := FRemoteBasePath + '/' + ARelPath;
  LocalDir := TPath.GetDirectoryName(LocalPath);
  if (LocalDir <> '') and not TDirectory.Exists(LocalDir) then
    TDirectory.CreateDirectory(LocalDir);
  Sftp.Receive(RemotePath, LocalPath, { Overwrite= } True);
end;

{ ---------------------------------------------------------------------------
  Compare lists and sync
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.SyncLists(Sftp: ISftpClient; Local, Remote: TList<TSyncFileInfo>);
const
  // 10-second tolerance: covers server clock vs local clock skew,
  // network latency, and SFTP timestamp granularity.
  TOLERANCE = 10 / 86400;
var
  LocalMap: TDictionary<string, TSyncFileInfo>;
  RemoteMap: TDictionary<string, TSyncFileInfo>;
  LInfo: TSyncFileInfo;
  RInfo: TSyncFileInfo;
  Key: string;
  Uploaded: Integer;
  Downloaded: Integer;
  // Last remote UTC mtime we saw for each file -- cached across cycles.
  // Comparing remote-to-remote (UTC-to-UTC) avoids all timezone issues.
  LastRemote: TDateTime;
  LastLocal: TDateTime;

  function FmtDT(const ADateTime: TDateTime): string;
  begin
    if ADateTime = 0 then
      Result := 'n/a'
    else
      Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ADateTime);
  end;

begin
  Uploaded := 0;
  Downloaded := 0;

  LocalMap := TDictionary<string, TSyncFileInfo>.Create;
  RemoteMap := TDictionary<string, TSyncFileInfo>.Create;
  try
    for LInfo in Local do
      LocalMap.AddOrSetValue(LowerCase(LInfo.RelPath), LInfo);
    for RInfo in Remote do
      RemoteMap.AddOrSetValue(LowerCase(RInfo.RelPath), RInfo);

    // -- Files only on local -> upload ---------------------------------------
    for LInfo in Local do
    begin
      Key := LowerCase(LInfo.RelPath);
      if RemoteMap.ContainsKey(Key) then
        Continue;
      try
        UploadFile(LInfo.RelPath, Sftp);
        Log('[UP] ' + TPath.GetFileName(LInfo.RelPath) + '  Reason: not on remote' + '  Local: ' + FmtDT(LInfo.MTime));
        Inc(Uploaded);
        FLastSyncedMTime.AddOrSetValue('L:' + Key, LInfo.MTime);
        FLastSyncedMTime.AddOrSetValue('R:' + Key, TTimeZone.Local.ToUniversalTime(LInfo.MTime));
      except
        on E: Exception do
          Log('[UP FAILED] ' + TPath.GetFileName(LInfo.RelPath) + '  (' + E.Message + ')');
      end;
    end;

    // -- Files only on remote -> download ------------------------------------
    for RInfo in Remote do
    begin
      Key := LowerCase(RInfo.RelPath);
      if LocalMap.ContainsKey(Key) then
        Continue;
      try
        DownloadFile(RInfo.RelPath, Sftp);
        Log('[DOWN] ' + TPath.GetFileName(RInfo.RelPath) + '  Reason: not local' + '  Remote: ' + FmtDT(TTimeZone.Local.ToLocalTime(RInfo.MTime)));
        Inc(Downloaded);
        FLastSyncedMTime.AddOrSetValue('R:' + Key, RInfo.MTime);
        FLastSyncedMTime.AddOrSetValue('L:' + Key, TTimeZone.Local.ToLocalTime(RInfo.MTime));
        var
        NotifyPath := FLocalBasePath + PathDelim + StringReplace(RInfo.RelPath, '/', PathDelim, [rfReplaceAll]);
        TMainThreadRunner.Queue(
          procedure
          begin
            NotifyIDEIfOpen(NotifyPath);
          end);
      except
        on E: Exception do
          Log('[DOWN FAILED] ' + TPath.GetFileName(RInfo.RelPath) + '  (' + E.Message + ')');
      end;
    end;

    // -- Files on both sides -------------------------------------------------
    for LInfo in Local do
    begin
      Key := LowerCase(LInfo.RelPath);
      if not RemoteMap.TryGetValue(Key, RInfo) then
        Continue;

      var
      HaveCache := FLastSyncedMTime.TryGetValue('L:' + Key, LastLocal) and FLastSyncedMTime.TryGetValue('R:' + Key, LastRemote);

      if HaveCache then
      begin
        var
        LocalChanged := Abs(LInfo.MTime - LastLocal) > TOLERANCE;
        var
        RemoteChanged := Abs(RInfo.MTime - LastRemote) > TOLERANCE;

        if not LocalChanged and not RemoteChanged then
          Continue;

        if LocalChanged and not RemoteChanged then
        begin
          try
            UploadFile(LInfo.RelPath, Sftp);
            Log('[UP] ' + TPath.GetFileName(LInfo.RelPath) + '  Reason: local changed' + '  Local: ' + FmtDT(LInfo.MTime) + '  Remote: ' +
              FmtDT(TTimeZone.Local.ToLocalTime(RInfo.MTime)));
            Inc(Uploaded);
            FLastSyncedMTime.AddOrSetValue('L:' + Key, LInfo.MTime);
            FLastSyncedMTime.AddOrSetValue('R:' + Key, TTimeZone.Local.ToUniversalTime(LInfo.MTime));
          except
            on E: Exception do
              Log('[UP FAILED] ' + TPath.GetFileName(LInfo.RelPath) + '  (' + E.Message + ')');
          end;
          Continue;
        end;

        if RemoteChanged and not LocalChanged then
        begin
          try
            DownloadFile(RInfo.RelPath, Sftp);
            Log('[DOWN] ' + TPath.GetFileName(RInfo.RelPath) + '  Reason: remote changed' + '  Remote: ' + FmtDT(TTimeZone.Local.ToLocalTime(RInfo.MTime)) +
              '  Local: ' + FmtDT(LInfo.MTime));
            Inc(Downloaded);
            FLastSyncedMTime.AddOrSetValue('R:' + Key, RInfo.MTime);
            FLastSyncedMTime.AddOrSetValue('L:' + Key, TTimeZone.Local.ToLocalTime(RInfo.MTime));
            var
            NotifyPath := FLocalBasePath + PathDelim + StringReplace(RInfo.RelPath, '/', PathDelim, [rfReplaceAll]);
            TMainThreadRunner.Queue(
              procedure
              begin
                NotifyIDEIfOpen(NotifyPath);
              end);
          except
            on E: Exception do
              Log('[DOWN FAILED] ' + TPath.GetFileName(RInfo.RelPath) + '  (' + E.Message + ')');
          end;
          Continue;
        end;

        // Both changed -> newest wins (fall through)
      end;

      // No cache or both changed: UTC comparison
      var
      LocalPath := FLocalBasePath + PathDelim + StringReplace(LInfo.RelPath, '/', PathDelim, [rfReplaceAll]);
      var
      LocalUtc := TTimeZone.Local.ToUniversalTime(TFile.GetLastWriteTime(LocalPath));
      var
      Diff := LocalUtc - RInfo.MTime;

      if Diff > TOLERANCE then
      begin
        try
          UploadFile(LInfo.RelPath, Sftp);
          Log('[UP] ' + TPath.GetFileName(LInfo.RelPath) + '  Reason: local newer' + '  Local: ' + FmtDT(LInfo.MTime) + '  Remote: ' +
            FmtDT(TTimeZone.Local.ToLocalTime(RInfo.MTime)));
          Inc(Uploaded);
          FLastSyncedMTime.AddOrSetValue('L:' + Key, LInfo.MTime);
          FLastSyncedMTime.AddOrSetValue('R:' + Key, TTimeZone.Local.ToUniversalTime(LInfo.MTime));
        except
          on E: Exception do
            Log('[UP FAILED] ' + TPath.GetFileName(LInfo.RelPath) + '  (' + E.Message + ')');
        end;
      end
      else if Diff < -TOLERANCE then
      begin
        try
          DownloadFile(RInfo.RelPath, Sftp);
          Log('[DOWN] ' + TPath.GetFileName(RInfo.RelPath) + '  Reason: remote newer' + '  Remote: ' + FmtDT(TTimeZone.Local.ToLocalTime(RInfo.MTime)) +
            '  Local: ' + FmtDT(LInfo.MTime));
          Inc(Downloaded);
          FLastSyncedMTime.AddOrSetValue('R:' + Key, RInfo.MTime);
          FLastSyncedMTime.AddOrSetValue('L:' + Key, TTimeZone.Local.ToLocalTime(RInfo.MTime));
          var
          NotifyPath := FLocalBasePath + PathDelim + StringReplace(RInfo.RelPath, '/', PathDelim, [rfReplaceAll]);
          TMainThreadRunner.Queue(
            procedure
            begin
              NotifyIDEIfOpen(NotifyPath);
            end);
        except
          on E: Exception do
            Log('[DOWN FAILED] ' + TPath.GetFileName(RInfo.RelPath) + '  (' + E.Message + ')');
        end;
      end
      else
      begin
        // Within tolerance -- in sync, seed cache
        FLastSyncedMTime.AddOrSetValue('L:' + Key, LInfo.MTime);
        FLastSyncedMTime.AddOrSetValue('R:' + Key, RInfo.MTime);
      end;
    end;

    if (Uploaded > 0) or (Downloaded > 0) then
      Log('Sync cycle: ' + IntToStr(Uploaded) + ' uploaded, ' + IntToStr(Downloaded) + ' downloaded.');

  finally
    LocalMap.Free;
    RemoteMap.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Main sync cycle
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.DoSyncCycle;
var
  Self_: TSftpSyncEngine;
  LocalBase: string;
  RemoteBase: string;
  IncludeSub: Boolean;
begin
  Self_ := Self;
  LocalBase := FLocalBasePath;
  RemoteBase := FRemoteBasePath;
  IncludeSub := FIncludeSubDirs;

  TTask.Run(TProc(
    procedure
    var
      Session: ISshSession;
      Sftp: ISftpClient;
      LocalList: TList<TSyncFileInfo>;
      RemoteList: TList<TSyncFileInfo>;
      // Check if an immediate sync was also requested during this cycle
      WasImmediate: Boolean;
    begin
      Session := nil;
      Sftp := nil;
      LocalList := TList<TSyncFileInfo>.Create;
      RemoteList := TList<TSyncFileInfo>.Create;
      try
        try
          // -- 1. Collect local files ----------------------------------------
          Self_.CollectLocalFiles(LocalList);

          if LocalList.Count = 0 then
          begin
            Self_.Log('No local project files found in: ' + LocalBase);
            Exit;
          end;

          // -- 2. Connect ---------------------------------------------------
          if not Self_.ConnectSftp(Session, Sftp) then
            Exit;

          // -- 3. Ensure remote base directory exists -----------------------
          if not Sftp.DirectoryExists(RemoteBase) then
          begin
            Self_.EnsureRemoteDir(RemoteBase, Sftp);
            Self_.Log('Created remote directory: ' + RemoteBase);
          end;

          // -- 4. Collect remote files ---------------------------------------
          Self_.CollectRemoteFiles(Sftp, RemoteBase, RemoteList, IncludeSub);

          // -- 5. Compare and sync -------------------------------------------
          Self_.SyncLists(Sftp, LocalList, RemoteList);

        except
          on E: Exception do
            Self_.Log('Sync error: ' + E.Message);
        end;

      finally
        // -- 6. Disconnect ---------------------------------------------------
        // Nil Sftp first (releases SFTP channel), then disconnect SSH session.
        // Assign to local non-interface variable to break the closure's reference
        // so libssh2 can fully tear down before the next cycle connects.
        try
          Sftp := nil;
        except
        end;
        try
          if Assigned(Session) then
          begin
            Session.Disconnect;
            Session := nil;
          end;
        except
        end;
        // Give libssh2 a moment to complete TCP teardown before the closure
        // frame (and any remaining interface refs) is garbage-collected.
        Sleep(200);

        LocalList.Free;
        RemoteList.Free;

        // Consume any watcher event that fired during this cycle
        WaitForSingleObject(Self_.FImmediateSync, 0);

        TMainThreadRunner.Queue(
          procedure
          begin
            Self_.FSyncBusy := False;
          end);
      end;
    end));
end;

{ ---------------------------------------------------------------------------
  IDE notification
  --------------------------------------------------------------------------- }

procedure TSftpSyncEngine.NotifyIDEIfOpen(const ALocalPath: string);
var
  ModSvc: IOTAModuleServices;
  Module: IOTAModule;
  I: Integer;
  NormTarget: string;
begin
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
    MessageDlg('[SYNC]  CyAI SFTP Sync' + sLineBreak + sLineBreak + '"' + TPath.GetFileName(ALocalPath) + '" was updated from the SFTP server.' + sLineBreak +
      sLineBreak + 'Use  File -> Revert  to reload it from disk.', mtInformation, [mbOK], 0);
    Exit;
  end;
end;

{ ---------------------------------------------------------------------------
  Cache persistence
  The [SyncCache] section stores one key-value pair per cached timestamp.
  Keys are the raw 'L:relpath' / 'R:relpath' strings (colons and slashes
  are valid in INI values but not in keys, so we base64-encode the key).
  We use a simpler approach: percent-encode just the characters that TIniFile
  rejects in key names ( = [ ] ; # newline ).
  --------------------------------------------------------------------------- }

const
  CACHE_SECTION = 'SyncCache';

function EncodeKey(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '=', '[', ']', ';', '#', #13, #10:
        Result := Result + '%' + IntToHex(Ord(S[I]), 2);
    else
      Result := Result + S[I];
    end;
end;

function DecodeKey(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '%') and (I + 2 <= Length(S)) then
    begin
      Result := Result + Chr(StrToIntDef('$' + Copy(S, I + 1, 2), Ord('%')));
      Inc(I, 3);
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

procedure TSftpSyncEngine.SaveCacheTo(const AFilePath: string);
var
  Ini: TIniFile;
  Key: string;
  Val: TDateTime;
begin
  if AFilePath = '' then
    Exit;
  Ini := TIniFile.Create(AFilePath);
  try
    Ini.EraseSection(CACHE_SECTION);
    for Key in FLastSyncedMTime.Keys do
    begin
      Val := FLastSyncedMTime[Key];
      Ini.WriteFloat(CACHE_SECTION, EncodeKey(Key), Val);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TSftpSyncEngine.LoadCacheFrom(const AFilePath: string);
var
  Ini: TIniFile;
  Keys: TStringList;
  I: Integer;
  RawKey: string;
  CacheKey: string;
  Val: TDateTime;
begin
  if (AFilePath = '') or not TFile.Exists(AFilePath) then
    Exit;
  FLastSyncedMTime.Clear;
  Keys := TStringList.Create;
  Ini := TIniFile.Create(AFilePath);
  try
    Ini.ReadSection(CACHE_SECTION, Keys);
    for I := 0 to Keys.Count - 1 do
    begin
      RawKey := Keys[I];
      CacheKey := DecodeKey(RawKey);
      Val := Ini.ReadFloat(CACHE_SECTION, RawKey, 0);
      if Val <> 0 then
        FLastSyncedMTime.AddOrSetValue(CacheKey, Val);
    end;
  finally
    Ini.Free;
    Keys.Free;
  end;
end;

initialization

GSftpSync := TSftpSyncEngine.Create;

finalization

FreeAndNil(GSftpSync);

end.
