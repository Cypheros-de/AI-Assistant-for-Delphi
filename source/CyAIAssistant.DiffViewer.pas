unit CyAIAssistant.DiffViewer;

// CyAIAssistant.DiffViewer.pas
// Side-by-side diff viewer: original vs AI code, unified diff, editable AI tab.
// Allows applying the AI result back into the IDE editor selection.

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Graphics,
  ToolsAPI;

type
  TDiffLineKind = (dlkSame, dlkAdded, dlkRemoved, dlkChanged);

  TDiffLine = record
    Kind: TDiffLineKind;
    OrigLine: string;
    NewLine: string;
    OrigLineNo: Integer;
    NewLineNo: Integer;
  end;

  TDiffViewerForm = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelBottom: TPanel;
    LabelStats: TLabel;
    BtnApply: TButton;
    BtnCopyNew: TButton;
    BtnClose: TButton;
    PageControl: TPageControl;
    TabSideBySide: TTabSheet;
    PanelOriginal: TPanel;
    LabelOrig: TLabel;
    MemoOriginal: TMemo;
    SplitterSide: TSplitter;
    PanelNew: TPanel;
    LabelNew: TLabel;
    MemoNew: TMemo;
    TabDiff: TTabSheet;
    MemoDiff: TRichEdit;
    TabAIOnly: TTabSheet;
    MemoAIEdit: TMemo;
    procedure BtnApplyClick(Sender: TObject);
    procedure BtnCopyClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
  private
    FOriginalCode: string;
    FAICode: string;
    FSourceEditor: IOTASourceEditor;
    FDiffLines: TList<TDiffLine>;
    FApplied: Boolean;
    procedure ComputeDiff;
    procedure RenderSideBySide;
    procedure RenderUnifiedDiff;
    procedure UpdateStats;
    procedure ApplyToEditor(const AText: string);
    function LCS(const A, B: TArray<string>): TArray<string>;
  public
    constructor Create(AOwner: TComponent; const AOriginal, AAIResult: string; ASourceEditor: IOTASourceEditor); reintroduce;
    destructor Destroy; override;
    property Applied: Boolean read FApplied;
  end;

implementation

{$R *.dfm}

uses
  System.Math, Vcl.Clipbrd,
  CyAIAssistant.IDETheme;

const
  COLOR_ADDED = $00C8FFC8;
  COLOR_REMOVED = $00C8C8FF;
  COLOR_CHANGED = $00FFFFC8;

  // TDiffViewerForm

