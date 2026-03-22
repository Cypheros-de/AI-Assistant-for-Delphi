unit CyAIAssistant.Plugin;

// CyAIAssistant.Plugin.pas
//
// Menu strategy:
// - "Code Assistant" added to the editor right-click popup menu
// by hooking TPopupActionBar.OnPopup on the TEditWindow form.
// - "Cypheros AI Assistant Settings..." stays in Tools menu.
// - Shortcut Ctrl+Alt+A works everywhere via the Tools menu item / action.
//
// Editor popup hook:
// The Delphi IDE editor window is a TForm with ClassName = 'TEditWindow'.
// It contains a TPopupActionBar which is the right-click context menu.
// We find it via FindEditorPopup, save the existing OnPopup handler, and
// chain into it. On destroy we restore the saved handler.

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.UITypes,
  Winapi.Windows, Winapi.Messages,
  Vcl.Menus, Vcl.ActnList, Vcl.ExtCtrls, Vcl.AppEvnts,
  ToolsAPI, CyAIAssistant.AIClient, CyAIAssistant.GPUMonitor;

type
  // Polls TThread.GetCPUUsage every 500 ms on a background thread.
  // Stop is signalled via a TEvent so the thread wakes immediately on shutdown
  // instead of waiting out the full sleep interval.
  TCPUMonitorThread = class(TThread)
  private
    FStopEvent: TEvent;
    FCPUUsage: Single;
    FMonitorEvent: TNotifyEvent;
    FGPUUsage: Single;
    FVRAMUsage: Single;
    FGPUMonitoring: Boolean;
    FVRAM_MB: Cardinal;
    FVRAM_MBUsed: Cardinal;
    procedure DoEvent;
    procedure UpdateGPUUsage(AGPUMonitor: TGPUMonitor);
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Stop;
    property CPUUsage: Single read FCPUUsage;
    property GPUMonitor: Boolean read FGPUMonitoring;
    property GPUUsage: Single read FGPUUsage;
    property VRAMUsage: Single read FVRAMUsage;
    property VRAM_MB: Cardinal read FVRAM_MB;
    property VRAM_MBUsed: Cardinal read FVRAM_MBUsed;
    property OnMonitor: TNotifyEvent read FMonitorEvent write FMonitorEvent;
  end;

  TCyAIAssistantPlugin = class
  private
    // Tools menu items
    FMenuItemSettings: TMenuItem;
    FMenuItemNewUnit: TMenuItem;
    FMenuItemSftpSync: TMenuItem;    // enabled only when a project is open
    FMenuItemCodeAssist: TMenuItem;  // enabled only when an editor file is open
    FMenuItemCompletion: TMenuItem;  // enabled only when editor open + completion enabled
    FSeparator: TMenuItem;

    // Editor popup hook
    FEditorPopupMenu: TPopupMenu;
    FSavedPopupMethod: TNotifyEvent;

    FTimer: TTimer;
    FCPUThread: TCPUMonitorThread;
    FCompletionClient: TAIClient;
    FAppEvents: TApplicationEvents;
    FCompletionRunning: Boolean;
    FInstalled: Boolean;

    procedure OnTimer(Sender: TObject);
    procedure OnUpdateMenuState(Sender: TObject);
    procedure InstallToolsMenu;
    procedure InstallEditorPopup;
    procedure OnEditorPopup(Sender: TObject); // our OnPopup hook
    procedure OnAIAssistClick(Sender: TObject);
    procedure OnAIAssistFromToolsClick(Sender: TObject);
    procedure OnNewUnitClick(Sender: TObject);
    procedure OnSftpSyncClick(Sender: TObject);
    procedure OnSettingsClick(Sender: TObject);
    procedure OnAboutClick(Sender: TObject);
    procedure OnChatClick(Sender: TObject);
    procedure OnCodeCompletionClick(Sender: TObject);
    procedure OnAppMessage(var Msg: tagMSG; var Handled: Boolean);
    function HasOpenProject: Boolean;
    function FindEditorPopup: TPopupMenu;
    function GetSelectedText: string;
    function GetCurrentEditor: IOTASourceEditor;
    procedure OnMonitor(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function GetCPUUsage: Single;
  end;

implementation

uses
  Vcl.Dialogs, Vcl.Forms,
  System.IOUtils, System.StrUtils,
  CyAIAssistant.PromptDialog,
  CyAIAssistant.NewUnitDialog,
  CyAIAssistant.ChatDialog,
  CyAIAssistant.Settings,
  CyAIAssistant.SettingsDialog,
  CyAIAssistant.SftpSyncDialog,
  CyAIAssistant.AboutDialog;

var
  ChatDlg: TChatDialog;
  PromptDlg: TPromptDialog;
  NewUnitDlg: TNewUnitDialog;

// ---------------------------------------------------------------------------
// Strips explanatory text that some models (e.g. deepseek-coder) add around
// code completions.  Strategy:
//   1. If the output contains ``` fences, extract the first fenced block.
//   2. Otherwise, drop lines that start with known English prose starters.
// ---------------------------------------------------------------------------

// Returns the content of the first ``` ... ``` block found in S, or '' if
// no complete code fence pair is present.
function ExtractFirstCodeBlock(const S: string): string;
var
  P, CodeStart, FenceEnd: Integer;
begin
  Result := '';
  // Find opening fence
  P := Pos('```', S);
  if P = 0 then
    Exit;

  // Skip the opening fence line (language hint etc.) to the next line
  CodeStart := P + 3;
  while (CodeStart <= Length(S)) and not (S[CodeStart] in [#10, #13]) do
    Inc(CodeStart);
  while (CodeStart <= Length(S)) and (S[CodeStart] in [#10, #13]) do
    Inc(CodeStart);

  // Find closing fence (search from CodeStart so we skip the opening one)
  FenceEnd := PosEx('```', S, CodeStart);
  if FenceEnd = 0 then
  begin
    // No closing fence — take everything after the opening fence anyway
    Result := TrimRight(Copy(S, CodeStart, MaxInt));
    Exit;
  end;

  Result := TrimRight(Copy(S, CodeStart, FenceEnd - CodeStart));
end;

const
  PROSE_PREFIXES: array[0..30] of string = (
    'Sure', 'Of course', 'Certainly', 'Absolutely',
    'It seems', 'It looks', 'It appears', 'It is ',
    'The code', 'The above', 'The following', 'The corrected',
    'Note that', 'Note:', 'Also note', 'Also,', 'Also ',
    'Please ', 'However,', 'However ', 'Here is', 'Here''s',
    'This code', 'This will', 'This is', 'This should',
    'Make sure', 'Ensure ', 'Check ', 'You need', 'You can');

function IsProseLineS(const Line: string): Boolean;
var
  I: Integer;
  T: string;
begin
  T := TrimLeft(Line);
  for I := Low(PROSE_PREFIXES) to High(PROSE_PREFIXES) do
    if Copy(T, 1, Length(PROSE_PREFIXES[I])) = PROSE_PREFIXES[I] then
      Exit(True);
  Result := False;
end;

function CleanCompletion(const S: string): string;
var
  Lines: TStringList;
  SB: TStringBuilder;
  I: Integer;
  Block: string;
begin
  // Strategy 1: extract content from the first ``` block
  if Pos('```', S) > 0 then
  begin
    Block := ExtractFirstCodeBlock(S);
    if Block <> '' then
    begin
      Result := Block;
      Exit;
    end;
  end;

  // Strategy 2: drop lines that are obviously English prose
  Lines := TStringList.Create;
  SB := TStringBuilder.Create;
  try
    Lines.Text := S;
    for I := 0 to Lines.Count - 1 do
      if not IsProseLineS(Lines[I]) then
        SB.AppendLine(Lines[I]);
    Result := TrimRight(SB.ToString);
    if Result = '' then
      Result := TrimRight(S); // fallback: return as-is
  finally
    Lines.Free;
    SB.Free;
  end;
end;

// TCPUMonitorThread

constructor TCPUMonitorThread.Create;
begin
  FStopEvent := TEvent.Create(nil, True, False, '');
  FCPUUsage  := 0;
  FGPUUsage  := 0;
  FVRAMUsage := 0;
  FVRAM_MB   := 0;
  FVRAM_MBUsed := 0;
  FGPUMonitoring := False;
  FreeOnTerminate := False;
  inherited Create(False);
end;

destructor TCPUMonitorThread.Destroy;
begin
  FStopEvent.Free;
  inherited;
end;

procedure TCPUMonitorThread.DoEvent;
begin
  if assigned(FMonitorEvent) then
    FMonitorEvent(self);
end;

procedure TCPUMonitorThread.UpdateGPUUsage(AGPUMonitor: TGPUMonitor);
var
    i: Integer;
    LGPUUsage: Double;
    LVRam: Cardinal;
    LVRamUsed: Cardinal;
    HWGPUs: Integer;
begin
  LGPUUsage := 0;
  HWGPUs := 0;
  LVRam := 0;
  LVRamUsed := 0;
  AGPUMonitor.Update;
  for i := 0 to AGPUMonitor.GPUCount - 1 do
  begin
    if not AGPUMonitor.GPUs[i].IsSoftwareDevice then
    begin
      LGPUUsage := LGPUUsage + AGPUMonitor.GPUs[i].UsagePercent;
      LVRam := LVRam + AGPUMonitor.GPUs[i].DedicatedTotalMB;
      LVRamUsed := LVRamUsed + AGPUMonitor.GPUs[i].DedicatedUsedMB;
      Inc(HWGPUs);
    end;
  end;

  if HWGPUs > 0 then
    FGPUUsage := LGPUUsage / HWGPUs
  else
    FGPUUsage := 0;

  if LVRam > 0 then
    FVRAMUsage := 100 * LVRamUsed / LVRam
  else
    FVRAMUsage := 0;

  FVRAM_MB := LVRam;
  FVRAM_MBUsed := LVRamUsed;
end;

procedure TCPUMonitorThread.Execute;
var
    PrevSystemTimes: TSystemTimes;
    GPUMonitor: TGPUMonitor;
    HWGPUs: Integer;
    i: Integer;
begin
  HWGPUs := 0;
  try
    GPUMonitor := TGPUMonitor.Create;
    for i := 0 to GPUMonitor.GPUCount - 1 do
    begin
      //Only hardware GPUs
      if not GPUMonitor.GPUs[i].IsSoftwareDevice then
        inc(HWGPUs);
    end;
    FGPUMonitoring := GPUMonitor.IsReady and (HWGPUs > 0);
  except
  end;
  try
    while not Terminated do
    begin
      FCPUUsage := TThread.GetCPUUsage(PrevSystemTimes);
      if FGPUMonitoring then
        UpdateGPUUsage(GPUMonitor);

      Synchronize(DoEvent);

      // Wait 1000 ms or until Stop signals the event — whichever comes first.
      if FStopEvent.WaitFor(1000) = wrSignaled then
        Break;
    end;
  finally
    if assigned(GPUMonitor) then
      GPUMonitor.Free;
  end;
end;

procedure TCPUMonitorThread.Stop;
begin
  Terminate;
  FStopEvent.SetEvent; // wake the thread immediately
end;

// TCyAIAssistantPlugin

constructor TCyAIAssistantPlugin.Create;
begin
  inherited;
  FInstalled := False;
  FCompletionClient := TAIClient.Create;
  FAppEvents := TApplicationEvents.Create(nil);
  FAppEvents.OnMessage := OnAppMessage;
  FCPUThread := TCPUMonitorThread.Create;
  FCPUThread.OnMonitor := OnMonitor;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 500;
  FTimer.OnTimer := OnTimer;
  FTimer.Enabled := True;
end;

destructor TCyAIAssistantPlugin.Destroy;
begin
  // Disable timer immediately to prevent any pending callbacks firing
  // after we start tearing down.  Free it before touching anything else.
  FreeAndNil(FCompletionClient);
  FreeAndNil(FAppEvents);

  if Assigned(FCPUThread) then
  begin
    FCPUThread.Stop;
    FCPUThread.WaitFor;
    FreeAndNil(FCPUThread);
  end;

  if Assigned(FTimer) then
  begin
    FTimer.Enabled := False;
    FTimer.OnTimer := nil;
    FreeAndNil(FTimer);
  end;

  // Restore editor popup handler.  The popup is owned by the IDE form —
  // we must NEVER free it, just clear our hook.
  if Assigned(FEditorPopupMenu) then
  begin
    if TMethod(FEditorPopupMenu.OnPopup).Code = @TCyAIAssistantPlugin.OnEditorPopup then
      FEditorPopupMenu.OnPopup := FSavedPopupMethod;
    FEditorPopupMenu := nil;
  end;

  // Remove the top-level Tools menu items we added.
  //
  // Ownership rules:
  // FSeparator      — created with Owner = ToolsMenu  → ToolsMenu frees it
  // automatically, but the IDE menu may already be gone
  // by the time we get here.  Safe pattern: Remove first
  // (detaches from parent list), then Free.
  //
  // FMenuItemNewUnit — same owner rule.  All sub-items (FMenuItemSettings,
  // Unit/Class Assistant, Settings...) were created with
  // Owner = FMenuItemNewUnit, so freeing FMenuItemNewUnit
  // frees them automatically.  Do NOT free FMenuItemSettings
  // separately — it is already gone at that point.
  //
  // We nil FMenuItemSettings first so the block below never double-frees it.
  FMenuItemSettings := nil;   // owned by FMenuItemNewUnit — freed with it
  FMenuItemCompletion := nil; // owned by FMenuItemNewUnit — freed with it

  if Assigned(FMenuItemNewUnit) then
  begin
    if Assigned(FMenuItemNewUnit.Parent) then
      FMenuItemNewUnit.Parent.Remove(FMenuItemNewUnit);
    FreeAndNil(FMenuItemNewUnit);
  end;

  if Assigned(FSeparator) then
  begin
    if Assigned(FSeparator.Parent) then
      FSeparator.Parent.Remove(FSeparator);
    FreeAndNil(FSeparator);
  end;

  inherited;
end;

procedure TCyAIAssistantPlugin.OnMonitor(Sender: TObject);
begin
  if assigned(ChatDlg) and (ChatDlg.Visible) then
    ChatDlg.SetMonitorValues(FCPUThread.CPUUsage, FCPUThread.GPUUsage, FCPUThread.VRAMUsage, FCPUThread.VRAM_MB, FCPUThread.VRAM_MBUsed, FCPUThread.GPUMonitor);

  if assigned(PromptDlg) and (PromptDlg.Visible) then
    PromptDlg.SetMonitorValues(FCPUThread.CPUUsage, FCPUThread.GPUUsage, FCPUThread.VRAMUsage, FCPUThread.VRAM_MB, FCPUThread.VRAM_MBUsed, FCPUThread.GPUMonitor);

  if assigned(NewUnitDlg) and (NewUnitDlg.Visible) then
    NewUnitDlg.SetMonitorValues(FCPUThread.CPUUsage, FCPUThread.GPUUsage, FCPUThread.VRAMUsage, FCPUThread.VRAM_MB, FCPUThread.VRAM_MBUsed, FCPUThread.GPUMonitor);
end;

procedure TCyAIAssistantPlugin.OnTimer(Sender: TObject);
begin
  FTimer.Enabled := False;
  InstallToolsMenu;
  InstallEditorPopup;
  // Re-use the timer for periodic menu state refresh (every 2 seconds)
  FTimer.Interval := 2000;
  FTimer.OnTimer := OnUpdateMenuState;
  FTimer.Enabled := True;
end;

procedure TCyAIAssistantPlugin.OnUpdateMenuState(Sender: TObject);
begin
  if Assigned(FMenuItemSftpSync) then
    FMenuItemSftpSync.Enabled := HasOpenProject;
  if Assigned(FMenuItemCodeAssist) then
    FMenuItemCodeAssist.Enabled := (GetCurrentEditor <> nil);
  if Assigned(FMenuItemCompletion) then
    FMenuItemCompletion.Enabled := (GetCurrentEditor <> nil) and GSettings.CodeCompletionEnabled;
end;

function TCyAIAssistantPlugin.HasOpenProject: Boolean;
var
  ModSvc: IOTAModuleServices;
  ProjGroup: IOTAProjectGroup;
  Module: IOTAModule;
  I: Integer;
begin
  Result := False;
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
    Exit;

  // MainProjectGroup.ActiveProject is the most direct check
  ProjGroup := ModSvc.MainProjectGroup;
  if Assigned(ProjGroup) and Assigned(ProjGroup.ActiveProject) then
  begin
    Result := True;
    Exit;
  end;

  // Fallback: any IOTAProject or IOTAProjectGroup in the module list
  for I := 0 to ModSvc.ModuleCount - 1 do
  begin
    Module := ModSvc.Modules[I];
    if Supports(Module, IOTAProject) or Supports(Module, IOTAProjectGroup) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// --- Tools menu (Settings + shortcut-bearing duplicate) ---

procedure TCyAIAssistantPlugin.InstallToolsMenu;
var
  NTASvc: INTAServices;
  MainMenu: TMainMenu;
  ToolsMenu: TMenuItem;
  I: Integer;
  Item: TMenuItem;
  SubItem: TMenuItem;
  Cap: string;
begin
  if FInstalled then
    Exit;

  if not Supports(BorlandIDEServices, INTAServices, NTASvc) then
    Exit;
  MainMenu := NTASvc.MainMenu;
  if MainMenu = nil then
    Exit;

  ToolsMenu := nil;
  for I := 0 to MainMenu.Items.Count - 1 do
  begin
    Item := MainMenu.Items[I];
    if SameText(Item.Name, 'ToolsMenu') or SameText(Item.Name, 'Tools') or SameText(Item.Name, 'MnuTools') or SameText(Item.Name, 'mnuTools') then
    begin
      ToolsMenu := Item;
      Break;
    end;
  end;

  if ToolsMenu = nil then
    for I := 0 to MainMenu.Items.Count - 1 do
    begin
      Item := MainMenu.Items[I];
      Cap := StringReplace(Item.Caption, '&', '', [rfReplaceAll]);
      if SameText(Cap, 'Tools') or SameText(Cap, 'Extras') or SameText(Cap, 'Outils') or SameText(Cap, 'Strumenti') or SameText(Cap, 'Herramientas') then
      begin
        ToolsMenu := Item;
        Break;
      end;
    end;

  if (ToolsMenu = nil) and (MainMenu.Items.Count > 2) then
    ToolsMenu := MainMenu.Items[MainMenu.Items.Count - 2];

  if ToolsMenu = nil then
    Exit;

  FSeparator := TMenuItem.Create(ToolsMenu);
  FSeparator.Caption := '-';
  ToolsMenu.Add(FSeparator);

  // "Cypheros AI Assistant" submenu in Tools — FMenuItemNewUnit holds the parent
  FMenuItemNewUnit := TMenuItem.Create(ToolsMenu);
  FMenuItemNewUnit.Caption := 'Cypheros AI Assistant';
  ToolsMenu.Add(FMenuItemNewUnit);

  FMenuItemSettings := TMenuItem.Create(FMenuItemNewUnit);
  FMenuItemSettings.Caption := 'Code Assistant';
  FMenuItemSettings.Enabled := False; // disabled until an editor file is open
  FMenuItemSettings.OnClick := OnAIAssistFromToolsClick;
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, FMenuItemSettings);
  FMenuItemCodeAssist := FMenuItemSettings;

  FMenuItemCompletion := TMenuItem.Create(FMenuItemNewUnit);
  FMenuItemCompletion.Caption := 'Code Completion';
  FMenuItemCompletion.ShortCut := TextToShortCut('Ctrl+Alt+Space');
  FMenuItemCompletion.Enabled := False; // enabled when editor open + completion enabled
  FMenuItemCompletion.OnClick := OnCodeCompletionClick;
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, FMenuItemCompletion);

  SubItem := TMenuItem.Create(FMenuItemNewUnit);
  SubItem.Caption := 'Unit/Class Assistant';
  SubItem.OnClick := OnNewUnitClick;
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, SubItem);

  SubItem := TMenuItem.Create(FMenuItemNewUnit);
  SubItem.Caption := 'AI Chat...';
  SubItem.OnClick := OnChatClick;
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, SubItem);

  FMenuItemSftpSync := TMenuItem.Create(FMenuItemNewUnit);
  FMenuItemSftpSync.Caption := 'SFTP Sync...';
  FMenuItemSftpSync.Enabled := False; // disabled until a project is open
  FMenuItemSftpSync.OnClick := OnSftpSyncClick;
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, FMenuItemSftpSync);

  SubItem := TMenuItem.Create(FMenuItemNewUnit);
  SubItem.Caption := 'Settings...';
  SubItem.OnClick := OnSettingsClick;
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, SubItem);

  SubItem := TMenuItem.Create(FMenuItemNewUnit);
  SubItem.Caption := '-';
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, SubItem);

  SubItem := TMenuItem.Create(FMenuItemNewUnit);
  SubItem.Caption := 'About...';
  SubItem.OnClick := OnAboutClick;
  FMenuItemNewUnit.Insert(FMenuItemNewUnit.Count, SubItem);

  FInstalled := True;
