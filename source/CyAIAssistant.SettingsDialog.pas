unit CyAIAssistant.SettingsDialog;

// CyAIAssistant.SettingsDialog.pas
// Settings UI: API keys, endpoints, models, temperature, prompt templates.

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Graphics,
  CyAIAssistant.Settings;

type
  TSettingsDialog = class(TForm)
    PanelBottom: TPanel;
    BtnOK: TButton;
    BtnCancel: TButton;
    PageControl: TPageControl;
    TabClaude: TTabSheet;
    LblClaudeKey: TLabel;
    LblClaudeModel: TLabel;
    LblClaudeEndpoint: TLabel;
    LblClaudeInfo: TLabel;
    Bevel3: TBevel;
    EditClaudeKey: TEdit;
    EditClaudeModel: TComboBox;
    EditClaudeEndpoint: TEdit;
    TabOpenAI: TTabSheet;
    LblOpenAIKey: TLabel;
    LblOpenAIModel: TLabel;
    LblOpenAIEndpoint: TLabel;
    LblOpenAIInfo: TLabel;
    Bevel4: TBevel;
    EditOpenAIKey: TEdit;
    EditOpenAIModel: TComboBox;
    EditOpenAIEndpoint: TEdit;
    TabOllama: TTabSheet;
    LblOllamaEndpoint: TLabel;
    LblOllamaModel: TLabel;
    LblOllamaInfo: TLabel;
    EditOllamaEndpoint: TEdit;
    ComboOllamaModel: TComboBox;
    BtnTestOllama: TButton;
    BtnLoadModels: TButton;
    LblOllamaCompletionModel: TLabel;
    ComboOllamaCompletionModel: TComboBox;
    ChkCodeCompletion: TCheckBox;
    TabGroq: TTabSheet;
    LblGroqKey: TLabel;
    LblGroqModel: TLabel;
    LblGroqEndpoint: TLabel;
    LblGroqInfo: TLabel;
    Bevel5: TBevel;
    EditGroqKey: TEdit;
    EditGroqModel: TComboBox;
    EditGroqEndpoint: TEdit;
    TabMistral: TTabSheet;
    LblMistralKey: TLabel;
    LblMistralModel: TLabel;
    LblMistralEndpoint: TLabel;
    LblMistralInfo: TLabel;
    Bevel6: TBevel;
    EditMistralKey: TEdit;
    EditMistralModel: TComboBox;
    EditMistralEndpoint: TEdit;
    TabGeneral: TTabSheet;
    LblDefaultProvider: TLabel;
    LblMaxTokens: TLabel;
    LblTemperature: TLabel;
    LblGeneralInfo: TLabel;
    ComboDefaultProvider: TComboBox;
    EditMaxTokens: TEdit;
    EditTemperature: TEdit;
    TabCustomPrompts: TTabSheet;
    PanelPromptsLeft: TPanel;
    LblPromptTemplates: TLabel;
    ListCustomPrompts: TListBox;
    PanelListBtns: TPanel;
    BtnMoveUp: TButton;
    BtnMoveDown: TButton;
    BtnDeletePrompt: TButton;
    PanelPromptsRight: TPanel;
    PanelPromptTop: TPanel;
    LblPromptName: TLabel;
    LblTemplate: TLabel;
    EditPromptName: TEdit;
    PanelPromptBtns: TPanel;
    BtnAddPrompt: TButton;
    BtnUpdatePrompt: TButton;
    BtnClearFields: TButton;
    MemoPromptTemplate: TMemo;
    procedure BtnOKClick(Sender: TObject);
    procedure BtnAddPromptClick(Sender: TObject);
    procedure BtnUpdatePromptClick(Sender: TObject);
    procedure BtnDeletePromptClick(Sender: TObject);
    procedure ListCustomPromptsClick(Sender: TObject);
    procedure BtnMoveUpClick(Sender: TObject);
    procedure BtnMoveDownClick(Sender: TObject);
    procedure BtnClearFieldsClick(Sender: TObject);
    procedure BtnTestOllamaClick(Sender: TObject);
    procedure BtnLoadModelsClick(Sender: TObject);
  private
    procedure LoadSettings;
    procedure SaveSettings;
    procedure RefreshPromptList;
    procedure LoadOllamaModels(ASilent: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.dfm}

