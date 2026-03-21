unit CyAIAssistant.DonutGraph;

// (c) 2026 Cypheros
// License: GPL 2.0
//
// GDI+ Antialiased Donut Chart for Delphi
// Renders via TGPBitmap (32bppPARGB)
// Colors: ARGB ($AARRGGBB), Value: 0.0..1.0, Thickness: 0.0..1.0 (relative to radius)

interface

uses
  Winapi.Windows,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  Vcl.Graphics,
  System.SysUtils,
  System.Types,
  System.Math;

type
  TDonutGraph = class
  private
    FSize: Integer;
    FThickness: Single;
    FValue: Single;
    FColor: DWORD;
    FBackColor: DWORD;
    FStartAngle: Single;
    FSpanAngle: Single;
    FRoundCaps: Boolean;
    FShowCaption: Boolean;
    FCaptionColor: DWORD;
    FCaptionFontName: string;
    FCaptionFontSize: Single;
    procedure SetValue(const AValue: Single);
    procedure SetThickness(const AValue: Single);
    procedure SetSpanAngle(const AValue: Single);
    function GetEffectiveSpanAngle: Single;
  public
    constructor Create;
    procedure DrawTo(ACanvas: TCanvas; X, Y: Integer);
    procedure RenderToBitmap(ABitmap: TBitmap);

    property Size: Integer read FSize write FSize;
    property Thickness: Single read FThickness write SetThickness;
    property Value: Single read FValue write SetValue;
    property Color: DWORD read FColor write FColor;
    property BackColor: DWORD read FBackColor write FBackColor;
    property StartAngle: Single read FStartAngle write FStartAngle;
    property SpanAngle: Single read FSpanAngle write SetSpanAngle;
    property RoundCaps: Boolean read FRoundCaps write FRoundCaps;
    property ShowCaption: Boolean read FShowCaption write FShowCaption;
    property CaptionColor: DWORD read FCaptionColor write FCaptionColor;
    property CaptionFontName: string read FCaptionFontName write FCaptionFontName;
    property CaptionFontSize: Single read FCaptionFontSize write FCaptionFontSize;
  end;

implementation

var
  GdipToken: ULONG_PTR;
  GdipStartupInput: TGDIPlusStartupInput;

procedure InitGDIPlus;
begin
  FillChar(GdipStartupInput, SizeOf(GdipStartupInput), 0);
  GdipStartupInput.GdiplusVersion := 1;
  GdiplusStartup(GdipToken, @GdipStartupInput, nil);
end;

procedure FreeGDIPlus;
begin
  GdiplusShutdown(GdipToken);
end;

procedure ApplyCaps(APen: TGPPen; ARound: Boolean);
begin
  if ARound then
  begin
    APen.SetStartCap(LineCapRound);
    APen.SetEndCap(LineCapRound);
  end
  else
  begin
    APen.SetStartCap(LineCapFlat);
    APen.SetEndCap(LineCapFlat);
  end;
end;

procedure RenderDonutToGPBitmap(ADonut: TDonutGraph; AGPBitmap: TGPBitmap);
var
  G: TGPGraphics;
  Pen: TGPPen;
  Brush: TGPSolidBrush;
  Font: TGPFont;
  Family: TGPFontFamily;
  Fmt: TGPStringFormat;
  PenW, HalfPen, TotalSweep, SweepAngle, FontSize: Single;
  ArcR, LayoutR: TGPRectF;
  Caption: string;
begin
  G := TGPGraphics.Create(AGPBitmap);
  try
    G.SetSmoothingMode(SmoothingModeAntiAlias);
    G.SetPixelOffsetMode(PixelOffsetModeHighQuality);
    G.SetCompositingQuality(CompositingQualityHighQuality);
    G.SetCompositingMode(CompositingModeSourceOver);
    G.SetTextRenderingHint(TextRenderingHintAntiAlias);
    G.Clear(MakeColor(0, 0, 0, 0));

    TotalSweep := ADonut.GetEffectiveSpanAngle;
    PenW := (ADonut.Size / 2.0) * ADonut.Thickness;
    HalfPen := PenW / 2.0;

    ArcR.X := HalfPen + 1;
    ArcR.Y := HalfPen + 1;
    ArcR.Width := ADonut.Size - PenW - 2;
    ArcR.Height := ADonut.Size - PenW - 2;

    // Background ring
    Pen := TGPPen.Create(TGPColor(ADonut.BackColor), PenW);
    try
      ApplyCaps(Pen, ADonut.RoundCaps);
      G.DrawArc(Pen, ArcR, ADonut.StartAngle, TotalSweep);
    finally
      Pen.Free;
    end;

    // Value segment
    SweepAngle := ADonut.Value * TotalSweep;
    if SweepAngle > 0.1 then
    begin
      Pen := TGPPen.Create(TGPColor(ADonut.Color), PenW);
      try
        ApplyCaps(Pen, ADonut.RoundCaps);
        G.DrawArc(Pen, ArcR, ADonut.StartAngle, SweepAngle);
      finally
        Pen.Free;
      end;
    end;

    // Caption
    if ADonut.ShowCaption then
    begin
      Caption := IntToStr(Round(ADonut.Value * 100)) + '%';

      if ADonut.CaptionFontSize < 1 then
        FontSize := ADonut.Size * 0.18
      else
        FontSize := ADonut.CaptionFontSize;

      Family := TGPFontFamily.Create(ADonut.CaptionFontName);
      try
        if Family.GetLastStatus <> Ok then
        begin
          Family.Free;
          Family := TGPFontFamily.Create('Arial');
        end;

        Font := TGPFont.Create(Family, FontSize, FontStyleBold, UnitPixel);
        try
          Brush := TGPSolidBrush.Create(TGPColor(ADonut.CaptionColor));
          try
            Fmt := TGPStringFormat.Create;
            try
              Fmt.SetAlignment(StringAlignmentCenter);
              Fmt.SetLineAlignment(StringAlignmentCenter);
              LayoutR.X := 0;
              LayoutR.Y := 0;
              LayoutR.Width := ADonut.Size;
              LayoutR.Height := ADonut.Size;
              G.DrawString(Caption, Length(Caption), Font, LayoutR, Fmt, Brush);
            finally
              Fmt.Free;
            end;
          finally
            Brush.Free;
          end;
        finally
          Font.Free;
        end;
      finally
        Family.Free;
      end;
    end;
  finally
    G.Free;
  end;
