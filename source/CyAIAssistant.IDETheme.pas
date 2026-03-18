unit CyAIAssistant.IDETheme;

// CyAIAssistant.IDETheme.pas
//
// Applies the Delphi IDE's current VCL theme to plugin forms.
//
// Strategy:
// - Try IOTAIDEThemingServices250 first (Delphi 10.3+), which has ApplyTheme.
// - Fall back to IOTAIDEThemingServices if the versioned one is unavailable.
// - After ApplyTheme, manually fix TLabel/TPanel colors using GetSystemColor,
// because these controls don't use VCL style hooks.
// - RegisterFormClass must be called once per form class before any instance
// is created (done in CyAIAssistant.Register initialization).
//
// IDEThemeIsDark
// Returns True when the current IDE theme has a dark background.
// Determined by computing the luminance of clWindow from StyleServices.
// Luminance < 128  →  dark theme.
//
// IDEThemeLinkColor / IDEThemeLinkHoverColor
// Return link colors appropriate for the active theme:
// Dark  theme → bright orange  #FF8C00 / bright blue  #6CB4FF
// Light theme → dark  orange   #CC6600 / standard blue #0000CC

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls,
  ToolsAPI;

procedure RegisterIDEThemeForm(AFormClass: TCustomFormClass);
procedure ApplyIDETheme(AForm: TCustomForm);

function IDEThemeIsDark: Boolean;
function IDEThemeLinkColor: TColor;
function IDEThemeLinkHoverColor: TColor;

implementation

uses
  Winapi.Windows;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

function GetThemeService(out ThemeSvc: IOTAIDEThemingServices): Boolean;
begin
  Result := Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc);
end;

// Luminance (0..255) of an RGB color using the standard Rec.601 formula.
function Luminance(AColor: TColor): Byte;
var
  C: TColor;
  R, G, B: Byte;
begin
  C := ColorToRGB(AColor);
  R := GetRValue(C);
  G := GetGValue(C);
  B := GetBValue(C);
  Result := Round(0.299 * R + 0.587 * G + 0.114 * B);
end;

// ---------------------------------------------------------------------------
// Public: theme detection
// ---------------------------------------------------------------------------

function IDEThemeIsDark: Boolean;
var
  ThemeSvc: IOTAIDEThemingServices;
  BgColor: TColor;
  Lum: Byte;
begin
  Result := False; // assume light when IDE theming is unavailable
  if not GetThemeService(ThemeSvc) then
    Exit;

  // clWindow gives the editor/form background; clBtnFace gives the panel
  // background — both should agree on dark vs light.
  // Try clWindow first, fall back to clBtnFace.
  BgColor := ThemeSvc.StyleServices.GetSystemColor(clWindow);
  // ColorToRGB resolves system color indices to actual RGB via the VCL style
  // engine; if the result is still a system color constant (high bit set),
  // fall back to clBtnFace which is always a real color in styled apps.
  if (BgColor and $FF000000) <> 0 then
    BgColor := ThemeSvc.StyleServices.GetSystemColor(clBtnFace);

  Lum := Luminance(ColorToRGB(BgColor));
  Result := Lum < 128;
end;

function IDEThemeLinkColor: TColor;
begin
  if IDEThemeIsDark then
    Result := $0040B8FF // amber  RGB(255,184,64)  — warm, visible on dark bg
  else
    Result := $000066CC; // dark orange RGB(204,102,0) — visible on light bg
end;

function IDEThemeLinkHoverColor: TColor;
begin
  if IDEThemeIsDark then
    Result := $00FFFFFF // bright white — unmistakably different from amber
  else
    Result := $00CC0000; // standard blue RGB(0,0,204)
end;

// ---------------------------------------------------------------------------
// Internal: fix label/panel colors after ApplyTheme
// ---------------------------------------------------------------------------

procedure FixControlColors(AParent: TWinControl; const ThemeSvc: IOTAIDEThemingServices);
var
  I: Integer;
  Ctrl: TControl;
  BgColor: TColor;
  FgColor: TColor;
begin
  BgColor := ThemeSvc.StyleServices.GetSystemColor(clWindow);
  FgColor := ThemeSvc.StyleServices.GetSystemColor(clWindowText);

  for I := 0 to AParent.ControlCount - 1 do
  begin
    Ctrl := AParent.Controls[I];

    if Ctrl is TLabel then
    begin
      TLabel(Ctrl).Color := BgColor;
      TLabel(Ctrl).Font.Color := FgColor;
    end
    else if Ctrl is TPanel then
    begin
      TPanel(Ctrl).Color := BgColor;
      TPanel(Ctrl).Font.Color := FgColor;
    end;

    if (Ctrl is TWinControl) and (TWinControl(Ctrl).ControlCount > 0) then
      FixControlColors(TWinControl(Ctrl), ThemeSvc);
  end;
end;

// ---------------------------------------------------------------------------
// Public: registration and application
// ---------------------------------------------------------------------------

procedure RegisterIDEThemeForm(AFormClass: TCustomFormClass);
var
  ThemeSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then
    ThemeSvc.RegisterFormClass(AFormClass);
end;

procedure ApplyIDETheme(AForm: TCustomForm);
var
  ThemeSvc: IOTAIDEThemingServices;
  ThemeSvc250: IOTAIDEThemingServices250;
begin
  // Try the versioned interface first (Delphi 10.3+)
  if Supports(BorlandIDEServices, IOTAIDEThemingServices250, ThemeSvc250) then
  begin
    ThemeSvc250.ApplyTheme(AForm);
    if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then
      FixControlColors(AForm, ThemeSvc);
    Exit;
  end;

  // Fall back to base interface
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then
  begin
    ThemeSvc.ApplyTheme(AForm);
    FixControlColors(AForm, ThemeSvc);
  end;
end;

end.