uses
  System.JSON,
  System.Net.HttpClient,
  CyAIAssistant.IDETheme;

constructor TSettingsDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  LoadSettings;
  ApplyIDETheme(Self);
end;

procedure TSettingsDialog.LoadSettings;
begin
  EditClaudeKey.Text := GSettings.ClaudeAPIKey;
  EditClaudeModel.Text := GSettings.ClaudeModel;
  EditClaudeEndpoint.Text := GSettings.ClaudeEndpoint;
  EditOpenAIKey.Text := GSettings.OpenAIAPIKey;
  EditOpenAIModel.Text := GSettings.OpenAIModel;
  EditOpenAIEndpoint.Text := GSettings.OpenAIEndpoint;
  EditOllamaEndpoint.Text := GSettings.OllamaEndpoint;
  ComboOllamaModel.Text := GSettings.OllamaModel;
  ComboOllamaCompletionModel.Text := GSettings.OllamaCompletionModel;
  ChkCodeCompletion.Checked := GSettings.CodeCompletionEnabled;
  EditGroqKey.Text := GSettings.GroqAPIKey;
  EditGroqModel.Text := GSettings.GroqModel;
  EditGroqEndpoint.Text := GSettings.GroqEndpoint;
  EditMistralKey.Text := GSettings.MistralAPIKey;
  EditMistralModel.Text := GSettings.MistralModel;
  EditMistralEndpoint.Text := GSettings.MistralEndpoint;
  EditMaxTokens.Text := IntToStr(GSettings.MaxTokens);
  EditTemperature.Text := FormatFloat('0.00', GSettings.Temperature);
  ComboDefaultProvider.ItemIndex := Ord(GSettings.Provider);
  RefreshPromptList;
  // Auto-populate Ollama model list if the server is reachable; errors are
  // silently ignored so the dialog opens instantly when Ollama is not running.
  LoadOllamaModels(True);
end;

procedure TSettingsDialog.SaveSettings;
begin
  GSettings.ClaudeAPIKey := Trim(EditClaudeKey.Text);
  GSettings.ClaudeModel := Trim(EditClaudeModel.Text);
  GSettings.ClaudeEndpoint := Trim(EditClaudeEndpoint.Text);
  GSettings.OpenAIAPIKey := Trim(EditOpenAIKey.Text);
  GSettings.OpenAIModel := Trim(EditOpenAIModel.Text);
  GSettings.OpenAIEndpoint := Trim(EditOpenAIEndpoint.Text);
  GSettings.OllamaEndpoint := Trim(EditOllamaEndpoint.Text);
  GSettings.OllamaModel := Trim(ComboOllamaModel.Text);
  GSettings.OllamaCompletionModel := Trim(ComboOllamaCompletionModel.Text);
  GSettings.CodeCompletionEnabled := ChkCodeCompletion.Checked;
  GSettings.GroqAPIKey := Trim(EditGroqKey.Text);
  GSettings.GroqModel := Trim(EditGroqModel.Text);
  GSettings.GroqEndpoint := Trim(EditGroqEndpoint.Text);
  GSettings.MistralAPIKey := Trim(EditMistralKey.Text);
  GSettings.MistralModel := Trim(EditMistralModel.Text);
  GSettings.MistralEndpoint := Trim(EditMistralEndpoint.Text);
  GSettings.Provider := TAIProvider(ComboDefaultProvider.ItemIndex);
  try
    GSettings.MaxTokens := StrToIntDef(EditMaxTokens.Text, 4096);
    GSettings.Temperature := StrToFloatDef(EditTemperature.Text, 0.2);
  except
  end;
  GSettings.Save;
end;

procedure TSettingsDialog.RefreshPromptList;
var
  P: TCustomPrompt;
begin
  ListCustomPrompts.Clear;
  for P in GSettings.CustomPrompts do
    ListCustomPrompts.Items.Add(P.Name);
end;

procedure TSettingsDialog.BtnOKClick(Sender: TObject);
begin
  SaveSettings;
  ModalResult := mrOK;
end;

procedure TSettingsDialog.ListCustomPromptsClick(Sender: TObject);
var
  Idx: Integer;
  P: TCustomPrompt;
