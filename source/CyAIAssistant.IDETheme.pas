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

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls,
  ToolsAPI;

procedure RegisterIDEThemeForm(AFormClass: TCustomFormClass);
procedure ApplyIDETheme(AForm: TCustomForm);
function GetIDEThemeGetColor(aColor: TColor): TColor;

function IDEThemeIsDark: Boolean;

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

// ---------------------------------------------------------------------------
// Public: registration and application
// ---------------------------------------------------------------------------

procedure RegisterIDEThemeForm(AFormClass: TCustomFormClass);
var
  ThemeSvc: IOTAIDEThemingServices;
  ThemeSvc250: IOTAIDEThemingServices250;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices250, ThemeSvc250) then   // Try the versioned interface first (Delphi 10.3+)
    ThemeSvc250.RegisterFormClass(AFormClass)
  else if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then    // Fall back to base interface
    ThemeSvc.RegisterFormClass(AFormClass);
end;

procedure ApplyIDETheme(AForm: TCustomForm);
var
  ThemeSvc: IOTAIDEThemingServices;
  ThemeSvc250: IOTAIDEThemingServices250;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices250, ThemeSvc250) then   // Try the versioned interface first (Delphi 10.3+)
    ThemeSvc250.ApplyTheme(AForm)
  else if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then    // Fall back to base interface
    ThemeSvc.ApplyTheme(AForm);
end;

function GetIDEThemeGetColor(aColor: TColor): TColor;
var
  ThemeSvc: IOTAIDEThemingServices;
  ThemeSvc250: IOTAIDEThemingServices250;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices250, ThemeSvc250) then   // Try the versioned interface first (Delphi 10.3+)
    Result := ThemeSvc250.StyleServices.GetSystemColor(aColor)
  else if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then    // Fall back to base interface
    Result := ThemeSvc.StyleServices.GetSystemColor(aColor)
  else
    Result := aColor;
end;

end.
