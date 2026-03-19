unit CyAIAssistant.ChatDialog;

// CyAIAssistant.ChatDialog.pas
//
// Multi-turn AI chat dialog with automatic detection of Delphi project files
// embedded in the AI response and a save-to-disk facility.
//
// File detection
// --------------
// The AI is instructed to wrap each file in a fenced block whose opening line
// includes the filename, e.g.:  ```pascal MyUnit.pas
// The parser also recognises bare "unit X;" / "program X;" declarations.
//
// Detected file types: .pas .dpr .dpk .dfm .dproj .groupproj .ini .txt

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs, Vcl.Graphics,
  CyAIAssistant.Settings,
  CyAIAssistant.AIClient;

type
  TDetectedFile = record
    FileName: string;
    Content: string;
  end;

  TChatDialog = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    LabelProvider: TLabel;
    LabelModel: TLabel;
    ComboProvider: TComboBox;
    EditModel: TEdit;
    BtnNewChat: TButton;
    PanelMain: TPanel;
    PanelChat: TPanel;
    PageControl: TPageControl;
    TabChat: TTabSheet;
    LabelInput: TLabel;
    MemoInput: TMemo;
    PanelChatBtns: TPanel;
    LabelStatus: TLabel;
    BtnSend: TButton;
    BtnStop: TButton;
    BtnClearInput: TButton;
    ProgressBar: TProgressBar;
    TabFiles: TTabSheet;
    PanelFileLeft: TPanel;
    LabelFiles: TLabel;
    ListFiles: TListBox;
    SplitterFiles: TSplitter;
    MemoFilePreview: TMemo;
    PanelFileBtns: TPanel;
    BtnSaveSelected: TButton;
    BtnSaveAll: TButton;
    BtnOpenInIDE: TButton;
    SplitterMain: TSplitter;
    PanelHistory: TPanel;
    LabelHistory: TLabel;
    RichHistory: TRichEdit;
    procedure ComboProviderChange(Sender: TObject);
    procedure BtnNewChatClick(Sender: TObject);
    procedure BtnSendClick(Sender: TObject);
    procedure BtnStopClick(Sender: TObject);
    procedure BtnClearInputClick(Sender: TObject);
    procedure ListFilesClick(Sender: TObject);
    procedure BtnSaveSelectedClick(Sender: TObject);
    procedure BtnSaveAllClick(Sender: TObject);
    procedure BtnOpenInIDEClick(Sender: TObject);
  private
    FAIClient: TAIClient;
    FHistory: TList<TChatMessage>;
    FDetectedFiles: TList<TDetectedFile>;
    FBusy: Boolean;
    procedure SetBusy(ABusy: Boolean);
    procedure UpdateModelHint;
    procedure AppendHistory(const ARole, AText: string);
    procedure ParseFilesFromResponse(const AResponse: string);
    procedure RefreshFileList;
    function SaveFileWithDialog(const AFile: TDetectedFile; const ADefaultDir: string): string;
    procedure OpenFileInIDE(const APath: string);
  public
    constructor Create(AOwner: TComponent); reintroduce;
    destructor Destroy; override;
  end;

implementation

{$R *.dfm}

uses
  Winapi.ShellAPI,
  System.IOUtils,
  System.RegularExpressions,
  ToolsAPI,
  CyAIAssistant.IDETheme;

constructor TChatDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAIClient := TAIClient.Create;
  FHistory := TList<TChatMessage>.Create;
  FDetectedFiles := TList<TDetectedFile>.Create;

  ComboProvider.ItemIndex := Ord(GSettings.Provider);
  UpdateModelHint;
  ActiveControl := MemoInput;

  ApplyIDETheme(Self);
end;

destructor TChatDialog.Destroy;
begin
  FAIClient.Free;
  FHistory.Free;
  FDetectedFiles.Free;
  inherited;
end;

procedure TChatDialog.UpdateModelHint;
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

procedure TChatDialog.ComboProviderChange(Sender: TObject);
begin
  GSettings.Provider := TAIProvider(ComboProvider.ItemIndex);
  UpdateModelHint;
end;

procedure TChatDialog.SetBusy(ABusy: Boolean);
begin
  FBusy := ABusy;
  BtnSend.Enabled := not ABusy;
  BtnStop.Enabled := ABusy;
  BtnNewChat.Enabled := not ABusy;
  ProgressBar.Visible := ABusy;
  if ABusy then
    ProgressBar.Style := pbstMarquee
  else
    ProgressBar.Style := pbstNormal;
end;

