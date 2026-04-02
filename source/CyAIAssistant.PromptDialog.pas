unit CyAIAssistant.PromptDialog;

// CyAIAssistant.PromptDialog.pas
// Main dialog: select a prompt template, preview code, submit to AI, review diff.

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Graphics,
  ToolsAPI,
  CyAIAssistant.Settings,
  CyAIAssistant.AIClient, CyAIAssistant.DonutGraph;

type
  TPromptDialog = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelProvider: TPanel;
    LabelProvider: TLabel;
    LabelModel: TLabel;
    ComboProvider: TComboBox;
    EditModel: TEdit;
    PanelBottom: TPanel;
    LabelStatus: TLabel;
    CheckStripFences: TCheckBox;
    ProgressBar: TProgressBar;
    BtnSubmit: TButton;
    BtnStop: TButton;
    BtnCancel: TButton;
    PanelLeft: TPanel;
    LabelPrompts: TLabel;
    LabelCustom: TLabel;
    ListPrompts: TListBox;
    MemoCustomPrefix: TMemo;
    Splitter: TSplitter;
    PanelRight: TPanel;
    LabelCode: TLabel;
    LabelFinal: TLabel;
    MemoCode: TMemo;
    MemoFinalPrompt: TMemo;
    PaintBox1: TPaintBox;
    procedure ComboProviderChange(Sender: TObject);
    procedure ListPromptsClick(Sender: TObject);
    procedure MemoCustomPrefixChange(Sender: TObject);
    procedure BtnSubmitClick(Sender: TObject);
    procedure BtnStopClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
  private
    FSelectedCode: string;
    FSourceEditor: IOTASourceEditor;
    FAIClient: TAIClient;

    FCPUUsage: Single;
    FGPUUsage: Single;
    FVRAMUsage: Single;
    FVRAM_MB: Cardinal;
    FVRAM_MBUsed: Cardinal;
    FHasGPU: Boolean;
    FCPUDonut: TDonutGraph;
    FGPUDonut: TDonutGraph;
    FVRAMDonut: TDonutGraph;

    procedure PopulatePrompts;
    procedure UpdateFinalPrompt;
    procedure SetBusy(ABusy: Boolean);
    function BuildFinalPrompt: string;
    procedure UpdateModelHint;
  public
    constructor Create(AOwner: TComponent; const ASelectedCode: string; ASourceEditor: IOTASourceEditor); reintroduce;
    destructor Destroy; override;
    procedure SetMonitorValues(CPUUsage, GPUUsage, VRAMUsage: Single; VRAM_MB, VRAM_MBUsed: Cardinal ; HasGPU: Boolean);
  end;

implementation

{$R *.dfm}

uses
  CyAIAssistant.DiffViewer,
  CyAIAssistant.IDETheme,
  CyAIAssistant.UsagePresent;

constructor TPromptDialog.Create(AOwner: TComponent; const ASelectedCode: string; ASourceEditor: IOTASourceEditor);
var
  Idx: Integer;
begin
  inherited Create(AOwner);
  FSelectedCode := ASelectedCode;
  FSourceEditor := ASourceEditor;
  FAIClient := TAIClient.Create;

  ComboProvider.ItemIndex := Ord(GSettings.Provider);
  MemoCode.Text := FSelectedCode;

  PopulatePrompts;
  UpdateModelHint;

  // Restore last prompt selection
  if ListPrompts.Count > 0 then
  begin
    Idx := GSettings.LastPromptIndex;
    if (Idx < 0) or (Idx >= ListPrompts.Count) then
      Idx := 0;
    ListPrompts.ItemIndex := Idx;
    UpdateFinalPrompt;
  end;

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

destructor TPromptDialog.Destroy;
begin
  FAIClient.Free;
  FCPUDonut.Free;
  FGPUDonut.Free;
  FVRAMDonut.Free;
  inherited;
end;

procedure TPromptDialog.PopulatePrompts;
var
  I: Integer;
begin
  ListPrompts.Clear;
  for I := 0 to GSettings.Prompts.Count - 1 do
    ListPrompts.Items.Add('  ' + GSettings.Prompts[I].Name);
end;