end;

// --- Editor popup menu ---

function TCyAIAssistantPlugin.FindEditorPopup: TPopupMenu;
var
  I, j: Integer;
  EditWin: TForm;
  Comp: TComponent;
begin
  Result := nil;
  for I := 0 to Screen.FormCount - 1 do
    if CompareText(Screen.Forms[I].ClassName, 'TEditWindow') = 0 then
    begin
      EditWin := Screen.Forms[I];
      for j := 0 to EditWin.ComponentCount - 1 do
      begin
        Comp := EditWin.Components[j];
        // TPopupActionBar descends from TPopupMenu — match by class name
        if (Comp is TPopupMenu) and (CompareText(Copy(Comp.ClassName, 1, 14), 'TPopupActionBa') = 0) then
        begin
          Result := TPopupMenu(Comp);
          Exit;
        end;
      end;
      // Fallback: take the first TPopupMenu found in the editor window
      if Result = nil then
        for j := 0 to EditWin.ComponentCount - 1 do
          if EditWin.Components[j] is TPopupMenu then
          begin
            Result := TPopupMenu(EditWin.Components[j]);
            Exit;
          end;
    end;
end;

procedure TCyAIAssistantPlugin.InstallEditorPopup;
var
  Popup: TPopupMenu;
begin
  Popup := FindEditorPopup;
  if Popup = nil then
    Exit;

  FEditorPopupMenu := Popup;
  FSavedPopupMethod := Popup.OnPopup;
  Popup.OnPopup := OnEditorPopup;
