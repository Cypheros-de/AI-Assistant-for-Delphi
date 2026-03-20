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
// Internal: recursive label/panel color fix
// ---------------------------------------------------------------------------

// After ApplyTheme, TLabel and TPanel controls that have ParentFont=False or
// an explicit Color set are not updated by the VCL style engine because it
// treats explicit property values as intentional overrides.  Walk the control
// tree and remap the two common "unset" values to their themed equivalents:
//   Font.Color = clWindowText  →  themed foreground
//   Color      = clBtnFace     →  themed panel background
// Controls that carry deliberately different colors (e.g. the white text on
// the dark header strip) are left alone.
procedure FixLabelPanelColors(AParent: TWinControl; AThemeSvc: IOTAIDEThemingServices);
var
  I: Integer;
  C: TControl;
  FgColor, BgColor: TColor;
begin
  FgColor := AThemeSvc.StyleServices.GetSystemColor(clWindowText);
  BgColor := AThemeSvc.StyleServices.GetSystemColor(clBtnFace);
  for I := 0 to AParent.ControlCount - 1 do
  begin
    C := AParent.Controls[I];
    if C is TLabel then
    begin
      if TLabel(C).Font.Color = clWindowText then
        TLabel(C).Font.Color := FgColor;
    end
    else if C is TPanel then
    begin
      if TPanel(C).Color = clBtnFace then
        TPanel(C).Color := BgColor;
    end;
    if C is TWinControl then
      FixLabelPanelColors(TWinControl(C), AThemeSvc);
  end;
end;

// ---------------------------------------------------------------------------
// Public: registration and application
// ---------------------------------------------------------------------------

procedure RegisterIDEThemeForm(AFormClass: TCustomFormClass);
var
  ThemeSvc: IOTAIDEThemingServices;
begin
  // Use base interface
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then
    ThemeSvc.RegisterFormClass(AFormClass);
end;

procedure ApplyIDETheme(AForm: TCustomForm);
var
  ThemeSvc: IOTAIDEThemingServices;
  ThemeSvc250: IOTAIDEThemingServices250;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices250, ThemeSvc250) then  // Try the versioned interface first (Delphi 10.3+)
    ThemeSvc250.ApplyTheme(AForm)
  else if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then   // Fall back to base interface
    ThemeSvc.ApplyTheme(AForm);

  // Fix labels/panels that ApplyTheme skips because they have explicit colors.
  // Use the base interface (StyleServices lives there) regardless of which
  // versioned interface was used above for ApplyTheme.
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then
    FixLabelPanelColors(AForm, ThemeSvc);
end;

function GetIDEThemeGetColor(aColor: TColor): TColor;
var
  ThemeSvc: IOTAIDEThemingServices;
  ThemeSvc250: IOTAIDEThemingServices250;
begin
  // Use base interface
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then
    Result := ThemeSvc.StyleServices.GetSystemColor(aColor)
  else
    Result := aColor;
end;

end.