procedure TPromptDialog.UpdateModelHint;
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
    apGemini:
      EditModel.Text := GSettings.GeminiModel;
    apZai:
      EditModel.Text := GSettings.ZaiModel;
  end;
end;

procedure TPromptDialog.ComboProviderChange(Sender: TObject);
begin
  GSettings.Provider := TAIProvider(ComboProvider.ItemIndex);
  UpdateModelHint;
end;

procedure TPromptDialog.ListPromptsClick(Sender: TObject);
begin
  if ListPrompts.ItemIndex >= 0 then
  begin
    GSettings.LastPromptIndex := ListPrompts.ItemIndex;
    GSettings.Save;
  end;
  UpdateFinalPrompt;
end;

procedure TPromptDialog.MemoCustomPrefixChange(Sender: TObject);
begin
  UpdateFinalPrompt;
end;

function TPromptDialog.BuildFinalPrompt: string;
var
  Idx: Integer;
  Template: string;
begin
  Result := '';
  Idx := ListPrompts.ItemIndex;
  if (Idx < 0) or (Idx >= GSettings.Prompts.Count) then
    Exit;
  Template := GSettings.Prompts[Idx].Template;
  Result := StringReplace(Template, '{CODE}', FSelectedCode, [rfReplaceAll]);
  Result := StringReplace(Result, '{CUSTOM_PREFIX}', Trim(MemoCustomPrefix.Text), [rfReplaceAll]);
end;

procedure TPromptDialog.UpdateFinalPrompt;
begin
  MemoFinalPrompt.Text := BuildFinalPrompt;
end;

procedure TPromptDialog.SetBusy(ABusy: Boolean);
begin
  BtnSubmit.Enabled := not ABusy;
  BtnStop.Enabled := ABusy;
  ListPrompts.Enabled := not ABusy;
  ComboProvider.Enabled := not ABusy;
  ProgressBar.Visible := ABusy;
  LabelStatus.Visible := not ABusy;
  if ABusy then
    LabelStatus.Caption := 'Sending to AI...'
  else
    LabelStatus.Caption := 'Ready.';
end;

procedure TPromptDialog.SetMonitorValues(CPUUsage, GPUUsage, VRAMUsage: Single; VRAM_MB, VRAM_MBUsed: Cardinal; HasGPU: Boolean);
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

procedure TPromptDialog.BtnStopClick(Sender: TObject);
begin
  FAIClient.Cancel;
  SetBusy(False);
end;

procedure TPromptDialog.BtnSubmitClick(Sender: TObject);
var
  FinalPrompt: string;
begin
  FinalPrompt := BuildFinalPrompt;
  if Trim(FinalPrompt) = '' then
  begin
    ShowMessage('Please select a prompt template first.');
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
    apGemini:
      GSettings.GeminiModel := Trim(EditModel.Text);
    apZai:
      GSettings.ZaiModel := Trim(EditModel.Text);
  end;

  SetBusy(True);
  LabelStatus.Visible := True;
  LabelStatus.Caption := 'Sending to AI - please wait...';
  Application.ProcessMessages;

  FAIClient.SendAsync(FinalPrompt,
    procedure(const AResult, AError: string)
    var
      Viewer: TDiffViewerForm;
    begin
      SetBusy(False);

      if AError <> '' then
      begin
        ShowMessage('AI Error:' + sLineBreak + AError);
        Exit;
      end;

      if Trim(AResult) = '' then
      begin
        ShowMessage('The AI returned an empty response.');
        Exit;
      end;

      Viewer := TDiffViewerForm.Create(Self, FSelectedCode, AResult, FSourceEditor);
      try
        Viewer.ShowModal;
        if Viewer.Applied then
          Close;
      finally
        Viewer.Free;
      end;
    end);
end;

procedure TPromptDialog.BtnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TPromptDialog.PaintBox1Paint(Sender: TObject);
begin
  if GSettings.Provider = apOllama then
    PaintUsageGraphs(PaintBox1.Canvas, PaintBox1.Width, PaintBox1.Height, FCPUDonut, FGPUDonut, FVRAMDonut, FHasGPU, 'CPU', 'GPU', 'VRAM');
end;

end.