end;

procedure TCyAIAssistantPlugin.OnEditorPopup(Sender: TObject);
const
  TAG_AI = 9771; // unique tag to identify our popup items — no Names, no conflicts
var
  I: Integer;
  Sep: TMenuItem;
  SubMenu: TMenuItem;
  Item: TMenuItem;
  ItemNew: TMenuItem;
  ItemChat: TMenuItem;
begin
  // Chain to the IDE's handler first.
  if Assigned(FSavedPopupMethod) then
    FSavedPopupMethod(Sender);

  // Remove our items from the previous call, identified by Tag only.
  // No Name is ever set, so nothing enters the component name registry.
  for I := FEditorPopupMenu.Items.Count - 1 downto 0 do
    if FEditorPopupMenu.Items[I].Tag = TAG_AI then
      FEditorPopupMenu.Items.Delete(I);

  // Only show our submenu when a source code editor is active.
  // GetCurrentEditor returns nil on the Welcome page and other non-source tabs.
  if GetCurrentEditor = nil then
    Exit;

  // Separator before our submenu
  Sep := TMenuItem.Create(nil);
  Sep.Tag := TAG_AI;
  Sep.Caption := '-';
  FEditorPopupMenu.Items.Add(Sep);

  // Submenu: "Cypheros AI Assistant"
  SubMenu := TMenuItem.Create(nil);
  SubMenu.Tag := TAG_AI;
  SubMenu.Caption := 'Cypheros AI Assistant';
  FEditorPopupMenu.Items.Add(SubMenu);

  // "Code Assistant" — requires a selection
  Item := TMenuItem.Create(nil);
  Item.Tag := TAG_AI;
  Item.Caption := 'Code Assistant';
  Item.ShortCut := TextToShortCut('Ctrl+Alt+A');
  Item.Enabled := Length(Trim(GetSelectedText)) > 0;
  Item.OnClick := OnAIAssistClick;
  SubMenu.Add(Item);

  // "Unit/Class Assistant" — always enabled
  ItemNew := TMenuItem.Create(nil);
  ItemNew.Tag := TAG_AI;
  ItemNew.Caption := 'Unit/Class Assistant';
  ItemNew.OnClick := OnNewUnitClick;
  SubMenu.Add(ItemNew);

  // "AI Chat..." — always enabled
  ItemChat := TMenuItem.Create(nil);
  ItemChat.Tag := TAG_AI;
  ItemChat.Caption := 'AI Chat...';
  ItemChat.OnClick := OnChatClick;
  SubMenu.Add(ItemChat);

  // "Code Completion" — only shown when feature is enabled
  if GSettings.CodeCompletionEnabled then
  begin
    Item := TMenuItem.Create(nil);
    Item.Tag := TAG_AI;
    Item.Caption := 'Code Completion';
    Item.ShortCut := TextToShortCut('Ctrl+Alt+Space');
    Item.OnClick := OnCodeCompletionClick;
    SubMenu.Add(Item);
  end;