// ---------------------------------------------------------------------------
// FormatAIText
// Converts the raw AI response text into something readable:
// - Converts markdown pipe-table rows (| col | col |) into indented lines
// - Replaces || separators with line breaks
// - Strips leading/trailing ** bold markers (rendered via font style instead)
// - Collapses sequences of 3+ blank lines to a single blank line
// ---------------------------------------------------------------------------
function FormatAIText(const AText: string): string;
var
  Lines: TStringList;
  Out : TStringList;
  i: Integer;
  Line: string;
  Trimmed: string;
  Parts: TArray<string>;
  Col: string;
  Row: string;
  Blanks: Integer;
  c: String;
  Expanded: String;
begin
  Lines := TStringList.Create;
  Out := TStringList.Create;
  try
    // First pass: split || into separate lines
    Expanded := AText.Replace(' || ', #13#10);
    Lines.Text := Expanded;

    Blanks := 0;
    for i := 0 to Lines.Count - 1 do
    begin
      Line := Lines[i];
      Trimmed := Trim(Line);

      // Markdown table separator rows (---|---) -- skip entirely
      if (Trimmed <> '') and (Trimmed.Replace('-', '').Replace('|', '').Replace('+', '').Replace(' ', '') = '') then
        Continue;

      // Markdown table rows: | col | col | col |
      if (Length(Trimmed) > 1) and (Trimmed[1] = '|') then
      begin
        Parts := Trimmed.Trim(['|']).Split(['|']);
        Row := '';
        for Col in Parts do
        begin
          c := Trim(Col);
          if c <> '' then
            Row := Row + '  ' + c;
        end;
        if Trim(Row) <> '' then
        begin
          Out.Add(Trim(Row));
          Blanks := 0;
        end;
        Continue;
      end;

      // Blank line throttling
      if Trimmed = '' then
      begin
        Inc(Blanks);
        if Blanks <= 1 then
          Out.Add('');
        Continue;
      end;

      Blanks := 0;
      Out.Add(Line);
    end;

    Result := Out.Text;

    // Trim a trailing blank line that TStringList.Text appends
    while Result.EndsWith(#13#10#13#10) do
      Result := Copy(Result, 1, Length(Result) - 2);

  finally
    Lines.Free;
    Out.Free;
  end;
end;

// ---------------------------------------------------------------------------
// RichAppend  --  append styled text to RichHistory without flicker
// ---------------------------------------------------------------------------
procedure RichAppend(Rich: TRichEdit; const AText: string; ABold: Boolean; AColor: TColor; AFontHeight: Integer = -25);
begin
  Rich.SelStart := Length(Rich.Text);
  Rich.SelLength := 0;
  // Style and Height are set before Color.
  // Each SelAttributes setter does a GetAttributes / SetAttributes round-trip
  // (EM_GETCHARFORMAT then EM_SETCHARFORMAT). After ApplyIDETheme the control's
  // default format carries CFE_AUTOCOLOR; the Style setter reads that back and
  // re-sends it, silently overwriting whatever Color we had just set.
  // Setting Color last guarantees it is the active insertion-point format when
  // EM_REPLACESEL fires.
  if ABold then
    Rich.SelAttributes.Style := [fsBold]
  else
    Rich.SelAttributes.Style := [];
  Rich.SelAttributes.Height := AFontHeight;
  Rich.SelAttributes.Color := AColor;  // must be last
  Rich.SelText := AText + #13#10;
end;

procedure TChatDialog.AppendHistory(const ARole, AText: string);
const
  COLOR_YOU = $00E8A020; // amber -- [You] header
  COLOR_AI = $0040C080; // teal -- [AI] header
var
  HeaderColor: TColor;
  Formatted: string;
  LTextColor: TColor;
begin
  // Header line
  if SameText(ARole, 'You') then
    HeaderColor := COLOR_YOU
  else
    HeaderColor := COLOR_AI;

  LTextColor := GetIDEThemeGetColor(clWindowText);

  RichAppend(RichHistory, '[' + ARole + ']', True, HeaderColor, -25);

  // Body text -- preprocessed
  Formatted := FormatAIText(AText);
  RichAppend(RichHistory, Formatted, False, LTextColor, -23);

  // Scroll to bottom
  SendMessage(RichHistory.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

// ---------------------------------------------------------------------------
// Send
// ---------------------------------------------------------------------------

procedure TChatDialog.BtnSendClick(Sender: TObject);
var
  UserText: string;
  Msg: TChatMessage;
  History: TArray<TChatMessage>;
  i: Integer;
begin
  if FBusy then
    Exit;
  UserText := Trim(MemoInput.Text);
  if UserText = '' then
    Exit;

  Msg.Role := crUser;
  Msg.Content := UserText;
  FHistory.Add(Msg);
  AppendHistory('You', UserText);
  MemoInput.Clear;

  SetLength(History, FHistory.Count);
  for i := 0 to FHistory.Count - 1 do
    History[i] := FHistory[i];

  SetBusy(True);
  LabelStatus.Caption := 'Thinking...';

  FAIClient.SendChatAsync(History,
    procedure(const AResult, AError: string)
    var
      AssistantMsg: TChatMessage;
    begin
      SetBusy(False);
      LabelStatus.Caption := '';

      if AError <> '' then
      begin
        AppendHistory('Error', AError);
        Exit;
      end;

      AssistantMsg.Role := crAssistant;
      AssistantMsg.Content := AResult;
      FHistory.Add(AssistantMsg);

      AppendHistory('AI', AResult);

      ParseFilesFromResponse(AResult);
      RefreshFileList;
      if FDetectedFiles.Count > 0 then
      begin
        TabFiles.TabVisible := True;
        PageControl.ActivePage := TabFiles;
      end;
    end);
end;

procedure TChatDialog.BtnStopClick(Sender: TObject);
begin
  FAIClient.Cancel;
  SetBusy(False);
  LabelStatus.Caption := '';
  AppendHistory('System', '[Request cancelled by user]');
end;

procedure TChatDialog.BtnClearInputClick(Sender: TObject);
begin
  MemoInput.Clear;
end;

procedure TChatDialog.BtnNewChatClick(Sender: TObject);
begin
  if FBusy then
    Exit;
  if (FHistory.Count > 0) and (MessageDlg('Start a new chat? The current conversation will be cleared.', mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  FHistory.Clear;
  FDetectedFiles.Clear;
  RichHistory.Clear;
  ListFiles.Clear;
  MemoFilePreview.Clear;
  TabFiles.TabVisible := False;
  PageControl.ActivePage := TabChat;
end;

// ---------------------------------------------------------------------------
// File detection
// ---------------------------------------------------------------------------

procedure TChatDialog.ParseFilesFromResponse(const AResponse: string);
const
  KNOWN_EXTS: array [0 .. 7] of string = ('.pas', '.dpr', '.dpk', '.dfm', '.dproj', '.groupproj', '.ini', '.txt');
var
  Lines: TStringList;
  i, J: Integer;
  Line: string;
  InFence: Boolean;
  FenceFile: string;
  ContentSB: TStringBuilder;
  DF: TDetectedFile;
  FenceLine: string;
  Parts: TArray<string>;
  CandExt: string;
  ValidExt: Boolean;
  Content: string;

  function GuessNameFromContent(const AContent: string): string;
  var
    M: TMatch;
    Kind: string;
    Name: string;
  begin
    Result := '';
    M := TRegEx.Match(AContent, '^\s*(unit|program|package)\s+([A-Za-z0-9_.]+)\s*;', [roIgnoreCase, roMultiLine]);
    if M.Success then
    begin
      Kind := LowerCase(M.Groups[1].Value);
      Name := M.Groups[2].Value;
      if Kind = 'program' then
        Result := Name + '.dpr'
      else if Kind = 'package' then
        Result := Name + '.dpk'
      else
        Result := Name + '.pas';
    end;
  end;

begin
  Lines := TStringList.Create;
  try
    Lines.Text := AResponse;
    InFence := False;
    FenceFile := '';
    ContentSB := TStringBuilder.Create;
    try
      for i := 0 to Lines.Count - 1 do
      begin
        Line := Lines[i];

        if not InFence then
        begin
          if (Length(Trim(Line)) >= 3) and (Copy(Trim(Line), 1, 3) = '```') then
          begin
            FenceLine := Trim(Copy(Trim(Line), 4, MaxInt));
            Parts := FenceLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
            FenceFile := '';
            for J := 0 to High(Parts) do
            begin
              CandExt := LowerCase(TPath.GetExtension(Parts[J]));
              ValidExt := False;
              for var Ext in KNOWN_EXTS do
                if CandExt = Ext then
                begin
                  ValidExt := True;
                  Break;
                end;
              if ValidExt then
              begin
                FenceFile := Parts[J];
                Break;
              end;
            end;
            InFence := True;
            ContentSB.Clear;
          end;
        end
        else
        begin
          if Trim(Line) = '```' then
          begin
            Content := ContentSB.ToString;
            if Trim(Content) <> '' then
            begin
              if FenceFile = '' then
                FenceFile := GuessNameFromContent(Content);
              if FenceFile <> '' then
              begin
                DF.FileName := FenceFile;
                DF.Content := Content;
                FDetectedFiles.Add(DF);
              end;
            end;
            InFence := False;
            FenceFile := '';
          end
          else
          begin
            if ContentSB.Length > 0 then
              ContentSB.AppendLine;
            ContentSB.Append(Line);
          end;
        end;
      end;
    finally
      ContentSB.Free;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TChatDialog.RefreshFileList;
var
  i, SelIdx: Integer;
begin
  SelIdx := ListFiles.ItemIndex;
  ListFiles.Clear;
  for i := 0 to FDetectedFiles.Count - 1 do
    ListFiles.Items.Add(FDetectedFiles[i].FileName);
  if (SelIdx >= 0) and (SelIdx < ListFiles.Count) then
    ListFiles.ItemIndex := SelIdx;
end;

procedure TChatDialog.ListFilesClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := ListFiles.ItemIndex;
  if (Idx < 0) or (Idx >= FDetectedFiles.Count) then
  begin
    MemoFilePreview.Clear;
    Exit;
  end;
  MemoFilePreview.Text := FDetectedFiles[Idx].Content;
end;

// ---------------------------------------------------------------------------
// Save / Open in IDE
// ---------------------------------------------------------------------------

function TChatDialog.SaveFileWithDialog(const AFile: TDetectedFile; const ADefaultDir: string): string;
var
  Dlg: TSaveDialog;
begin
  Result := '';
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title := 'Save ' + AFile.FileName;
    Dlg.FileName := AFile.FileName;
    if ADefaultDir <> '' then
      Dlg.InitialDir := ADefaultDir;
    Dlg.Filter := 'Pascal Files (*.pas)|*.pas|' + 'Delphi Project (*.dpr)|*.dpr|' + 'Package (*.dpk)|*.dpk|' + 'Form File (*.dfm)|*.dfm|' +
      'Project File (*.dproj)|*.dproj|' + 'All Files (*.*)|*.*';
    if Dlg.Execute then
    begin
      TFile.WriteAllText(Dlg.FileName, AFile.Content, TEncoding.UTF8);
      Result := Dlg.FileName;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TChatDialog.BtnSaveSelectedClick(Sender: TObject);
var
  Idx: Integer;
  Path: string;
begin
  Idx := ListFiles.ItemIndex;
  if (Idx < 0) or (Idx >= FDetectedFiles.Count) then
  begin
    ShowMessage('Please select a file from the list first.');
    Exit;
  end;
  Path := SaveFileWithDialog(FDetectedFiles[Idx], '');
  if Path <> '' then
    ShowMessage('Saved: ' + Path);
end;

procedure TChatDialog.BtnSaveAllClick(Sender: TObject);
var
  DirDlg: TFileOpenDialog;
  Dir: string;
  i, Saved: Integer;
  Path: string;
begin
  if FDetectedFiles.Count = 0 then
  begin
    ShowMessage('No files detected yet.');
    Exit;
  end;

  DirDlg := TFileOpenDialog.Create(nil);
  try
    DirDlg.Title := 'Choose folder to save all files';
    DirDlg.Options := [fdoPickFolders];
    if not DirDlg.Execute then
      Exit;
    Dir := DirDlg.FileName;
  finally
    DirDlg.Free;
  end;

  Saved := 0;
  for i := 0 to FDetectedFiles.Count - 1 do
  begin
    Path := TPath.Combine(Dir, FDetectedFiles[i].FileName);
    if TFile.Exists(Path) then
      if MessageDlg('Overwrite existing file?' + sLineBreak + Path, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
        Continue;
    TFile.WriteAllText(Path, FDetectedFiles[i].Content, TEncoding.UTF8);
    Inc(Saved);
  end;
  ShowMessage(Format('%d of %d file(s) saved to:' + sLineBreak + Dir, [Saved, FDetectedFiles.Count]));
end;

procedure TChatDialog.BtnOpenInIDEClick(Sender: TObject);
var
  Idx: Integer;
  Path: string;
begin
  Idx := ListFiles.ItemIndex;
  if (Idx < 0) or (Idx >= FDetectedFiles.Count) then
  begin
    ShowMessage('Please select a file from the list first.');
    Exit;
  end;
  Path := SaveFileWithDialog(FDetectedFiles[Idx], '');
  if Path = '' then
    Exit;
  OpenFileInIDE(Path);
end;

procedure TChatDialog.OpenFileInIDE(const APath: string);
var
  ActionSvc: IOTAActionServices;
begin
  if not Supports(BorlandIDEServices, IOTAActionServices, ActionSvc) then
  begin
    ShellExecute(0, 'open', PChar(APath), nil, nil, SW_SHOWNORMAL);
    Exit;
  end;
  ActionSvc.OpenFile(APath);
end;

end.
