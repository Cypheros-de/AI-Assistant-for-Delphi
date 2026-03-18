unit CyAIAssistant.Register;

// CyAIAssistant.Register.pas
//
// This unit's initialization section is the ONLY entry point that Delphi
// calls when a design-time package (.dpk/.bpl) is loaded by the IDE.
//
// It registers the wizard with IOTAWizardServices, which causes
// TCyAIAssistantWizard.Create to run, which creates TCyAIAssistantPlugin,
// which installs the menu items.
//
// The wizard index is saved so we can cleanly unregister in finalization.

interface

implementation

uses
  ToolsAPI,
  CyAIAssistant.Wizard,
  CyAIAssistant.IDETheme,
  CyAIAssistant.PromptDialog,
  CyAIAssistant.NewUnitDialog,
  CyAIAssistant.DiffViewer,
  CyAIAssistant.SettingsDialog,
  CyAIAssistant.AboutDialog,
  CyAIAssistant.ChatDialog,
  CyAIAssistant.SftpSyncDialog;

var
  WizardIndex: Integer = -1;

initialization

// Guard: only register if the IDE services are available
if BorlandIDEServices <> nil then
begin
  // Register form classes for IDE theme styling
  RegisterIDEThemeForm(TPromptDialog);
  RegisterIDEThemeForm(TDiffViewerForm);
  RegisterIDEThemeForm(TNewUnitDialog);
  RegisterIDEThemeForm(TSettingsDialog);
  RegisterIDEThemeForm(TAboutDialog);
  RegisterIDEThemeForm(TChatDialog);
  RegisterIDEThemeForm(TSftpSyncDialog);

  WizardIndex := (BorlandIDEServices as IOTAWizardServices).AddWizard(TCyAIAssistantWizard.Create);
end;

finalization

// BorlandIDEServices may already be nil if the IDE is shutting down
// (the services object is released before packages are unloaded).
// Calling RemoveWizard in that case causes an AV in rtl280.bpl.
if (WizardIndex >= 0) and (BorlandIDEServices <> nil) then
begin
  try
    (BorlandIDEServices as IOTAWizardServices).RemoveWizard(WizardIndex);
  except
    // Swallow any residual AV during late-stage IDE teardown
  end;
  WizardIndex := -1;
end;

end.