constructor TDiffViewerForm.Create(AOwner: TComponent; const AOriginal, AAIResult: string; ASourceEditor: IOTASourceEditor);

  function NormalizeEOL(const S: string): string;
  var
    i: Integer;
    SB: TStringBuilder;
    c: Char;
  begin
    SB := TStringBuilder.Create(Length(S) + 64);
    try
      i := 1;
      while i <= Length(S) do
      begin
        c := S[i];
        if c = #13 then
        begin
          SB.Append(#13#10);
          if (i < Length(S)) and (S[i + 1] = #10) then
            Inc(i);
        end
        else if c = #10 then
          SB.Append(#13#10)
        else
          SB.Append(c);
        Inc(i);
      end;
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  end;

begin
  inherited Create(AOwner);
  FOriginalCode := NormalizeEOL(AOriginal);
  FAICode := NormalizeEOL(AAIResult);
  FSourceEditor := ASourceEditor;
  FDiffLines := TList<TDiffLine>.Create;

  MemoOriginal.Text := FOriginalCode;
  MemoNew.Text := FAICode;
  MemoAIEdit.Text := FAICode;

  ComputeDiff;
  RenderSideBySide;
  RenderUnifiedDiff;
  UpdateStats;

  ApplyIDETheme(Self);
end;

destructor TDiffViewerForm.Destroy;
begin
  FDiffLines.Free;
  inherited;
end;

function TDiffViewerForm.LCS(const A, B: TArray<string>): TArray<string>;
var
  m, n, i, j: Integer;
  Dp: array of array of Integer;
  Result2: TList<string>;
begin
  m := Length(A);
  n := Length(B);
  SetLength(Dp, m + 1, n + 1);
  for i := 1 to m do
    for j := 1 to n do
      if A[i - 1] = B[j - 1] then
        Dp[i][j] := Dp[i - 1][j - 1] + 1
      else
        Dp[i][j] := Max(Dp[i - 1][j], Dp[i][j - 1]);

  Result2 := TList<string>.Create;
  try
    i := m;
    j := n;
    while (i > 0) and (j > 0) do
    begin
      if A[i - 1] = B[j - 1] then
      begin
        Result2.Insert(0, A[i - 1]);
        Dec(i);
        Dec(j);
      end
      else if Dp[i - 1][j] > Dp[i][j - 1] then
        Dec(i)
      else
        Dec(j);
    end;
    Result := Result2.ToArray;
  finally
    Result2.Free;
  end;
end;

procedure TDiffViewerForm.ComputeDiff;
var
  OrigLines, NewLines, Common: TArray<string>;
  OI, NI, CI: Integer;
  DL: TDiffLine;
  MaxLen, i: Integer;
  OMatch: Boolean;
  NMatch: Boolean;
begin
  FDiffLines.Clear;
  OrigLines := FOriginalCode.Split([#13#10]);
  NewLines := FAICode.Split([#13#10]);

  if (Length(OrigLines) + Length(NewLines)) > 2000 then
  begin
    MaxLen := Max(Length(OrigLines), Length(NewLines));
    for i := 0 to MaxLen - 1 do
    begin
      DL.OrigLineNo := i + 1;
      DL.NewLineNo := i + 1;
      if (i < Length(OrigLines)) and (i < Length(NewLines)) then
      begin
        DL.OrigLine := OrigLines[i];
        DL.NewLine := NewLines[i];
        if OrigLines[i] = NewLines[i] then
          DL.Kind := dlkSame
        else
          DL.Kind := dlkChanged;
      end
      else if i < Length(OrigLines) then
      begin
        DL.OrigLine := OrigLines[i];
        DL.NewLine := '';
        DL.Kind := dlkRemoved;
      end
      else
      begin
        DL.OrigLine := '';
        DL.NewLine := NewLines[i];
        DL.Kind := dlkAdded;
      end;
      FDiffLines.Add(DL);
    end;
    Exit;
  end;

  Common := LCS(OrigLines, NewLines);
  OI := 0;
  NI := 0;
  CI := 0;

  while (OI < Length(OrigLines)) or (NI < Length(NewLines)) do
  begin
    OMatch := (CI < Length(Common)) and (OI < Length(OrigLines)) and (OrigLines[OI] = Common[CI]);
    NMatch := (CI < Length(Common)) and (NI < Length(NewLines)) and (NewLines[NI] = Common[CI]);

    if OMatch and NMatch then
    begin
      DL.Kind := dlkSame;
      DL.OrigLine := OrigLines[OI];
      DL.NewLine := NewLines[NI];
      DL.OrigLineNo := OI + 1;
      DL.NewLineNo := NI + 1;
      FDiffLines.Add(DL);
      Inc(OI);
      Inc(NI);
      Inc(CI);
    end
    else if not OMatch and (OI < Length(OrigLines)) and not NMatch and (NI < Length(NewLines)) then
    begin
      DL.Kind := dlkChanged;
      DL.OrigLine := OrigLines[OI];
      DL.NewLine := NewLines[NI];
      DL.OrigLineNo := OI + 1;
      DL.NewLineNo := NI + 1;
      FDiffLines.Add(DL);
      Inc(OI);
      Inc(NI);
    end
    else if not OMatch and (OI < Length(OrigLines)) then
    begin
      DL.Kind := dlkRemoved;
      DL.OrigLine := OrigLines[OI];
      DL.NewLine := '';
      DL.OrigLineNo := OI + 1;
      DL.NewLineNo := 0;
      FDiffLines.Add(DL);
      Inc(OI);
    end
    else if not NMatch and (NI < Length(NewLines)) then
    begin
      DL.Kind := dlkAdded;
      DL.OrigLine := '';
      DL.NewLine := NewLines[NI];
      DL.OrigLineNo := 0;
      DL.NewLineNo := NI + 1;
      FDiffLines.Add(DL);
      Inc(NI);
    end
    else
      Break;
  end;
end;

procedure TDiffViewerForm.RenderSideBySide;
var
  DL: TDiffLine;
  OrigLines: TStringList;
  NewLines: TStringList;
begin
  OrigLines := TStringList.Create;
  NewLines := TStringList.Create;
  try
    for DL in FDiffLines do
    begin
      case DL.Kind of
        dlkSame:
          begin
            OrigLines.Add(DL.OrigLine);
            NewLines.Add(DL.NewLine);
          end;
        dlkAdded:
          begin
            OrigLines.Add('');
            NewLines.Add('+ ' + DL.NewLine);
          end;
        dlkRemoved:
          begin
            OrigLines.Add('- ' + DL.OrigLine);
            NewLines.Add('');
          end;
        dlkChanged:
          begin
            OrigLines.Add('~ ' + DL.OrigLine);
            NewLines.Add('~ ' + DL.NewLine);
          end;
      end;
    end;
    MemoOriginal.Lines.BeginUpdate;
    MemoNew.Lines.BeginUpdate;
    try
      MemoOriginal.Lines.Assign(OrigLines);
      MemoNew.Lines.Assign(NewLines);
    finally
      MemoOriginal.Lines.EndUpdate;
      MemoNew.Lines.EndUpdate;
    end;
  finally
    OrigLines.Free;
    NewLines.Free;
  end;
end;

procedure TDiffViewerForm.RenderUnifiedDiff;
var
  DL: TDiffLine;
  LineText: string;
  FgColor: TColor;
  StartPos: Integer;
begin
  MemoDiff.Lines.BeginUpdate;
  MemoDiff.Lines.Clear;
  MemoDiff.Lines.EndUpdate;

  for DL in FDiffLines do
  begin
    case DL.Kind of
      dlkSame:
        begin
          LineText := '   ' + DL.OrigLine;
          FgColor := $00777777;
        end;
      dlkAdded:
        begin
          LineText := '+  ' + DL.NewLine;
          FgColor := $0055FF55;
        end;
      dlkRemoved:
        begin
          LineText := '-  ' + DL.OrigLine;
          FgColor := $00FF5555;
        end;
      dlkChanged:
        begin
          LineText := '~  ' + DL.OrigLine + '  ->  ' + DL.NewLine;
          FgColor := $00FFFF55;
        end;
    else
      LineText := DL.OrigLine;
      FgColor := $00AAAAAA;
    end;
    StartPos := Length(MemoDiff.Text);
    MemoDiff.SelStart := StartPos;
    MemoDiff.SelLength := 0;
    MemoDiff.SelAttributes.Color := FgColor;
    MemoDiff.SelText := LineText + #13#10;
  end;
end;

procedure TDiffViewerForm.UpdateStats;
var
  DL: TDiffLine;
  Added, Removed, Changed, Same: Integer;
begin
  Added := 0;
  Removed := 0;
  Changed := 0;
  Same := 0;
  for DL in FDiffLines do
    case DL.Kind of
      dlkAdded:
        Inc(Added);
      dlkRemoved:
        Inc(Removed);
      dlkChanged:
        Inc(Changed);
      dlkSame:
        Inc(Same);
    end;
  LabelStats.Caption := Format('Diff: %d unchanged  |  +%d added  |  -%d removed  |  ~%d changed  |  Total lines: %d',
    [Same, Added, Removed, Changed, FDiffLines.Count]);
end;

procedure TDiffViewerForm.ApplyToEditor(const AText: string);

  function LeadingWhitespace(const S: string): string;
  var
    SL: TStringList;
    i, j: Integer;
    Line: string;
  begin
    Result := '';
    SL := TStringList.Create;
    try
      SL.Text := S;
      for i := 0 to SL.Count - 1 do
      begin
        Line := SL[i];
        if Length(Trim(Line)) > 0 then
        begin
          j := 1;
          while (j <= Length(Line)) and ((Line[j] = ' ') or (Line[j] = #9)) do
            Inc(j);
          Result := Copy(Line, 1, j - 1);
          Exit;
        end;
      end;
    finally
      SL.Free;
    end;
  end;

  function ReindentCode(const ACode, AiBase, ATargetBase: string): string;
  var
    SL: TStringList;
    SB: TStringBuilder;
    i: Integer;
    Line: string;
    BaseLen: Integer;
  begin
    if AiBase = ATargetBase then
    begin
      Result := ACode;
      Exit;
    end;
    BaseLen := Length(AiBase);
    SL := TStringList.Create;
    SB := TStringBuilder.Create;
    try
      SL.Text := ACode;
      for i := 0 to SL.Count - 1 do
      begin
        Line := SL[i];
        if (BaseLen > 0) and (Copy(Line, 1, BaseLen) = AiBase) then
          Line := ATargetBase + Copy(Line, BaseLen + 1, MaxInt)
        else if Length(Trim(Line)) > 0 then
          Line := ATargetBase + TrimLeft(Line);
        SB.Append(Line);
        if i < SL.Count - 1 then
          SB.Append(#13#10);
      end;
      Result := SB.ToString;
    finally
      SL.Free;
      SB.Free;
    end;
  end;

var
  EditView: IOTAEditView;
  StartChar: TOTACharPos;
  EndChar: TOTACharPos;
  StartOff: LongInt;
  EndOff: LongInt;
  Writer: IOTAEditWriter;
  InsertText: AnsiString;
  Reindented: string;
begin
  if FSourceEditor = nil then
  begin
    ShowMessage('Cannot apply: source editor reference lost.');
    Exit;
  end;
  if FSourceEditor.EditViewCount = 0 then
  begin
    ShowMessage('Cannot apply: no active edit view.');
    Exit;
  end;

  EditView := FSourceEditor.EditViews[0];
  StartChar := FSourceEditor.BlockStart;
  EndChar := FSourceEditor.BlockAfter;

  if (StartChar.Line = 0) and (EndChar.Line = 0) then
  begin
    ShowMessage('Cannot apply: no selection found.' + sLineBreak + 'Please copy the result manually.');
    Exit;
  end;

  StartOff := EditView.CharPosToPos(StartChar);
  EndOff := EditView.CharPosToPos(EndChar);
  Reindented := ReindentCode(AText, LeadingWhitespace(AText), LeadingWhitespace(FOriginalCode));

  InsertText := AnsiString(StringReplace(Reindented, #13#10, #10, [rfReplaceAll]));
  InsertText := AnsiString(StringReplace(string(InsertText), #10, #13#10, [rfReplaceAll]));

  Writer := FSourceEditor.CreateUndoableWriter;
  try
    Writer.CopyTo(StartOff);
    Writer.DeleteTo(EndOff);
    Writer.Insert(PAnsiChar(InsertText));
  finally
    Writer := nil;
  end;

  EditView.Paint;
  FApplied := True;
  Close;
end;

procedure TDiffViewerForm.BtnApplyClick(Sender: TObject);
begin
  if MessageDlg('Apply the AI-generated code to replace the selected text in the editor?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    ApplyToEditor(MemoAIEdit.Text);
end;

procedure TDiffViewerForm.BtnCopyClick(Sender: TObject);
begin
  Clipboard.AsText := MemoAIEdit.Text;
  ShowMessage('AI result copied to clipboard.');
end;

procedure TDiffViewerForm.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