end;

// --- Editor / selection helpers ---

function TCyAIAssistantPlugin.GetCurrentEditor: IOTASourceEditor;
var
  ModSvc: IOTAModuleServices;
  Module: IOTAModule;
  I: Integer;
  Editor: IOTAEditor;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
    Exit;

  Module := ModSvc.CurrentModule;
  if Module = nil then
    Exit;
  for I := 0 to Module.ModuleFileCount - 1 do
  begin
    Editor := Module.ModuleFileEditors[I];
    if Supports(Editor, IOTASourceEditor, Result) then
      Break;
  end;
end;

function TCyAIAssistantPlugin.GetSelectedText: string;
var
  SrcEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  Block: IOTAEditBlock;
begin
  Result := '';
  SrcEditor := GetCurrentEditor;
  if SrcEditor = nil then
    Exit;
  if SrcEditor.EditViewCount = 0 then
    Exit;
  EditView := SrcEditor.EditViews[0];
  if EditView = nil then
    Exit;
  Block := EditView.Block;
  if (Block <> nil) and Block.IsValid then
    Result := Block.Text;
end;

procedure TCyAIAssistantPlugin.OnAIAssistClick(Sender: TObject);
var
  SelectedText: string;
begin
  SelectedText := GetSelectedText;
  if Length(Trim(SelectedText)) = 0 then
  begin
    ShowMessage('No text selected.' + sLineBreak + 'Please select some source code in the editor first.');
    Exit;
  end;
  PromptDlg := TPromptDialog.Create(nil, SelectedText, GetCurrentEditor);
  try
    PromptDlg.ShowModal;
  finally
    PromptDlg.Free;
    PromptDlg := nil;
  end;