begin
  Idx := ListCustomPrompts.ItemIndex;
  if Idx < 0 then
    Exit;
  P := GSettings.CustomPrompts[Idx];
  EditPromptName.Text := P.Name;
  MemoPromptTemplate.Text := P.Template;
end;

procedure TSettingsDialog.BtnAddPromptClick(Sender: TObject);
begin
  if Trim(EditPromptName.Text) = '' then
  begin
    ShowMessage('Please enter a prompt name.');
    EditPromptName.SetFocus;
    Exit;
  end;
  if Trim(MemoPromptTemplate.Text) = '' then
  begin
    ShowMessage('Please enter the prompt template.');
    MemoPromptTemplate.SetFocus;
    Exit;
  end;
  GSettings.AddCustomPrompt(Trim(EditPromptName.Text), MemoPromptTemplate.Text);
  RefreshPromptList;
  EditPromptName.Clear;
  MemoPromptTemplate.Clear;
end;

procedure TSettingsDialog.BtnUpdatePromptClick(Sender: TObject);
var
  Idx: Integer;
  P: TCustomPrompt;
begin
  Idx := ListCustomPrompts.ItemIndex;
  if Idx < 0 then
  begin
    ShowMessage('Please select a prompt to update.');
    Exit;
  end;
  P.Name := Trim(EditPromptName.Text);
  P.Template := MemoPromptTemplate.Text;
  GSettings.CustomPrompts[Idx] := P;
  RefreshPromptList;
  ListCustomPrompts.ItemIndex := Idx;
end;

