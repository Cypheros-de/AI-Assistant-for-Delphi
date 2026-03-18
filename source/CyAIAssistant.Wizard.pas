unit CyAIAssistant.Wizard;

// CyAIAssistant.Wizard.pas
// Implements the IOTAWizard interface required for Delphi IDE plugin registration.

interface

uses
  System.SysUtils,
  ToolsAPI,
  CyAIAssistant.Plugin;

type
  TCyAIAssistantWizard = class(TInterfacedObject, IOTANotifier, IOTAWizard)
  private
    FPlugin: TCyAIAssistantPlugin;
  public
    constructor Create;
    destructor Destroy; override;

    // IOTANotifier (required by IOTAWizard inheritance chain)
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    // IOTAWizard
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

implementation

// TCyAIAssistantWizard

constructor TCyAIAssistantWizard.Create;
begin
  inherited;
  FPlugin := TCyAIAssistantPlugin.Create;
end;

destructor TCyAIAssistantWizard.Destroy;
begin
  try
    FreeAndNil(FPlugin);
  except
    FPlugin := nil;
  end;
  inherited;
end;

// IOTANotifier — required stubs
procedure TCyAIAssistantWizard.AfterSave;
begin
end;

procedure TCyAIAssistantWizard.BeforeSave;
begin
end;

procedure TCyAIAssistantWizard.Destroyed;
begin
end;

procedure TCyAIAssistantWizard.Modified;
begin
end;

procedure TCyAIAssistantWizard.Execute;
begin
  // Not used for menu-based wizard
end;

function TCyAIAssistantWizard.GetIDString: string;
begin
  Result := 'com.aiassist.delphi.plugin';
end;

function TCyAIAssistantWizard.GetName: string;
begin
  Result := 'Cypheros AI Assistant';
end;

function TCyAIAssistantWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

end.