end;

procedure TCyAIAssistantPlugin.OnAIAssistFromToolsClick(Sender: TObject);
begin
  OnAIAssistClick(Sender);
end;

procedure TCyAIAssistantPlugin.OnNewUnitClick(Sender: TObject);
begin
  NewUnitDlg := TNewUnitDialog.Create(nil);
  try
    NewUnitDlg.ShowModal;
  finally
    NewUnitDlg.Free;
  end;
end;

procedure TCyAIAssistantPlugin.OnSftpSyncClick(Sender: TObject);
var
  Dlg: TSftpSyncDialog;
  I: Integer;
begin
  // Find existing instance if already open
  Dlg := nil;
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I] is TSftpSyncDialog then
    begin
      Dlg := TSftpSyncDialog(Screen.Forms[I]);
      Break;
    end;

  if Dlg = nil then
    Dlg := TSftpSyncDialog.Create(Application);

  Dlg.Show;
  Dlg.BringToFront;
end;

procedure TCyAIAssistantPlugin.OnSettingsClick(Sender: TObject);
var
  Dlg: TSettingsDialog;
begin
  Dlg := TSettingsDialog.Create(nil);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TCyAIAssistantPlugin.OnAboutClick(Sender: TObject);
var
  Dlg: TAboutDialog;
