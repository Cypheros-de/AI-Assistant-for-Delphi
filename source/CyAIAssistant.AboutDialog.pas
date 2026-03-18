unit CyAIAssistant.AboutDialog;

// CyAIAssistant.AboutDialog.pas
// About box: plugin name, file version, developer, GPL-2 and website links.
// Link colors adapt to the active IDE theme:
// Dark  theme → bright orange / sky-blue hover
// Light theme → dark  orange / blue hover
// Colors are re-applied after ApplyIDETheme (which resets all label font
// colors to the theme foreground) via RestoreLinkColors.
interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics;

type
  TAboutDialog = class(TForm)
    PanelHeader: TPanel;
    LabelVersion: TLabel;
    LabelDev: TLabel;
    Bevel1: TBevel;
    LabelLicenseGPLText: TLabel;
    LinkLicenseGPL: TLabel;
    Bevel2: TBevel;
    LinkWebsite: TLabel;
    BtnClose: TButton;
    LabelLicenseMITText: TLabel;
    LinkLicenseMIT: TLabel;
    LabelSourceCode: TLabel;
    LinkSourceCode: TLabel;
    procedure LinkLicenseMITClick(Sender: TObject);
    procedure LinkLicenseGPLClick(Sender: TObject);
    procedure LinkSourceCodeClick(Sender: TObject);
    procedure LinkWebsiteClick(Sender: TObject);
  private
    function GetFileVersionString: string;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.dfm}

uses
  Winapi.Windows, Winapi.ShellAPI,
  CyAIAssistant.IDETheme;

constructor TAboutDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  LabelVersion.Caption := 'Version: ' + GetFileVersionString;
  ApplyIDETheme(Self);
end;

// Link clicks
procedure TAboutDialog.LinkLicenseGPLClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'https://www.gnu.org/licenses/old-licenses/gpl-2.0.html', nil, nil, SW_SHOWNORMAL);
end;

procedure TAboutDialog.LinkWebsiteClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'https://www.cypheros.de', nil, nil, SW_SHOWNORMAL);
end;

// Version string from BPL resource
function TAboutDialog.GetFileVersionString: string;
var
  FileName: array [0 .. MAX_PATH] of Char;
  InfoSize, Dummy: DWORD;
  InfoBuf: Pointer;
  FileInfo: PVSFixedFileInfo;
  InfoLen: UINT;
  Major, Minor, Build, Revision: Word;
begin
  Result := 'N/A';
  if GetModuleFileName(HInstance, FileName, MAX_PATH) = 0 then
    Exit;
  InfoSize := GetFileVersionInfoSize(FileName, Dummy);
  if InfoSize = 0 then
    Exit;
  GetMem(InfoBuf, InfoSize);
  try
    if not GetFileVersionInfo(FileName, 0, InfoSize, InfoBuf) then
      Exit;
    if not VerQueryValue(InfoBuf, '\', Pointer(FileInfo), InfoLen) then
      Exit;
    if InfoLen < SizeOf(TVSFixedFileInfo) then
      Exit;
    Major := HiWord(FileInfo^.dwFileVersionMS);
    Minor := LoWord(FileInfo^.dwFileVersionMS);
    Build := HiWord(FileInfo^.dwFileVersionLS);
    Revision := LoWord(FileInfo^.dwFileVersionLS);
    Result := Format('%d.%d.%d.%d', [Major, Minor, Build, Revision]);
  finally
    FreeMem(InfoBuf);
  end;
end;

procedure TAboutDialog.LinkLicenseMITClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'https://github.com/pyscripter/Ssh-Pascal#MIT-1-ov-file', nil, nil, SW_SHOWNORMAL);
end;

procedure TAboutDialog.LinkSourceCodeClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'https://github.com/Cypheros-de/AI-Assistant-for-Delphi', nil, nil, SW_SHOWNORMAL);
end;

end.
