unit CyAIAssistant.UsagePresent;

interface

uses
  System.Types, Vcl.Graphics, CyAIAssistant.DonutGraph;

procedure UpdateDonutsGraphs(Donut1, Donut2, Donut3: TDonutGraph; HasGPU: Boolean; Value1, Value2, Value3: Single; Size: Integer);
procedure PaintUsageGraphs(ACanvas: TCanvas; AWidth, AHeight: Integer; Donut1, Donut2, Donut3: TDonutGraph; HasGPU: Boolean; Caption1, Caption2, Caption3: String);

implementation

procedure DrawDonutTextCentered(ACanvas: TCanvas; Text: String; X, Y: Integer);
var
    LSize: TSize;
begin
  LSize := ACanvas.TextExtent(Text);
  ACanvas.Brush.Style := bsClear;
  ACanvas.TextOut(X - LSize.cx div 2, Y - LSize.cy div 2, Text);
end;

procedure PaintUsageGraphs(ACanvas: TCanvas; AWidth, AHeight: Integer; Donut1, Donut2, Donut3: TDonutGraph; HasGPU: Boolean; Caption1, Caption2, Caption3: String);
var
  CenterY: Integer;
  LSpace: Integer;
  LTextPosY: Integer;
begin
  CenterY := (AHeight - Donut1.Size) div 2;
  LSpace  := (AWidth - 3 * AHeight) div 4;
  LTextPosY := AHeight + ACanvas.Font.Height div 2 + 1;

  ACanvas.Font.Color := clWhite;
  ACanvas.Font.Size := 6;

  if HasGPU then
  begin
    Donut1.DrawTo(ACanvas, LSpace, CenterY);
    DrawDonutTextCentered(ACanvas, Caption1, LSpace + AHeight div 2, LTextPosY);

    Donut2.DrawTo(ACanvas, 2*LSpace + AHeight, CenterY);
    DrawDonutTextCentered(ACanvas, Caption2, 2*LSpace + AHeight + AHeight div 2, LTextPosY);

    Donut3.DrawTo(ACanvas, 3*LSpace + 2*AHeight, CenterY);
    DrawDonutTextCentered(ACanvas, Caption3, 3*LSpace + 2*AHeight + AHeight div 2, LTextPosY);
  end
  else
  begin
    Donut1.DrawTo(ACanvas, AWidth - LSpace - AHeight, CenterY);
    DrawDonutTextCentered(ACanvas, Caption1, AWidth - LSpace - AHeight div 2, LTextPosY);
  end;

end;

procedure UpdateDonutsGraphs(Donut1, Donut2, Donut3: TDonutGraph; HasGPU: Boolean; Value1, Value2, Value3: Single; Size: Integer);
const
   TextColor: Cardinal = $FFF0F0F0;
   DonutColor: Cardinal = $FFE0E0FF;
   BackColor: Cardinal = $FF8080A0;
   StartAngle = 135;
   SpanAngle = 270;
   Thickness = 0.2;
begin
  Donut1.Size := Size;
  Donut1.Thickness := Thickness;
  Donut1.StartAngle := StartAngle;
  Donut1.SpanAngle  := SpanAngle;
  Donut1.CaptionColor := TextColor;
  Donut1.Color := DonutColor;
  Donut1.BackColor := BackColor;
  Donut1.Value := Value1 / 100;

  if HasGPU then
  begin
    Donut2.Size := Size;
    Donut2.Thickness := Thickness;
    Donut2.StartAngle := StartAngle;
    Donut2.SpanAngle  := SpanAngle;
    Donut2.CaptionColor := TextColor;
    Donut2.Color := DonutColor;
    Donut2.BackColor := BackColor;
    Donut2.Value := Value2 / 100;

    Donut3.Size := Size;
    Donut3.Thickness := Thickness;
    Donut3.StartAngle := StartAngle;
    Donut3.SpanAngle  := SpanAngle;
    Donut3.CaptionColor := TextColor;
    Donut3.Color := DonutColor;
    Donut3.BackColor := BackColor;
    Donut3.Value := Value2 / 100;
  end;

end;

end.
