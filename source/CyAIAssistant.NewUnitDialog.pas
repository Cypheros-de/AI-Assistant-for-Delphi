unit CyAIAssistant.NewUnitDialog;

// CyAIAssistant.NewUnitDialog.pas
// Generate a brand-new Delphi unit from a plain-English description.

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs,
  ToolsAPI,
  CyAIAssistant.Settings,
  CyAIAssistant.AIClient, CyAIAssistant.DonutGraph;

type
  TNewUnitDialog = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelProvider: TPanel;
    LabelProvider: TLabel;
    LabelModel: TLabel;
    ComboProvider: TComboBox;
    EditModel: TEdit;
    PanelBottom: TPanel;
    LabelStatus: TLabel;
    BtnGenerate: TButton;
    BtnStop: TButton;
    BtnCreateUnit: TButton;
    BtnClose: TButton;
    ProgressBar: TProgressBar;
    PanelMain: TPanel;
    PanelLeft: TPanel;
    LabelStyle: TLabel;
    LabelDesc: TLabel;
    ListStyle: TListBox;
    MemoDesc: TMemo;
    SplitterMain: TSplitter;
    PanelRight: TPanel;
    LabelResult: TLabel;
    MemoResult: TMemo;
    PaintBox1: TPaintBox;
    procedure ComboProviderChange(Sender: TObject);
    procedure BtnGenerateClick(Sender: TObject);
    procedure BtnStopClick(Sender: TObject);
    procedure BtnCreateUnitClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    procedure MemoResultChange(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
  private
    FAIClient: TAIClient;
    FLastResult: string;

    FCPUUsage: Single;
    FGPUUsage: Single;
    FVRAMUsage: Single;
    FVRAM_MB: Cardinal;
    FVRAM_MBUsed: Cardinal;
    FHasGPU: Boolean;
    FCPUDonut: TDonutGraph;
    FGPUDonut: TDonutGraph;
    FVRAMDonut: TDonutGraph;

    procedure SetBusy(ABusy: Boolean);
    procedure UpdateModelHint;
    function BuildPrompt: string;
    procedure CreateIDEUnit(const ASource: string);
  public
    constructor Create(AOwner: TComponent); reintroduce;
    destructor Destroy; override;
    procedure SetMonitorValues(CPUUsage, GPUUsage, VRAMUsage: Single; VRAM_MB, VRAM_MBUsed: Cardinal ; HasGPU: Boolean);
  end;

implementation

{$R *.dfm}

uses
  CyAIAssistant.IDETheme, CyAIAssistant.UsagePresent;

const
STYLES:
array [0 .. 4] of record Name: string;
Template:
string;
end
= ((Name: 'Full Unit'; Template: 'Write a complete, compilable Delphi unit based on the following description.' + sLineBreak +
  'Include the unit header, interface section with type declarations, ' + 'and a full implementation. Add brief doc comments.' + sLineBreak +
  'Return ONLY the Pascal source code, no explanation:' + sLineBreak + sLineBreak + '{DESC}'), (Name: 'Class Only';
  Template: 'Write a single Delphi class (interface + implementation) based on the following description.' + sLineBreak +
  'Wrap it in a minimal compilable unit. Add brief doc comments.' + sLineBreak + 'Return ONLY the Pascal source code, no explanation:' + sLineBreak + sLineBreak
  + '{DESC}'), (Name: 'Interface + Stub'; Template: 'Write a Delphi unit with a fully declared interface section (types, method signatures) ' +
  'and stub implementations (empty bodies with TODO comments) based on the description.' + sLineBreak + 'Return ONLY the Pascal source code, no explanation:' +
  sLineBreak + sLineBreak + '{DESC}'), (Name: 'Unit Tests'; Template: 'Write a DUnitX test unit for a Delphi class described below.' + sLineBreak +
  'Include [Test] methods covering the main scenarios and edge cases.' + sLineBreak + 'Return ONLY the Pascal source code, no explanation:' + sLineBreak +
  sLineBreak + '{DESC}'), (Name: 'Free Prompt'; Template: '{DESC}'));

constructor TNewUnitDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAIClient := TAIClient.Create;
  ComboProvider.ItemIndex := Ord(GSettings.Provider);
  ListStyle.ItemIndex := 0;
  UpdateModelHint;

  FCPUUsage := 0;
  FGPUUsage := 0;
  FVRAMUsage:= 0;
  FVRAM_MB  := 0;
  FVRAM_MBUsed:= 0;
  FHasGPU := False;
  FCPUDonut := TDonutGraph.Create;
  FGPUDonut := TDonutGraph.Create;
  FVRAMDonut:= TDonutGraph.Create;
  UpdateDonutsGraphs(FCPUDonut, FGPUDonut, FVRAMDonut, FHasGPU, FCPUUsage, FGPUUsage, FVRAMUsage, Paintbox1.Height);

  ApplyIDETheme(Self);
end;

destructor TNewUnitDialog.Destroy;
begin
  FAIClient.Free;
  FCPUDonut.Free;
  FGPUDonut.Free;
  FVRAMDonut.Free;
  inherited;
end;

procedure TNewUnitDialog.UpdateModelHint;
begin
  case GSettings.Provider of
    apClaude:
      EditModel.Text := GSettings.ClaudeModel;
    apOpenAI:
      EditModel.Text := GSettings.OpenAIModel;
    apOllama:
      EditModel.Text := GSettings.OllamaModel;
    apGroq:
      EditModel.Text := GSettings.GroqModel;
    apMistral:
      EditModel.Text := GSettings.MistralModel;
  end;
end;

procedure TNewUnitDialog.ComboProviderChange(Sender: TObject);
begin
  GSettings.Provider := TAIProvider(ComboProvider.ItemIndex);
  UpdateModelHint;
end;

procedure TNewUnitDialog.SetBusy(ABusy: Boolean);
begin
  BtnGenerate.Enabled := not ABusy;
  BtnStop.Enabled := ABusy;
  BtnCreateUnit.Enabled := (not ABusy) and (Trim(MemoResult.Text) <> '');
  ProgressBar.Visible := ABusy;
  LabelStatus.Caption := '';
end;

procedure TNewUnitDialog.SetMonitorValues(CPUUsage, GPUUsage, VRAMUsage: Single; VRAM_MB, VRAM_MBUsed: Cardinal; HasGPU: Boolean);
begin
  FCPUUsage := CPUUsage;
  FGPUUsage := GPUUsage;
  FVRAMUsage:= VRAMUsage;
  FVRAM_MB  := VRAM_MB;
  FVRAM_MBUsed := VRAM_MBUsed;
  FHasGPU   := HasGPU;
  UpdateDonutsGraphs(FCPUDonut, FGPUDonut, FVRAMDonut, FHasGPU, FCPUUsage, FGPUUsage, FVRAMUsage, Paintbox1.Height);
  Paintbox1.Invalidate;
end;

procedure TNewUnitDialog.BtnStopClick(Sender: TObject);
begin
  FAIClient.Cancel;
  SetBusy(False);
  LabelStatus.Caption := 'Cancelled.';
end;

function TNewUnitDialog.BuildPrompt: string;
var
  Idx: Integer;
  Desc: string;
begin
  Idx := ListStyle.ItemIndex;
  if Idx < 0 then
    Idx := 0;
  Desc := Trim(MemoDesc.Text);
  Result := StringReplace(STYLES[Idx].Template, '{DESC}', Desc, [rfReplaceAll]);
end;

procedure TNewUnitDialog.BtnGenerateClick(Sender: TObject);
var
  Prompt: string;
begin
  if Trim(MemoDesc.Text) = '' then
  begin
    ShowMessage('Please describe the unit you want to generate.');
    Exit;
  end;

  case GSettings.Provider of
    apClaude:
      GSettings.ClaudeModel := Trim(EditModel.Text);
    apOpenAI:
      GSettings.OpenAIModel := Trim(EditModel.Text);
    apOllama:
      GSettings.OllamaModel := Trim(EditModel.Text);
    apGroq:
      GSettings.GroqModel := Trim(EditModel.Text);
    apMistral:
      GSettings.MistralModel := Trim(EditModel.Text);
  end;

  Prompt := BuildPrompt;
  SetBusy(True);
  MemoResult.Text := '';
  FLastResult := '';
  LabelStatus.Caption := 'Generating - please wait...';
  Application.ProcessMessages;

  FAIClient.SendAsync(Prompt,
    procedure(const AResult, AError: string)
    begin
      SetBusy(False);
      if AError <> '' then
      begin
        LabelStatus.Caption := 'Error.';
        ShowMessage('AI Error:' + sLineBreak + AError);
        Exit;
      end;
      if Trim(AResult) = '' then
      begin
        LabelStatus.Caption := 'Empty response.';
        ShowMessage('The AI returned an empty response.');
        Exit;
      end;
      FLastResult := AResult;
      MemoResult.Text := StringReplace(StringReplace(AResult, #13#10, #10, [rfReplaceAll]), #10, #13#10, [rfReplaceAll]);
      BtnCreateUnit.Enabled := True;
      LabelStatus.Caption := 'Done. Review and click "Create Unit in IDE".';
    end);
end;

procedure TNewUnitDialog.CreateIDEUnit(const ASource: string);
var
  ActionSvc: IOTAActionServices;
  TempFile: string;
  SL: TStringList;
  Normalised: string;
begin
  Normalised := StringReplace(StringReplace(ASource, #13#10, #10, [rfReplaceAll]), #10, #13#10, [rfReplaceAll]);

  TempFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'CyAIAssistant_NewUnit.pas';
  SL := TStringList.Create;
  try
    SL.Text := Normalised;
    SL.SaveToFile(TempFile);
  finally
    SL.Free;
  end;

  if not Supports(BorlandIDEServices, IOTAActionServices, ActionSvc) then
  begin
    ShowMessage('Could not access IDE action services.' + sLineBreak + 'File saved to: ' + TempFile);
    Exit;
  end;

  if not ActionSvc.OpenFile(TempFile) then
    ShowMessage('Could not open file in IDE.' + sLineBreak + 'File saved to: ' + TempFile)
  else
    Close;
end;

procedure TNewUnitDialog.BtnCreateUnitClick(Sender: TObject);
var
  Src: string;
  I: Integer;
begin
  if Trim(FLastResult) <> '' then
    Src := FLastResult
  else
  begin
    if MemoResult.Lines.Count = 0 then
    begin
      ShowMessage('No generated code to create a unit from.');
      Exit;
    end;
    Src := '';
    for I := 0 to MemoResult.Lines.Count - 1 do
    begin
      if I > 0 then
        Src := Src + #13#10;
      Src := Src + MemoResult.Lines[I];
    end;
  end;
  if Trim(Src) = '' then
  begin
    ShowMessage('No generated code to create a unit from.');
    Exit;
  end;
  CreateIDEUnit(Src);
end;

procedure TNewUnitDialog.MemoResultChange(Sender: TObject);
begin
  FLastResult := ''; // user edited — discard raw AI result
end;

procedure TNewUnitDialog.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TNewUnitDialog.PaintBox1Paint(Sender: TObject);
begin
  PaintUsageGraphs(PaintBox1.Canvas, PaintBox1.Width, PaintBox1.Height, FCPUDonut, FGPUDonut, FVRAMDonut, FHasGPU, 'CPU', 'GPU', 'VRAM');
end;

end.
