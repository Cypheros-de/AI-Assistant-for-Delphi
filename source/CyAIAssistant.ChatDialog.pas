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
  System.SysUtils, System.Classes, System.Generics.Collections, System.StrUtils,
  Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Menus, Vcl.Clipbrd,
  CyAIAssistant.Settings,
  CyAIAssistant.AIClient, CyAIAssistant.DonutGraph;

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
    PanelHistoryBtn: TPanel;
    PaintBox1: TPaintBox;
    procedure ComboProviderChange(Sender: TObject);
    procedure BtnNewChatClick(Sender: TObject);
    procedure BtnSendClick(Sender: TObject);
    procedure BtnStopClick(Sender: TObject);
    procedure BtnClearInputClick(Sender: TObject);
    procedure ListFilesClick(Sender: TObject);
    procedure BtnSaveSelectedClick(Sender: TObject);
    procedure BtnSaveAllClick(Sender: TObject);
    procedure BtnOpenInIDEClick(Sender: TObject);
    procedure MenuItemCopyClick(Sender: TObject);
    procedure MenuItemSelectAllClick(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
  private
    FAIClient: TAIClient;
    FHistory: TList<TChatMessage>;
    FDetectedFiles: TList<TDetectedFile>;
    FBusy: Boolean;

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
    procedure AppendHistory(const ARole, AText: string; const ADuration: TDateTime = 0);
    procedure ParseFilesFromResponse(const AResponse: string);
    procedure RefreshFileList;
    function SaveFileWithDialog(const AFile: TDetectedFile; const ADefaultDir: string): string;
    procedure OpenFileInIDE(const APath: string);
  public
    procedure SetMonitorValues(CPUUsage, GPUUsage, VRAMUsage: Single; VRAM_MB, VRAM_MBUsed: Cardinal ; HasGPU: Boolean);
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
  CyAIAssistant.IDETheme,
  CyAIAssistant.UsagePresent;

constructor TChatDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAIClient := TAIClient.Create;
  FHistory := TList<TChatMessage>.Create;
  FDetectedFiles := TList<TDetectedFile>.Create;

  ComboProvider.ItemIndex := Ord(GSettings.Provider);
  UpdateModelHint;
  ActiveControl := MemoInput;

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

destructor TChatDialog.Destroy;
begin
  FCPUDonut.Free;
  FGPUDonut.Free;
  FVRAMDonut.Free;

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

procedure TChatDialog.SetMonitorValues(CPUUsage, GPUUsage, VRAMUsage: Single; VRAM_MB, VRAM_MBUsed: Cardinal; HasGPU: Boolean);
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
// AFontName = '' uses the control's default proportional font.
// Pass a fixed font name (e.g. 'Courier New') for code blocks.
//
// Strategy: insert the text first, then select the entire inserted range and
// apply all formatting to it.  Setting format at the insertion point before
// EM_REPLACESEL only affects the first line; subsequent lines revert to the
// control's default paragraph format.  Formatting the selection after
// insertion covers every line uniformly.
// Color is set last so it always clears CFE_AUTOCOLOR that ApplyIDETheme
// leaves in the control's default character format.
procedure RichAppend(Rich: TRichEdit; const AText: string; ABold: Boolean;
  AColor: TColor; AFontHeight: Integer = -25; const AFontName: string = '');
var
  StartPos, EndPos: Integer;
begin
  Rich.SelStart := MaxInt; // clamp to end of content
  StartPos := Rich.SelStart;
  Rich.SelLength := 0;
  Rich.SelText := AText + #13#10; // insert; cursor lands at end of inserted text

  EndPos := Rich.SelStart;

  // Select the full inserted range and apply formatting to every character.
  Rich.SelStart  := StartPos;
  Rich.SelLength := EndPos - StartPos;

  if AFontName <> '' then
    Rich.SelAttributes.Name := AFontName
  else
    Rich.SelAttributes.Name := Rich.Font.Name; // restore after a code block
  if ABold then
    Rich.SelAttributes.Style := [fsBold]
  else
    Rich.SelAttributes.Style := [];
  Rich.SelAttributes.Height := AFontHeight;
  Rich.SelAttributes.Color := AColor; // must be last
end;

procedure TChatDialog.AppendHistory(const ARole, AText: string; const ADuration: TDateTime);
const
  COLOR_YOU = $00E8A020; // amber -- [You] header
  COLOR_AI  = $0040C080; // teal  -- [AI]  header
  CODE_FONT = 'Courier New';
var
  HeaderColor, TextColor: TColor;
  Segments: TArray<string>;
  I: Integer;
  IsCode: Boolean;
  Seg, LangStrip: string;
  NL: Integer;
begin
  HeaderColor := COLOR_AI;
  if SameText(ARole, 'You') then
    HeaderColor := COLOR_YOU;
  TextColor := GetIDEThemeGetColor(clWindowText);

  if (ARole = 'You') then
    RichAppend(RichHistory, '[' + ARole + ']', True, HeaderColor, -25)
  else
    RichAppend(RichHistory, '[' + ARole + '] (' + IntToStr(Round(ADuration * 86400)) + 's)', True, HeaderColor, -25);

  // Split on ``` fence markers; even-indexed segments are prose, odd are code.
  Segments := AText.Split(['```']);
  IsCode := False;
  for I := 0 to High(Segments) do
  begin
    Seg := Segments[I];
    if IsCode then
    begin
      // Strip optional language identifier on the opening line (e.g. "pascal").
      LangStrip := Seg.TrimLeft;
      NL := LangStrip.IndexOfAny([#13, #10]);
      if (NL >= 0) and (NL < 20) and
         (Trim(Copy(LangStrip, 1, NL)).IndexOfAny([' ', '.', ';', '(']) < 0) then
        Seg := LangStrip.Substring(NL).TrimLeft([#13, #10]);
      Seg := Seg.TrimRight([#13, #10, ' ']);
      if Seg <> '' then
        RichAppend(RichHistory, Seg, False, TextColor, -20, CODE_FONT);
    end
    else
    begin
      Seg := FormatAIText(Seg);
      if Trim(Seg) <> '' then
        RichAppend(RichHistory, Seg, False, TextColor, -23);
    end;
    IsCode := not IsCode;
  end;

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
  LStartTime: TDateTime;
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
  LStartTime := now;

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

      AppendHistory('AI', AResult, Now - LStartTime);

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
  Line, TrimLine: string;
  InFence: Boolean;
  FenceFile: string;
  ContentSB: TStringBuilder;
  DF: TDetectedFile;
  FenceLine: string;
  Parts: TArray<string>;
  CandExt: string;
  ValidExt: Boolean;
  PrevNonBlank: string;

  function GuessNameFromContent(const AContent: string): string;
  var
    M: TMatch;
    Kind: string;
  begin
    Result := '';
    M := TRegEx.Match(AContent, '^\s*(unit|program|package)\s+([A-Za-z0-9_.]+)\s*;',
      [roIgnoreCase, roMultiLine]);
    if M.Success then
    begin
      Kind := LowerCase(M.Groups[1].Value);
      if Kind = 'program' then Result := M.Groups[2].Value + '.dpr'
      else if Kind = 'package' then Result := M.Groups[2].Value + '.dpk'
      else Result := M.Groups[2].Value + '.pas';
    end;
  end;

  // Parse the filename hint from a fence-opening line (everything after ```).
  function ParseFenceFileName(const AFenceLine: string): string;
  var
    P: TArray<string>;
    Ext: string;
    K: Integer;
  begin
    Result := '';
    P := AFenceLine.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
    for K := 0 to High(P) do
    begin
      Ext := LowerCase(TPath.GetExtension(P[K]));
      for var KnownExt in KNOWN_EXTS do
        if Ext = KnownExt then
        begin
          Result := P[K];
          Exit;
        end;
    end;
  end;

  // Save each Pascal unit found in AContent as a separate TDetectedFile.
  // A single fence block may contain multiple units when the AI omits the
  // closing ``` between them; we split on "end." followed by a new
  // unit/program/package declaration.
  // AFenceFile is used for the first segment only (it came from the fence
  // header); subsequent segments get their name from GuessNameFromContent.
  procedure FlushContent(const AContent, AFenceFile: string);
  var
    SLines: TStringList;
    K: Integer;
    SLine, SPrev: string;
    SegSB: TStringBuilder;
    SegContent, SegName: string;
    IsFirst: Boolean;
  begin
    if Trim(AContent) = '' then Exit;
    SLines := TStringList.Create;
    SegSB  := TStringBuilder.Create;
    try
      SLines.Text := AContent;
      SPrev   := '';
      IsFirst := True;
      for K := 0 to SLines.Count - 1 do
      begin
        SLine := SLines[K];
        // Split point: previous non-blank line was "end." and this line
        // starts a new unit/program/package declaration.
        if (SegSB.Length > 0) and (SPrev = 'end.') and
           TRegEx.IsMatch(Trim(SLine), '^(unit|program|package)\s+\w+',
             [roIgnoreCase]) then
        begin
          SegContent := SegSB.ToString;
          SegName := IfThen(IsFirst and (AFenceFile <> ''), AFenceFile,
                            GuessNameFromContent(SegContent));
          if (Trim(SegContent) <> '') and (SegName <> '') then
          begin
            DF.FileName := SegName;
            DF.Content  := SegContent;
            FDetectedFiles.Add(DF);
          end;
          SegSB.Clear;
          IsFirst := False;
        end;
        if SegSB.Length > 0 then SegSB.AppendLine;
        SegSB.Append(SLine);
        if Trim(SLine) <> '' then SPrev := Trim(SLine);
      end;
      // Remaining segment
      SegContent := SegSB.ToString;
      SegName := IfThen(IsFirst and (AFenceFile <> ''), AFenceFile,
                        GuessNameFromContent(SegContent));
      if (Trim(SegContent) <> '') and (SegName <> '') then
      begin
        DF.FileName := SegName;
        DF.Content  := SegContent;
        FDetectedFiles.Add(DF);
      end;
    finally
      SLines.Free;
      SegSB.Free;
    end;
  end;

begin
  Lines := TStringList.Create;
  ContentSB := TStringBuilder.Create;
  try
    Lines.Text := AResponse;
    InFence      := False;
    FenceFile    := '';
    PrevNonBlank := '';

    for i := 0 to Lines.Count - 1 do
    begin
      Line     := Lines[i];
      TrimLine := Trim(Line);

      if not InFence then
      begin
        // Any line starting with ``` opens a fence.
        if (Length(TrimLine) >= 3) and (Copy(TrimLine, 1, 3) = '```') then
        begin
          FenceLine := Trim(Copy(TrimLine, 4, MaxInt));
          FenceFile := ParseFenceFileName(FenceLine);
          InFence   := True;
          ContentSB.Clear;
          PrevNonBlank := '';
        end;
      end
      else
      begin
        // Bare ``` → normal fence close.
        if TrimLine = '```' then
        begin
          FlushContent(ContentSB.ToString, FenceFile);
          InFence   := False;
          FenceFile := '';
          ContentSB.Clear;
        end
        // A new fence opener (``` + non-empty suffix) while already inside a
        // fence means the AI forgot the closing ```.  Treat it as an implicit
        // close followed by a new open.
        else if (Length(TrimLine) > 3) and (Copy(TrimLine, 1, 3) = '```') then
        begin
          FlushContent(ContentSB.ToString, FenceFile);
          ContentSB.Clear;
          PrevNonBlank := '';
          FenceLine := Trim(Copy(TrimLine, 4, MaxInt));
          FenceFile := ParseFenceFileName(FenceLine);
          // InFence stays True — we are now in the new fence.
        end
        else
        begin
          if ContentSB.Length > 0 then ContentSB.AppendLine;
          ContentSB.Append(Line);
          if TrimLine <> '' then PrevNonBlank := TrimLine;
        end;
      end;
    end;

    // Handle a fence left open at the end of the response (AI omitted the
    // closing ```).
    if InFence then
      FlushContent(ContentSB.ToString, FenceFile);

  finally
    ContentSB.Free;
    Lines.Free;
  end;
end;

procedure TChatDialog.RefreshFileList;
var
  i, SelIdx: Integer;
  HasSel: Boolean;
begin
  SelIdx := ListFiles.ItemIndex;
  ListFiles.Clear;
  for i := 0 to FDetectedFiles.Count - 1 do
    ListFiles.Items.Add(FDetectedFiles[i].FileName);
  if (SelIdx >= 0) and (SelIdx < ListFiles.Count) then
    ListFiles.ItemIndex := SelIdx;
  HasSel := ListFiles.ItemIndex >= 0;
  BtnSaveSelected.Enabled := HasSel;
  BtnOpenInIDE.Enabled    := HasSel;
end;

procedure TChatDialog.ListFilesClick(Sender: TObject);
var
  Idx: Integer;
  HasSel: Boolean;
begin
  Idx := ListFiles.ItemIndex;
  HasSel := (Idx >= 0) and (Idx < FDetectedFiles.Count);
  BtnSaveSelected.Enabled := HasSel;
  BtnOpenInIDE.Enabled    := HasSel;
  if not HasSel then
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

// ---------------------------------------------------------------------------
// IOTAFile implementation — supplies source text to the module creator.
// ---------------------------------------------------------------------------
type
  TSourceContent = class(TInterfacedObject, IOTAFile)
  private
    FSource: string;
  public
    constructor Create(const ASource: string);
    function GetSource: string;
    function GetAge: TDateTime;
  end;

constructor TSourceContent.Create(const ASource: string);
begin
  inherited Create;
  FSource := ASource;
end;

function TSourceContent.GetSource: string;
begin
  Result := FSource;
end;

function TSourceContent.GetAge: TDateTime;
begin
  Result := -1; // no file on disk
end;

// ---------------------------------------------------------------------------
// IOTAModuleCreator implementation — creates a new unnamed source buffer.
// ---------------------------------------------------------------------------
type
  TNewUnitCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    FFileName: string;
    FSource: string;
  public
    constructor Create(const AFileName, ASource: string);
    // IOTACreator
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    // IOTAModuleCreator
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor);
  end;

constructor TNewUnitCreator.Create(const AFileName, ASource: string);
begin
  inherited Create;
  FFileName := AFileName;
  FSource   := ASource;
end;

function TNewUnitCreator.GetCreatorType: string;
begin
  Result := sUnit;
end;

function TNewUnitCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TNewUnitCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TNewUnitCreator.GetOwner: IOTAModule;
begin
  Result := nil; // not added to any project
end;

function TNewUnitCreator.GetUnnamed: Boolean;
begin
  Result := True; // unsaved — no path on disk
end;

function TNewUnitCreator.GetAncestorName: string;
begin
  Result := '';
end;

function TNewUnitCreator.GetImplFileName: string;
begin
  Result := ''; // let the IDE assign a unique name (Unit1, Unit2, ...)
end;

function TNewUnitCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TNewUnitCreator.GetFormName: string;
begin
  Result := '';
end;

function TNewUnitCreator.GetMainForm: Boolean;
begin
  Result := False;
end;

function TNewUnitCreator.GetShowForm: Boolean;
begin
  Result := False;
end;

function TNewUnitCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

function TNewUnitCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil; // source-only unit, no form
end;

function TNewUnitCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := TSourceContent.Create(FSource);
end;

function TNewUnitCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil; // Pascal unit has no separate interface file
end;

procedure TNewUnitCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin
  // no form
end;

procedure TChatDialog.BtnOpenInIDEClick(Sender: TObject);
var
  Idx: Integer;
  DF: TDetectedFile;
  ModSvc: IOTAModuleServices;
begin
  Idx := ListFiles.ItemIndex;
  if (Idx < 0) or (Idx >= FDetectedFiles.Count) then
  begin
    ShowMessage('Please select a file from the list first.');
    Exit;
  end;
  DF := FDetectedFiles[Idx];
  if Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
    ModSvc.CreateModule(TNewUnitCreator.Create(DF.FileName, DF.Content));
end;

procedure TChatDialog.MenuItemCopyClick(Sender: TObject);
begin
  if RichHistory.SelLength > 0 then
    Clipboard.AsText := RichHistory.SelText;
end;

procedure TChatDialog.MenuItemSelectAllClick(Sender: TObject);
begin
  RichHistory.SelectAll;
end;

procedure TChatDialog.PaintBox1Paint(Sender: TObject);
begin
  PaintUsageGraphs(PaintBox1.Canvas, PaintBox1.Width, PaintBox1.Height, FCPUDonut, FGPUDonut, FVRAMDonut, FHasGPU, 'CPU', 'GPU', 'VRAM');
end;

end.
