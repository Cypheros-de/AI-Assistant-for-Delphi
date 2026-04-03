unit CyAIAssistant.DebugLog;

// CyAIAssistant.DebugLog.pas
// HTTP request/response logging utility for debugging AI API calls.

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.Generics.Collections, System.SyncObjs, System.Net.URLClient;

type
  TDebugLogger = class
  private
    FLogFolder: string;
    FCS: TCriticalSection;
    procedure Write(const AText: string);
    function GetLogFileName: string;
    function RedactHeaderValue(const AName, AValue: string): string;
  public
    constructor Create(const ALogFolder: string);
    destructor Destroy; override;
    procedure LogRequest(const AMethod, AURL: string; const AHeaders: TNetHeaders; const ABody: string);
    procedure LogResponse(const AStatusCode: Integer; const AHeaders: TNetHeaders; const ABody: string; const AError: string = '');
  end;

implementation

uses
  System.IOUtils, System.NetEncoding, System.Threading;

{ TDebugLogger }

constructor TDebugLogger.Create(const ALogFolder: string);
begin
  inherited Create;
  FCS := TCriticalSection.Create;
  FLogFolder := ALogFolder;

  // Ensure log folder exists
  if not TDirectory.Exists(FLogFolder) then
    TDirectory.CreateDirectory(FLogFolder);
end;

destructor TDebugLogger.Destroy;
begin
  FCS.Free;
  inherited;
end;

function TDebugLogger.GetLogFileName: string;
begin
  // Create log file name with date: cyai_debug_YYYYMMDD.log
  Result := TPath.Combine(FLogFolder,
    Format('cyai_debug_%s.log', [FormatDateTime('yyyymmdd', Now)]));
end;

function TDebugLogger.RedactHeaderValue(const AName, AValue: string): string;
// Redact sensitive values from headers for security
begin
  Result := AValue;

  // Redact Authorization headers (API keys, Bearer tokens)
  if SameText(AName, 'Authorization') or SameText(AName, 'x-api-key') then
    Result := '***REDACTED***'
  // Don't log api-key query parameters (some providers pass it this way)
  else if SameText(AName, 'api-key') then
    Result := '***REDACTED***';
end;

procedure TDebugLogger.Write(const AText: string);
// Thread-safe write to log file
var
  FileName: string;
begin
  FileName := GetLogFileName;

  FCS.Enter;
  try
    // Append to file
    TFile.AppendAllText(FileName, AText, TEncoding.UTF8);
  except
    // Silently fail if logging fails - don't break the app
  end;
  FCS.Leave;
end;

procedure TDebugLogger.LogRequest(const AMethod, AURL: string; const AHeaders: TNetHeaders; const ABody: string);
var
  SB: TStringBuilder;
  Header: TNameValuePair;
  Timestamp: string;
  BodyPreview: string;
begin
  Timestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
  SB := TStringBuilder.Create;

  try
    SB.AppendLine('=== REQUEST START ===');
    SB.AppendLine('Timestamp: ' + Timestamp);
    SB.AppendLine('Method: ' + AMethod);
    SB.AppendLine('URL: ' + AURL);
    SB.AppendLine('Headers:');

    for Header in AHeaders do
    begin
      SB.AppendFormat('  %s: %s', [Header.Name, RedactHeaderValue(Header.Name, Header.Value)]);
      SB.AppendLine;
    end;

    SB.AppendLine('Body:');
    if ABody <> '' then
    begin
      // Limit body preview for very large requests
      if Length(ABody) > 5000 then
      begin
        BodyPreview := Copy(ABody, 1, 5000) + #13#10'... [truncated, total length: ' + IntToStr(Length(ABody)) + ' chars]';
        SB.AppendLine(BodyPreview);
      end
      else
        SB.AppendLine(ABody);
    end
    else
      SB.AppendLine('(empty)');

    SB.AppendLine('=== REQUEST END ===');
    SB.AppendLine;

    Write(SB.ToString);
  finally
    SB.Free;
  end;
end;

procedure TDebugLogger.LogResponse(const AStatusCode: Integer; const AHeaders: TNetHeaders; const ABody: string; const AError: string);
var
  SB: TStringBuilder;
  Header: TNameValuePair;
  Timestamp: string;
  BodyPreview: string;
  StatusText: string;
begin
  Timestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
  SB := TStringBuilder.Create;

  try
    SB.AppendLine('=== RESPONSE START ===');
    SB.AppendLine('Timestamp: ' + Timestamp);

    if AError <> '' then
    begin
      SB.AppendLine('Status: ERROR - ' + AError);
    end
    else
    begin
      StatusText := IntToStr(AStatusCode);
      case AStatusCode of
        200: StatusText := StatusText + ' OK';
        201: StatusText := StatusText + ' Created';
        204: StatusText := StatusText + ' No Content';
        400: StatusText := StatusText + ' Bad Request';
        401: StatusText := StatusText + ' Unauthorized';
        403: StatusText := StatusText + ' Forbidden';
        404: StatusText := StatusText + ' Not Found';
        429: StatusText := StatusText + ' Too Many Requests';
        500: StatusText := StatusText + ' Internal Server Error';
        502: StatusText := StatusText + ' Bad Gateway';
        503: StatusText := StatusText + ' Service Unavailable';
      end;
      SB.AppendLine('Status: ' + StatusText);
    end;

    SB.AppendLine('Headers:');
    for Header in AHeaders do
    begin
      SB.AppendFormat('  %s: %s', [Header.Name, Header.Value]);
      SB.AppendLine;
    end;

    SB.AppendLine('Body:');
    if ABody <> '' then
    begin
      // Limit body preview for very large responses
      if Length(ABody) > 10000 then
      begin
        BodyPreview := Copy(ABody, 1, 10000) + #13#10'... [truncated, total length: ' + IntToStr(Length(ABody)) + ' chars]';
        SB.AppendLine(BodyPreview);
      end
      else
        SB.AppendLine(ABody);
    end
    else
      SB.AppendLine('(empty)');

    SB.AppendLine('=== RESPONSE END ===');
    SB.AppendLine;

    Write(SB.ToString);
  finally
    SB.Free;
  end;
end;

end.