end;

procedure GPBitmapToVCLBitmap(AGPBitmap: TGPBitmap; AWidth, AHeight: Integer; out AVCLBitmap: TBitmap);
var
  Data: TBitmapData;
  R: TGPRect;
  Y: Integer;
begin
  AVCLBitmap := TBitmap.Create;
  AVCLBitmap.PixelFormat := pf32bit;
  AVCLBitmap.SetSize(AWidth, AHeight);
  AVCLBitmap.AlphaFormat := afPremultiplied;

  R.X := 0;
  R.Y := 0;
  R.Width := AWidth;
  R.Height := AHeight;

  if AGPBitmap.LockBits(R, ImageLockModeRead, PixelFormat32bppPARGB, Data) = Ok then
  begin
    try
      for Y := 0 to AHeight - 1 do
        Move(Pointer(NativeUInt(Data.Scan0) + NativeUInt(Y) * NativeUInt(Data.Stride))^, AVCLBitmap.ScanLine[Y]^, AWidth * 4);
    finally
      AGPBitmap.UnlockBits(Data);
    end;
  end;
end;

// TDonutGraph

constructor TDonutGraph.Create;
begin
  inherited Create;
  FSize := 200;
  FThickness := 0.30;
  FValue := 0.0;
  FColor := $FF3498DB;
  FBackColor := $FFE8E8E8;
  FStartAngle := -90;
  FSpanAngle := 360;
  FRoundCaps := True;
  FShowCaption := True;
  FCaptionColor := $FF333333;
  FCaptionFontName := 'Segoe UI';
  FCaptionFontSize := 0;
end;

procedure TDonutGraph.SetValue(const AValue: Single);
begin
  FValue := EnsureRange(AValue, 0.0, 1.0);
end;

procedure TDonutGraph.SetThickness(const AValue: Single);
begin
  FThickness := EnsureRange(AValue, 0.01, 1.0);
end;

procedure TDonutGraph.SetSpanAngle(const AValue: Single);
begin
  FSpanAngle := EnsureRange(AValue, 0.1, 360.0);
end;

function TDonutGraph.GetEffectiveSpanAngle: Single;
begin
  Result := EnsureRange(FSpanAngle, 0.1, 360.0);
end;

procedure TDonutGraph.RenderToBitmap(ABitmap: TBitmap);
var
  GPBmp: TGPBitmap;
  TmpBmp: TBitmap;
begin
  GPBmp := TGPBitmap.Create(FSize, FSize, PixelFormat32bppPARGB);
  try
    RenderDonutToGPBitmap(Self, GPBmp);
    GPBitmapToVCLBitmap(GPBmp, FSize, FSize, TmpBmp);
    try
      ABitmap.Assign(TmpBmp);
      ABitmap.PixelFormat := pf32bit;
      ABitmap.AlphaFormat := afPremultiplied;
    finally
      TmpBmp.Free;
    end;
  finally
    GPBmp.Free;
  end;
end;

procedure TDonutGraph.DrawTo(ACanvas: TCanvas; X, Y: Integer);
var
  GPBmp: TGPBitmap;
  VCLBmp: TBitmap;
  Bf: TBlendFunction;
begin
  GPBmp := TGPBitmap.Create(FSize, FSize, PixelFormat32bppPARGB);
  try
    RenderDonutToGPBitmap(Self, GPBmp);
    GPBitmapToVCLBitmap(GPBmp, FSize, FSize, VCLBmp);
    try
      Bf.BlendOp := AC_SRC_OVER;
      Bf.BlendFlags := 0;
      Bf.SourceConstantAlpha := 255;
      Bf.AlphaFormat := AC_SRC_ALPHA;

      Winapi.Windows.AlphaBlend(ACanvas.Handle, X, Y, FSize, FSize, VCLBmp.Canvas.Handle, 0, 0, FSize, FSize, Bf);
    finally
      VCLBmp.Free;
    end;
  finally
    GPBmp.Free;
  end;
end;

initialization

InitGDIPlus;

finalization

FreeGDIPlus;

end.