begin
  Dlg := TAboutDialog.Create(nil);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

function TCyAIAssistantPlugin.GetCPUUsage: Single;
begin
  if Assigned(FCPUThread) then
    Result := FCPUThread.CPUUsage
  else
    Result := 0;
end;

procedure TCyAIAssistantPlugin.OnChatClick(Sender: TObject);
begin
  ChatDlg := TChatDialog.Create(nil);
  try
    ChatDlg.ShowModal;
  finally
    ChatDlg.Free;
    ChatDlg := nil;
  end;
end;

procedure TCyAIAssistantPlugin.OnAppMessage(var Msg: tagMSG; var Handled: Boolean);
begin
  if Msg.message = WM_KEYDOWN then
  begin
    // ESC aborts a running code completion
    if (Msg.wParam = VK_ESCAPE) and FCompletionRunning then
    begin
      FCompletionClient.Cancel;
      FCompletionRunning := False;
      Screen.Cursor := crDefault;
      Handled := True;
      Exit;
    end;

    // Ctrl+Alt+Space triggers code completion
    if (Msg.wParam = VK_SPACE) and
       (GetKeyState(VK_CONTROL) < 0) and
       (GetKeyState(VK_MENU) < 0) and   // VK_MENU = Alt
       GSettings.CodeCompletionEnabled then
    begin
      Handled := True;
      OnCodeCompletionClick(nil);
    end;
  end;
