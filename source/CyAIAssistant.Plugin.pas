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
  System.SysUtils, System.Classes,
  Vcl.Menus, Vcl.ActnList, Vcl.ExtCtrls,
  ToolsAPI;

type
  TCyAIAssistantPlugin = class
  private
    // Tools menu items
    FMenuItemSettings: TMenuItem;
    FMenuItemNewUnit: TMenuItem;
    FMenuItemSftpSync: TMenuItem; // enabled only when a project is open
    FMenuItemCodeAssist: TMenuItem; // enabled only when an editor file is open
    FSeparator: TMenuItem;

    // Editor popup hook
    FEditorPopupMenu: TPopupMenu;
    FSavedPopupMethod: TNotifyEvent;

    FTimer: TTimer;
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
    function HasOpenProject: Boolean;
    function FindEditorPopup: TPopupMenu;
    function GetSelectedText: string;
    function GetCurrentEditor: IOTASourceEditor;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  Vcl.Dialogs, Vcl.Forms,
  CyAIAssistant.PromptDialog,
  CyAIAssistant.NewUnitDialog,
  CyAIAssistant.ChatDialog,
  CyAIAssistant.Settings,
  CyAIAssistant.SettingsDialog,
  CyAIAssistant.SftpSyncDialog,
  CyAIAssistant.AboutDialog;

// TCyAIAssistantPlugin

constructor TCyAIAssistantPlugin.Create;
begin
  inherited;
  FInstalled := False;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 500;
  FTimer.OnTimer := OnTimer;
  FTimer.Enabled := True;
end;

destructor TCyAIAssistantPlugin.Destroy;
begin
  // Disable timer immediately to prevent any pending callbacks firing
  // after we start tearing down.  Free it before touching anything else.
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
  FMenuItemSettings := nil; // owned by FMenuItemNewUnit — freed with it

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
  Dlg: TPromptDialog;
begin
  SelectedText := GetSelectedText;
  if Length(Trim(SelectedText)) = 0 then
  begin
    ShowMessage('No text selected.' + sLineBreak + 'Please select some source code in the editor first.');
    Exit;
  end;
  Dlg := TPromptDialog.Create(nil, SelectedText, GetCurrentEditor);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TCyAIAssistantPlugin.OnAIAssistFromToolsClick(Sender: TObject);
begin
  OnAIAssistClick(Sender);
end;

procedure TCyAIAssistantPlugin.OnNewUnitClick(Sender: TObject);
var
  Dlg: TNewUnitDialog;
begin
  Dlg := TNewUnitDialog.Create(nil);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
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

procedure TCyAIAssistantPlugin.OnChatClick(Sender: TObject);
var
  Dlg: TChatDialog;
begin
  Dlg := TChatDialog.Create(nil);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

end.