procedure TSettingsDialog.BtnDeletePromptClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := ListCustomPrompts.ItemIndex;
  if Idx < 0 then
    Exit;
  if MessageDlg('Delete this prompt template?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    GSettings.RemoveCustomPrompt(Idx);
    RefreshPromptList;
  end;
end;

procedure TSettingsDialog.BtnMoveUpClick(Sender: TObject);
var
  Idx: Integer;
  P: TCustomPrompt;
begin
  Idx := ListCustomPrompts.ItemIndex;
  if Idx <= 0 then
    Exit;
  P := GSettings.CustomPrompts[Idx];
  GSettings.CustomPrompts.Delete(Idx);
  GSettings.CustomPrompts.Insert(Idx - 1, P);
  RefreshPromptList;
  ListCustomPrompts.ItemIndex := Idx - 1;
end;

procedure TSettingsDialog.BtnMoveDownClick(Sender: TObject);
var
  Idx: Integer;
  P: TCustomPrompt;
begin
  Idx := ListCustomPrompts.ItemIndex;
  if (Idx < 0) or (Idx >= GSettings.CustomPrompts.Count - 1) then
    Exit;
  P := GSettings.CustomPrompts[Idx];
  GSettings.CustomPrompts.Delete(Idx);
  GSettings.CustomPrompts.Insert(Idx + 1, P);
  RefreshPromptList;
  ListCustomPrompts.ItemIndex := Idx + 1;
end;

procedure TSettingsDialog.BtnClearFieldsClick(Sender: TObject);
begin
  ListCustomPrompts.ItemIndex := -1;
  EditPromptName.Clear;
  EditPromptName.SetFocus;
  MemoPromptTemplate.Clear;
end;

function GetOllamaBaseURL(const AEndpoint: string): string;
begin
  Result := StringReplace(AEndpoint, '/api/chat', '', [rfReplaceAll]);
  Result := StringReplace(Result, '/api/generate', '', [rfReplaceAll]);
  while (Length(Result) > 0) and (Result[Length(Result)] = '/') do
    SetLength(Result, Length(Result) - 1);
end;

procedure TSettingsDialog.LoadOllamaModels(ASilent: Boolean);
var
  HTTP: THTTPClient;
  Response: IHTTPResponse;
  BaseURL: string;
  JSON: TJSONObject;
  Models: TJSONArray;
  ModelObj: TJSONObject;
  Name: string;
  i: Integer;
  PrevModel: string;
  PrevCompletionModel: string;
begin
  BaseURL := Trim(EditOllamaEndpoint.Text);
  if BaseURL = '' then
  begin
    if not ASilent then
      ShowMessage('Please enter the Ollama endpoint URL first.');
    Exit;
  end;
  BaseURL := GetOllamaBaseURL(BaseURL);
  PrevModel := Trim(ComboOllamaModel.Text);
  PrevCompletionModel := Trim(ComboOllamaCompletionModel.Text);
  HTTP := THTTPClient.Create;
  try
    HTTP.ConnectionTimeout := 3000;
    HTTP.ResponseTimeout := 8000;
    try
      Response := HTTP.Get(BaseURL + '/api/tags');
      if Response.StatusCode <> 200 then
      begin
        if not ASilent then
          ShowMessage('Ollama returned HTTP ' + IntToStr(Response.StatusCode));
        Exit;
      end;
      JSON := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
      if JSON = nil then
      begin
        if not ASilent then
          ShowMessage('Could not parse Ollama response.');
        Exit;
      end;
      try
        Models := JSON.GetValue('models') as TJSONArray;
        if (Models = nil) or (Models.Count = 0) then
        begin
          if not ASilent then
            ShowMessage('No models found. Pull a model first:' + sLineBreak + '  ollama pull codellama');
          Exit;
        end;
        ComboOllamaModel.Items.BeginUpdate;
        ComboOllamaCompletionModel.Items.BeginUpdate;
        try
          ComboOllamaModel.Items.Clear;
          ComboOllamaCompletionModel.Items.Clear;
          for i := 0 to Models.Count - 1 do
          begin
            ModelObj := Models.Items[i] as TJSONObject;
            if ModelObj <> nil then
            begin
              Name := ModelObj.GetValue<string>('name', '');
              if Name <> '' then
              begin
                ComboOllamaModel.Items.Add(Name);
                ComboOllamaCompletionModel.Items.Add(Name);
              end;
            end;
          end;
        finally
          ComboOllamaModel.Items.EndUpdate;
          ComboOllamaCompletionModel.Items.EndUpdate;
        end;
        if ComboOllamaModel.Items.Count > 0 then
        begin
          i := ComboOllamaModel.Items.IndexOf(PrevModel);
          if i >= 0 then
            ComboOllamaModel.ItemIndex := i
          else
            ComboOllamaModel.ItemIndex := 0;
        end;
        if ComboOllamaCompletionModel.Items.Count > 0 then
        begin
          i := ComboOllamaCompletionModel.Items.IndexOf(PrevCompletionModel);
          if i >= 0 then
            ComboOllamaCompletionModel.ItemIndex := i
          else
            ComboOllamaCompletionModel.ItemIndex := 0;
        end;
        if not ASilent then
          ShowMessage(IntToStr(ComboOllamaModel.Items.Count) + ' model(s) loaded from Ollama.');
      finally
        JSON.Free;
      end;
    except
      on E: Exception do
        if not ASilent then
          ShowMessage('ERROR: Cannot reach Ollama:' + sLineBreak + E.Message +
            sLineBreak + sLineBreak + 'Is Ollama running? Try: ollama serve');
    end;
  finally
    HTTP.Free;
  end;
end;

procedure TSettingsDialog.BtnLoadModelsClick(Sender: TObject);
begin
  LoadOllamaModels(False);
end;

procedure TSettingsDialog.BtnTestOllamaClick(Sender: TObject);
var
  HTTP: THTTPClient;
  Response: IHTTPResponse;
  URL: string;
begin
  URL := Trim(EditOllamaEndpoint.Text);
  if URL = '' then
  begin
    ShowMessage('Please enter the Ollama endpoint URL first.');
    Exit;
  end;
  URL := GetOllamaBaseURL(URL) + '/api/tags';
  HTTP := THTTPClient.Create;
  try
    HTTP.ConnectionTimeout := 5000;
    HTTP.ResponseTimeout := 10000;
    try
      Response := HTTP.Get(URL);
      if Response.StatusCode = 200 then
        ShowMessage('Ollama is reachable!' + sLineBreak + 'Click "Load Models" to populate the model list.')
      else
        ShowMessage('WARNING: Ollama responded with HTTP ' + IntToStr(Response.StatusCode));
    except
      on E: Exception do
        ShowMessage('ERROR: Cannot reach Ollama: ' + sLineBreak + E.Message + sLineBreak + sLineBreak + 'Is Ollama running? Try: ollama serve');
    end;
  finally
    HTTP.Free;
  end;
end;

end.