end;

procedure TCyAIAssistantPlugin.OnCodeCompletionClick(Sender: TObject);
var
  SrcEditor: IOTASourceEditor;
  EditView: IOTAEditView;
  Source: string;
  Lines: TStringList;
  CursorPos: TOTAEditPos;
  I, LineIdx, LastNL: Integer;
  Prefix, Suffix, LineStr, PartialLine: string;
begin
  if not GSettings.CodeCompletionEnabled then
  begin
    ShowMessage('Code completion is disabled.' + sLineBreak +
      'Enable it in Settings > Ollama (Local).');
    Exit;
  end;

  if Trim(GSettings.OllamaCompletionModel) = '' then
  begin
    ShowMessage('No completion model selected.' + sLineBreak +
      'Please choose a model in Settings > Ollama (Local) > Completion Model.');
    Exit;
  end;

  SrcEditor := GetCurrentEditor;
  if SrcEditor = nil then
  begin
    ShowMessage('No active source editor.');
    Exit;
  end;
  if SrcEditor.EditViewCount = 0 then
    Exit;

  EditView := SrcEditor.EditViews[0];
  CursorPos := EditView.CursorPos;

  // Read source from disk (cursor position comes from the live EditView)
  if SrcEditor.FileName = '' then
    Exit; // unsaved new file — no context to complete
  try
    Source := TFile.ReadAllText(SrcEditor.FileName, TEncoding.UTF8);
  except
    Exit;
  end;

  if Source = '' then
    Exit;

  // Split source into prefix (before cursor) and suffix (after cursor)
  Lines := TStringList.Create;
  try
    Lines.Text := Source;
    Prefix := '';
    Suffix := '';
    LineIdx := CursorPos.Line - 1; // convert 1-based to 0-based

    for I := 0 to LineIdx - 1 do
      if I < Lines.Count then
        Prefix := Prefix + Lines[I] + Lines.LineBreak;

    if LineIdx < Lines.Count then
    begin
      LineStr := Lines[LineIdx];
      Prefix := Prefix + Copy(LineStr, 1, CursorPos.Col - 1);
      Suffix := Copy(LineStr, CursorPos.Col, MaxInt);
      for I := LineIdx + 1 to Lines.Count - 1 do
        Suffix := Suffix + Lines.LineBreak + Lines[I];
    end;
  finally
    Lines.Free;
  end;

  // Capture the partial current line (trimmed) for deduplication in callback.
  // Models often echo the partial line back at the start of their completion.
  LastNL := 0;
  for I := Length(Prefix) downto 1 do
    if Prefix[I] in [#13, #10] then
    begin
      LastNL := I;
      Break;
    end;
  PartialLine := TrimLeft(Copy(Prefix, LastNL + 1, MaxInt));

  // Limit context to keep requests fast
  if Length(Prefix) > 2000 then
    Prefix := Copy(Prefix, Length(Prefix) - 1999, 2000);
  if Length(Suffix) > 500 then
    Suffix := Copy(Suffix, 1, 500);

  Screen.Cursor := crHourGlass;
  FCompletionRunning := True;

  FCompletionClient.SendCompletionAsync(Prefix, Suffix,
    procedure(const AResult, AError: string)
    var
      View: IOTAEditView;
      Completion: string;
    begin
      FCompletionRunning := False;
      Screen.Cursor := crDefault;
      if AError <> '' then
      begin
        ShowMessage('Code completion error:' + sLineBreak + AError);
        Exit;
      end;
      if Trim(AResult) = '' then
      begin
        ShowMessage('The model returned no completion.' + sLineBreak +
          'Try a different model in Settings > Ollama (Local) > Completion Model.' + sLineBreak +
          'Model used: ' + GSettings.OllamaCompletionModel);
        Exit;
      end;
      if SrcEditor.EditViewCount = 0 then
        Exit;
      Completion := AResult;
      // Remove cursor marker if the model echoed it back
      Completion := StringReplace(Completion, '<|cursor|>', '', [rfReplaceAll]);
      // Strip explanations / extract from code fences (handles deepseek-coder etc.)
      Completion := CleanCompletion(Completion);
      // Strip leading line break the model may add
      while (Length(Completion) > 0) and (Completion[1] in [#13, #10]) do
        Delete(Completion, 1, 1);
      // Strip echoed partial line: models often repeat the incomplete line
      // from the prefix at the start of their output (e.g. "X := " → "X := value").
      // TrimLeft because the model usually omits leading whitespace.
      if (PartialLine <> '') and
         (Length(Completion) >= Length(PartialLine)) and
         (Copy(Completion, 1, Length(PartialLine)) = PartialLine) then
        Delete(Completion, 1, Length(PartialLine));
      if Trim(Completion) = '' then
        Exit;
      // Sanity check: reject if the model regenerated the whole unit file.
      // A valid inline completion never starts with "unit <Name>" or contains
      // the standalone "interface" / "implementation" section keywords.
      if (Copy(TrimLeft(Completion), 1, 5) = 'unit ') or
         (Pos(#10'interface'#10, Completion) > 0) or
         (Pos(#10'implementation'#10, Completion) > 0) then
      begin
        ShowMessage('The model generated an entire unit instead of a completion.' + sLineBreak +
          'Consider using a smaller, faster model designed for code completion' + sLineBreak +
          '(e.g. codellama:7b or qwen2.5-coder:1.5b).');
        Exit;
      end;
      View := SrcEditor.EditViews[0];
      View.Position.InsertText(Completion);
      View.Paint;
    end);
end;

end.
