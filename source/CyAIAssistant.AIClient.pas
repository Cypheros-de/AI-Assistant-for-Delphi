unit CyAIAssistant.AIClient;

// CyAIAssistant.AIClient.pas
// Unified async AI client supporting Claude, OpenAI, Ollama, Groq, Mistral.
//
// Cancellation
// ------------
// Call Cancel from the main thread at any time.  The implementation stores the
// live THTTPClient in FActiveHTTP (guarded by FCritSec).  Cancel frees it,
// which causes the blocking HTTP.Post to raise an ENetException, which is
// caught inside the sender procedure.  When the callback fires it checks
// FCancelled and silently drops the result instead of calling ACallback.

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient,
  System.Net.URLClient,
  System.JSON,
  System.Threading,
  System.SyncObjs,
  CyAIAssistant.Settings;

type
  TAIResultCallback = reference to procedure(const AResult: string; const AError: string);

  TChatRole = (crUser, crAssistant);

  TChatMessage = record
    Role: TChatRole;
    Content: string;
  end;

  TAIClient = class
  private
    FCritSec: TCriticalSection;
    FActiveHTTP: THTTPClient; // nil when idle, set while a request is running
    FCancelled: Boolean;

    // Helpers to register / unregister the active HTTP client
    procedure SetActiveHTTP(AHTTP: THTTPClient);
    procedure ClearActiveHTTP;

    // Single-turn senders
    procedure SendClaude(const APrompt: string; ACallback: TAIResultCallback);
    procedure SendZai(const APrompt: string; ACallback: TAIResultCallback);
    procedure SendOpenAI(const APrompt: string; ACallback: TAIResultCallback);
    procedure SendOllama(const APrompt: string; ACallback: TAIResultCallback);
    procedure SendOpenAICompatible(const APrompt, AEndpoint, AAPIKey, AModel: string; ACallback: TAIResultCallback);

    // Multi-turn chat senders
    procedure SendClaudeChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
    procedure SendZaiChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
    procedure SendOpenAIChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
    procedure SendOllamaChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
    procedure SendOpenAICompatibleChat(const AHistory: TArray<TChatMessage>; const AEndpoint, AAPIKey, AModel: string; ACallback: TAIResultCallback);

    // Ollama code completion via /api/generate
    procedure SendOllamaGenerate(const APrefix, ASuffix: string; ACallback: TAIResultCallback);
    function BuildOllamaGenerateJSON(const APrefix: string): string;
    function ReadOllamaGenerateStream(const AStreamData: string): string;

    // Gemini
    procedure SendGemini(const APrompt: string; ACallback: TAIResultCallback);
    procedure SendGeminiChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
    function BuildGeminiJSON(const APrompt: string): string;
    function BuildChatGeminiJSON(const AHistory: TArray<TChatMessage>): string;
    function ExtractGeminiResponse(const AJSON: string): string;
    function GeminiEndpointURL: string;

    // JSON builders
    function BuildClaudeJSON(const APrompt: string): string;
    function BuildZaiJSON(const APrompt: string): string;
    function BuildOpenAIJSON(const APrompt: string): string;
    function BuildOllamaJSON(const APrompt: string): string;
    function BuildChatClaudeJSON(const AHistory: TArray<TChatMessage>): string;
    function BuildChatZaiJSON(const AHistory: TArray<TChatMessage>): string;
    function BuildChatOpenAIJSON(const AHistory: TArray<TChatMessage>; const AModel: string): string;
    function BuildChatOllamaJSON(const AHistory: TArray<TChatMessage>): string;

    // Response extractors
    function ExtractClaudeResponse(const AJSON: string): string;
    function ExtractZaiResponse(const AJSON: string): string;
    function ExtractOpenAIResponse(const AJSON: string): string;
    function ExtractOllamaResponse(const AJSON: string): string;
    function ReadOllamaStream(const AStreamData: string): string;

    function StripCodeFences(const AText: string): string;
    function RoleToStr(ARole: TChatRole): string;

    // Create and destroy the HTTP client, registering it as the active one
    function CreateHTTP(AConnTimeout, AResponseTimeout: Integer): THTTPClient;
    procedure DestroyHTTP(var AHTTP: THTTPClient);
  public
    constructor Create;
    destructor Destroy; override;

    // Abort the running request (safe to call from main thread at any time)
    procedure Cancel;

    // Single-turn
    procedure SendAsync(const APrompt: string; ACallback: TAIResultCallback);

    // Multi-turn chat
    procedure SendChatAsync(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);

    // Ollama-only code completion using /api/generate with FIM (fill-in-middle)
    procedure SendCompletionAsync(const APrefix, ASuffix: string; ACallback: TAIResultCallback);
  end;

implementation

uses
  System.NetEncoding;

// TAIClient

constructor TAIClient.Create;
begin
  inherited Create;
  FCritSec := TCriticalSection.Create;
end;

destructor TAIClient.Destroy;
begin
  Cancel; // abort any running request
  FCritSec.Free;
  inherited;
end;

procedure TAIClient.SetActiveHTTP(AHTTP: THTTPClient);
begin
  FCritSec.Enter;
  try
    FActiveHTTP := AHTTP;
    FCancelled := False;
  finally
    FCritSec.Leave;
  end;
end;

procedure TAIClient.ClearActiveHTTP;
begin
  FCritSec.Enter;
  try
    FActiveHTTP := nil;
  finally
    FCritSec.Leave;
  end;
end;

procedure TAIClient.Cancel;
var
  HTTP: THTTPClient;
begin
  FCritSec.Enter;
  try
    FCancelled := True;
    HTTP := FActiveHTTP;
    FActiveHTTP := nil;
  finally
    FCritSec.Leave;
  end;
  // Freeing the HTTP client from outside the worker thread aborts the
  // blocking Post / Get call, causing it to raise an exception.
  if HTTP <> nil then
    HTTP.Free;
end;

function TAIClient.CreateHTTP(AConnTimeout, AResponseTimeout: Integer): THTTPClient;
begin
  Result := THTTPClient.Create;
  Result.ConnectionTimeout := AConnTimeout;
  Result.ResponseTimeout := AResponseTimeout;
  SetActiveHTTP(Result);
end;

procedure TAIClient.DestroyHTTP(var AHTTP: THTTPClient);
begin
  ClearActiveHTTP;
  FreeAndNil(AHTTP);
end;

// ---------------------------------------------------------------------------
// JSON builders (unchanged from previous version)
// ---------------------------------------------------------------------------

function TAIClient.BuildClaudeJSON(const APrompt: string): string;
const
  SYSTEM_PROMPT = 'You are an expert Delphi/Pascal developer. ' + 'Return ONLY the raw Delphi/Pascal source code — no markdown, no code fences, ' +
    'no ``` markers, no explanations before or after the code. ' + 'Use 2-space indentation. Follow Delphi naming conventions (T prefix for types, ' +
    'F prefix for fields). Output plain text that can be pasted directly into the IDE.';
var
  Root: TJSONObject;
  Messages: TJSONArray;
  Msg: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.ClaudeModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('system', SYSTEM_PROMPT);
    Messages := TJSONArray.Create;
    Msg := TJSONObject.Create;
    Msg.AddPair('role', 'user');
    Msg.AddPair('content', APrompt);
    Messages.Add(Msg);
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildZaiJSON(const APrompt: string): string;
const
  SYSTEM_PROMPT = 'You are an expert Delphi/Pascal developer. ' + 'Return ONLY the raw Delphi/Pascal source code — no markdown, no code fences, ' +
    'no ``` markers, no explanations before or after the code. ' + 'Use 2-space indentation. Follow Delphi naming conventions (T prefix for types, ' +
    'F prefix for fields). Output plain text that can be pasted directly into the IDE.';
var
  Root: TJSONObject;
  Messages: TJSONArray;
  Msg: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.ClaudeModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('system', SYSTEM_PROMPT);
    Messages := TJSONArray.Create;
    Msg := TJSONObject.Create;
    Msg.AddPair('role', 'user');
    Msg.AddPair('content', APrompt);
    Messages.Add(Msg);
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildOpenAIJSON(const APrompt: string): string;
var
  Root, Msg, SystemMsg: TJSONObject;
  Messages: TJSONArray;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.OpenAIModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('temperature', TJSONNumber.Create(GSettings.Temperature));
    Messages := TJSONArray.Create;
    SystemMsg := TJSONObject.Create;
    SystemMsg.AddPair('role', 'system');
    SystemMsg.AddPair('content', 'You are an expert Delphi/Pascal developer. ' + 'Return ONLY the raw Delphi/Pascal source code — no markdown, no code fences, '
      + 'no ``` markers, no explanations before or after the code. ' + 'Use 2-space indentation. Follow Delphi naming conventions. ' +
      'Output plain text that can be pasted directly into the IDE.');
    Messages.Add(SystemMsg);
    Msg := TJSONObject.Create;
    Msg.AddPair('role', 'user');
    Msg.AddPair('content', APrompt);
    Messages.Add(Msg);
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildOllamaJSON(const APrompt: string): string;
var
  Root, Msg, OllamaSystem, Options: TJSONObject;
  Messages: TJSONArray;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.OllamaModel);
    Root.AddPair('stream', TJSONBool.Create(True));
    Options := TJSONObject.Create;
    Options.AddPair('temperature', TJSONNumber.Create(GSettings.Temperature));
    Options.AddPair('num_predict', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('options', Options);
    Messages := TJSONArray.Create;
    OllamaSystem := TJSONObject.Create;
    OllamaSystem.AddPair('role', 'system');
    OllamaSystem.AddPair('content', 'You are an expert Delphi/Pascal developer. Return ONLY Pascal source code.');
    Messages.Add(OllamaSystem);
    Msg := TJSONObject.Create;
    Msg.AddPair('role', 'user');
    Msg.AddPair('content', APrompt);
    Messages.Add(Msg);
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildChatClaudeJSON(const AHistory: TArray<TChatMessage>): string;
const
  SYSTEM_PROMPT = 'You are an expert Delphi/Pascal developer. ' + 'When generating files, wrap each file in a fenced code block whose ' +
    'opening fence contains the suggested filename, for example:' + #13#10 + '```pascal MyUnit.pas' + #13#10 + '...code...' + #13#10 + '```' + #13#10 +
    'Supported extensions: .pas .dpr .dpk .dfm .dproj .groupproj .ini .txt. ' + 'Use 2-space indentation. Follow Delphi naming conventions.';
var
  Root: TJSONObject;
  Messages: TJSONArray;
  Msg: TJSONObject;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.ClaudeModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('system', SYSTEM_PROMPT);
    Messages := TJSONArray.Create;
    for I := 0 to High(AHistory) do
    begin
      Msg := TJSONObject.Create;
      Msg.AddPair('role', RoleToStr(AHistory[I].Role));
      Msg.AddPair('content', AHistory[I].Content);
      Messages.Add(Msg);
    end;
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildChatZaiJSON(const AHistory: TArray<TChatMessage>): string;
const
  SYSTEM_PROMPT = 'You are an expert Delphi/Pascal developer. ' + 'When generating files, wrap each file in a fenced code block whose ' +
    'opening fence contains the suggested filename, for example:' + #13#10 + '```pascal MyUnit.pas' + #13#10 + '...code...' + #13#10 + '```' + #13#10 +
    'Supported extensions: .pas .dpr .dpk .dfm .dproj .groupproj .ini .txt. ' + 'Use 2-space indentation. Follow Delphi naming conventions.';
var
  Root: TJSONObject;
  Messages: TJSONArray;
  Msg: TJSONObject;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.ClaudeModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('system', SYSTEM_PROMPT);
    Messages := TJSONArray.Create;
    for I := 0 to High(AHistory) do
    begin
      Msg := TJSONObject.Create;
      Msg.AddPair('role', RoleToStr(AHistory[I].Role));
      Msg.AddPair('content', AHistory[I].Content);
      Messages.Add(Msg);
    end;
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildChatOpenAIJSON(const AHistory: TArray<TChatMessage>; const AModel: string): string;
const
  SYSTEM_CONTENT = 'You are an expert Delphi/Pascal developer. ' + 'When generating files, wrap each file in a fenced code block whose ' +
    'opening fence contains the suggested filename, for example: ' + '```pascal MyUnit.pas ... ```. ' +
    'Supported extensions: .pas .dpr .dpk .dfm .dproj .groupproj .ini .txt. ' + 'Use 2-space indentation. Follow Delphi naming conventions.';
var
  Root: TJSONObject;
  Messages: TJSONArray;
  SystemMsg: TJSONObject;
  Msg: TJSONObject;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', AModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('temperature', TJSONNumber.Create(GSettings.Temperature));
    Messages := TJSONArray.Create;
    SystemMsg := TJSONObject.Create;
    SystemMsg.AddPair('role', 'system');
    SystemMsg.AddPair('content', SYSTEM_CONTENT);
    Messages.Add(SystemMsg);
    for I := 0 to High(AHistory) do
    begin
      Msg := TJSONObject.Create;
      Msg.AddPair('role', RoleToStr(AHistory[I].Role));
      Msg.AddPair('content', AHistory[I].Content);
      Messages.Add(Msg);
    end;
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildChatOllamaJSON(const AHistory: TArray<TChatMessage>): string;
const
  SYSTEM_CONTENT = 'You are an expert Delphi/Pascal developer. ' + 'When generating files, wrap each file in a fenced code block with a filename hint. ' +
    'Use 2-space indentation. Follow Delphi naming conventions.';
var
  Root: TJSONObject;
  Messages: TJSONArray;
  SystemMsg: TJSONObject;
  Options: TJSONObject;
  Msg: TJSONObject;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.OllamaModel);
    Root.AddPair('stream', TJSONBool.Create(True));
    Options := TJSONObject.Create;
    Options.AddPair('temperature', TJSONNumber.Create(GSettings.Temperature));
    Options.AddPair('num_predict', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('options', Options);
    Messages := TJSONArray.Create;
    SystemMsg := TJSONObject.Create;
    SystemMsg.AddPair('role', 'system');
    SystemMsg.AddPair('content', SYSTEM_CONTENT);
    Messages.Add(SystemMsg);
    for I := 0 to High(AHistory) do
    begin
      Msg := TJSONObject.Create;
      Msg.AddPair('role', RoleToStr(AHistory[I].Role));
      Msg.AddPair('content', AHistory[I].Content);
      Messages.Add(Msg);
    end;
    Root.AddPair('messages', Messages);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Response extractors (unchanged)
// ---------------------------------------------------------------------------

function TAIClient.ExtractClaudeResponse(const AJSON: string): string;
var
  Root: TJSONObject;
  Content: TJSONArray;
  ContentItem: TJSONObject;
  ErrObj: TJSONObject;
begin
  Result := '';
  Root := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if Root = nil then
    Exit;
  try
    if Root.GetValue('error') <> nil then
    begin
      ErrObj := Root.GetValue('error') as TJSONObject;
      if ErrObj <> nil then
        raise Exception.Create('Claude API Error: ' + ErrObj.GetValue<string>('message', 'Unknown error'));
    end;
    Content := Root.GetValue('content') as TJSONArray;
    if (Content = nil) or (Content.Count = 0) then
      Exit;
    ContentItem := Content.Items[0] as TJSONObject;
    if ContentItem <> nil then
      Result := ContentItem.GetValue<string>('text', '');
  finally
    Root.Free;
  end;
end;

function TAIClient.ExtractZaiResponse(const AJSON: string): string;
var
  Root: TJSONObject;
  Content: TJSONArray;
  ChoiceObj, MessageObj: TJSONObject;
  ErrObj: TJSONObject;
  ChoicesArr: TJSONArray;
  function FixJSONString(const AJSON: string): string;
  begin
    // Replace literal NewLines with escaped \n
    Result := StringReplace(AJSON, #13#10, '\n', [rfReplaceAll]);
    Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
    Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
    // Replace literal Tabs with escaped \t
    Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
  end;
begin
  Result := '';
  Root := TJSONObject.ParseJSONValue(FixJSONString(AJSON)) as TJSONObject;
  if Root = nil then
    Exit;
  try
    if Root.GetValue('error') <> nil then
    begin
      ErrObj := Root.GetValue('error') as TJSONObject;
      if ErrObj <> nil then
        raise Exception.Create('Z.ai API Error: ' + ErrObj.GetValue<string>('message', 'Unknown error'));
    end;
    ChoicesArr := Root.GetValue('choices') as TJSONArray;
    if (ChoicesArr <> nil) and (ChoicesArr.Count > 0) then
    begin
      ChoiceObj := ChoicesArr.Items[0] as TJSONObject;
      if ChoiceObj <> nil then
      begin
        MessageObj := ChoiceObj.GetValue('message') as TJSONObject;
        if MessageObj <> nil then
          Result := MessageObj.GetValue('content').Value;
      end;
    end;
  finally
    Root.Free;
  end;
end;

function TAIClient.ExtractOpenAIResponse(const AJSON: string): string;
var
  Root: TJSONObject;
  Choices: TJSONArray;
  Choice: TJSONObject;
  Message: TJSONObject;
  ErrObj: TJSONObject;
begin
  Result := '';
  Root := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if Root = nil then
    Exit;
  try
    if Root.GetValue('error') <> nil then
    begin
      ErrObj := Root.GetValue('error') as TJSONObject;
      if ErrObj <> nil then
        raise Exception.Create('OpenAI API Error: ' + ErrObj.GetValue<string>('message', 'Unknown error'));
    end;
    Choices := Root.GetValue('choices') as TJSONArray;
    if (Choices = nil) or (Choices.Count = 0) then
      Exit;
    Choice := Choices.Items[0] as TJSONObject;
    if Choice = nil then
      Exit;
    Message := Choice.GetValue('message') as TJSONObject;
    if Message = nil then
      Exit;
    Result := Message.GetValue<string>('content', '');
  finally
    Root.Free;
  end;
end;

// Parses a newline-delimited stream of Ollama JSON chunks (stream: true)
// and concatenates all message.content fragments into a single string.
// Each line is a JSON object; the final line has "done": true.
function TAIClient.ReadOllamaStream(const AStreamData: string): string;
var
  Lines: TStringList;
  Line: string;
  Chunk: TJSONObject;
  MsgObj: TJSONObject;
  I: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  Lines := TStringList.Create;
  try
    Lines.Text := AStreamData;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then Continue;
      Chunk := TJSONObject.ParseJSONValue(Line) as TJSONObject;
      if Chunk = nil then Continue;
      try
        if Chunk.GetValue('error') <> nil then
          raise Exception.Create('Ollama error: ' +
            Chunk.GetValue<string>('error', 'Unknown error'));
        MsgObj := Chunk.GetValue('message') as TJSONObject;
        if MsgObj <> nil then
          SB.Append(MsgObj.GetValue<string>('content', ''));
      finally
        Chunk.Free;
      end;
    end;
    Result := SB.ToString;
  finally
    Lines.Free;
    SB.Free;
  end;
end;

function TAIClient.ExtractOllamaResponse(const AJSON: string): string;
var
  Root: TJSONObject;
  Message: TJSONObject;
begin
  Result := '';
  Root := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if Root = nil then
    Exit;
  try
    if Root.GetValue('error') <> nil then
      raise Exception.Create('Ollama Error: ' + Root.GetValue<string>('error', 'Unknown error'));
    Message := Root.GetValue('message') as TJSONObject;
    if Message <> nil then
      Result := Message.GetValue<string>('content', '');
  finally
    Root.Free;
  end;
end;

function TAIClient.StripCodeFences(const AText: string): string;
var
  Lines: TStringList;
  I: Integer;
  StartIdx: Integer;
  EndIdx: Integer;
  Line: string;
  SB: TStringBuilder;
begin
  Result := Trim(AText);
  Lines := TStringList.Create;
  try
    Lines.Text := Result;
    StartIdx := -1;
    EndIdx := -1;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if (StartIdx < 0) and (Copy(Line, 1, 3) = '```') then
      begin
        StartIdx := I;
        Continue;
      end;
      if (StartIdx >= 0) and (Line = '```') then
        EndIdx := I;
    end;
    if (StartIdx >= 0) and (EndIdx > StartIdx) then
    begin
      SB := TStringBuilder.Create;
      try
        for I := StartIdx + 1 to EndIdx - 1 do
        begin
          SB.Append(Lines[I]);
          if I < EndIdx - 1 then
            SB.AppendLine;
        end;
        Result := SB.ToString;
      finally
        SB.Free;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function TAIClient.RoleToStr(ARole: TChatRole): string;
begin
  if ARole = crUser then
    Result := 'user'
  else
    Result := 'assistant';
end;

// ---------------------------------------------------------------------------
// Single-turn senders
// ---------------------------------------------------------------------------

procedure TAIClient.SendClaude(const APrompt: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 120000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json'), TNameValuePair.Create('x-api-key', GSettings.ClaudeAPIKey),
      TNameValuePair.Create('anthropic-version', '2023-06-01')];
    RequestBody := TStringStream.Create(BuildClaudeJSON(APrompt), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GSettings.ClaudeEndpoint, RequestBody, nil, Headers);
        ResultText := StripCodeFences(ExtractClaudeResponse(Response.ContentAsString(TEncoding.UTF8)));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendZai(const APrompt: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 120000);
  try
    Headers := [TNameValuePair.Create('Authorization', 'Bearer ' + GSettings.ClaudeAPIKey), TNameValuePair.Create('Content-Type', 'application/json')];

    RequestBody := TStringStream.Create(BuildZaiJSON(APrompt), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GSettings.ClaudeEndpoint, RequestBody, nil, Headers);
        ResultText := ExtractZaiResponse(Response.ContentAsString(TEncoding.UTF8));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendOpenAI(const APrompt: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 120000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json'), TNameValuePair.Create('Authorization', 'Bearer ' + GSettings.OpenAIAPIKey)];
    RequestBody := TStringStream.Create(BuildOpenAIJSON(APrompt), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GSettings.OpenAIEndpoint, RequestBody, nil, Headers);
        ResultText := StripCodeFences(ExtractOpenAIResponse(Response.ContentAsString(TEncoding.UTF8)));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendOllama(const APrompt: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody, ResponseStream: TStringStream;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(10000, 300000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json')];
    RequestBody := TStringStream.Create(BuildOllamaJSON(APrompt), TEncoding.UTF8);
    ResponseStream := TStringStream.Create('', TEncoding.UTF8);
    try
      try
        HTTP.Post(GSettings.OllamaEndpoint, RequestBody, ResponseStream, Headers);
        ResultText := StripCodeFences(ReadOllamaStream(ResponseStream.DataString));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := 'Ollama error (is it running?): ' + E.Message;
      end;
    finally
      RequestBody.Free;
      ResponseStream.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendOpenAICompatible(const APrompt, AEndpoint, AAPIKey, AModel: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
  Root, Msg, SystemMsg: TJSONObject;
  Messages: TJSONArray;
  JSON: string;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', AModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(GSettings.MaxTokens));
    Root.AddPair('temperature', TJSONNumber.Create(GSettings.Temperature));
    Messages := TJSONArray.Create;
    SystemMsg := TJSONObject.Create;
    SystemMsg.AddPair('role', 'system');
    SystemMsg.AddPair('content', 'You are an expert Delphi/Pascal developer. ' + 'Return ONLY the raw Delphi/Pascal source code — no markdown, no code fences. '
      + 'Use 2-space indentation. Follow Delphi naming conventions.');
    Messages.Add(SystemMsg);
    Msg := TJSONObject.Create;
    Msg.AddPair('role', 'user');
    Msg.AddPair('content', APrompt);
    Messages.Add(Msg);
    Root.AddPair('messages', Messages);
    JSON := Root.ToJSON;
  finally
    Root.Free;
  end;

  HTTP := CreateHTTP(30000, 120000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json'), TNameValuePair.Create('Authorization', 'Bearer ' + AAPIKey)];
    RequestBody := TStringStream.Create(JSON, TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(AEndpoint, RequestBody, nil, Headers);
        ResultText := StripCodeFences(ExtractOpenAIResponse(Response.ContentAsString(TEncoding.UTF8)));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

// ---------------------------------------------------------------------------
// Ollama code completion via /api/generate (FIM — fill-in-middle)
// ---------------------------------------------------------------------------

function TAIClient.BuildOllamaGenerateJSON(const APrefix: string): string;
const
  SYSTEM_PROMPT =
    'You are a Delphi/Pascal code completion engine.' + #10 +
    'Rules (MUST follow):' + #10 +
    '1. Output ONLY the raw Delphi/Pascal source code that belongs at <|cursor|>.' + #10 +
    '2. Do NOT repeat, echo, or paraphrase anything that appears before <|cursor|>.' + #10 +
    '3. Do NOT write any English sentences, explanations, analysis, or suggestions.' + #10 +
    '4. Do NOT use markdown, code fences, or ``` blocks.' + #10 +
    '5. Stop as soon as the current statement or block is logically complete.' + #10 +
    'If you cannot produce a valid completion, output a single semicolon.';
var
  Root, Options: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('model', GSettings.OllamaCompletionModel);
    Root.AddPair('system', SYSTEM_PROMPT);
    Root.AddPair('prompt', APrefix + '<|cursor|>');
    Root.AddPair('stream', TJSONBool.Create(True));

    // Stop sequences: halt before the model starts re-generating the whole unit.
    // These patterns only appear at the start of a new top-level Delphi file.
    var Stops := TJSONArray.Create;
    Stops.Add(#10'unit ');
    Stops.Add(#10'interface'#10);
    Stops.Add(#10'implementation'#10);
    Stops.Add('<|cursor|>');
    Root.AddPair('stop', Stops);

    Options := TJSONObject.Create;
    Options.AddPair('temperature', TJSONNumber.Create(0.1));
    Options.AddPair('num_predict', TJSONNumber.Create(256));
    Root.AddPair('options', Options);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

// Parses an NDJSON stream from /api/generate (each line has a "response" field).
function TAIClient.ReadOllamaGenerateStream(const AStreamData: string): string;
var
  Lines: TStringList;
  Line: string;
  Chunk: TJSONObject;
  I: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  Lines := TStringList.Create;
  try
    Lines.Text := AStreamData;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then Continue;
      Chunk := TJSONObject.ParseJSONValue(Line) as TJSONObject;
      if Chunk = nil then Continue;
      try
        if Chunk.GetValue('error') <> nil then
          raise Exception.Create('Ollama error: ' +
            Chunk.GetValue<string>('error', 'Unknown error'));
        SB.Append(Chunk.GetValue<string>('response', ''));
      finally
        Chunk.Free;
      end;
    end;
    Result := SB.ToString;
  finally
    Lines.Free;
    SB.Free;
  end;
end;

procedure TAIClient.SendOllamaGenerate(const APrefix, ASuffix: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody, ResponseStream: TStringStream;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
  BaseURL: string;
  GenerateURL: string;
begin
  // Derive /api/generate URL from the configured chat endpoint
  BaseURL := GSettings.OllamaEndpoint;
  BaseURL := StringReplace(BaseURL, '/api/chat', '', [rfReplaceAll]);
  BaseURL := StringReplace(BaseURL, '/api/generate', '', [rfReplaceAll]);
  while (Length(BaseURL) > 0) and (BaseURL[Length(BaseURL)] = '/') do
    SetLength(BaseURL, Length(BaseURL) - 1);
  GenerateURL := BaseURL + '/api/generate';

  HTTP := CreateHTTP(10000, 120000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json')];
    RequestBody := TStringStream.Create(BuildOllamaGenerateJSON(APrefix), TEncoding.UTF8);
    ResponseStream := TStringStream.Create('', TEncoding.UTF8);
    try
      try
        HTTP.Post(GenerateURL, RequestBody, ResponseStream, Headers);
        ResultText := ReadOllamaGenerateStream(ResponseStream.DataString);

      except
        on E: Exception do
          if not FCancelled then
            ErrorText := 'Ollama completion error: ' + E.Message;
      end;
    finally
      RequestBody.Free;
      ResponseStream.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendCompletionAsync(const APrefix, ASuffix: string; ACallback: TAIResultCallback);
begin
  TTask.Run(
    procedure
    begin
      SendOllamaGenerate(APrefix, ASuffix, ACallback);
    end);
end;

// ---------------------------------------------------------------------------
// Google Gemini  (generateContent REST API)
// ---------------------------------------------------------------------------

// Builds the full endpoint URL including model and API key.
// Base endpoint: https://generativelanguage.googleapis.com/v1beta/models
// Full URL:      {base}/{model}:generateContent?key={API_KEY}
function TAIClient.GeminiEndpointURL: string;
begin
  Result := GSettings.GeminiEndpoint;
  while (Length(Result) > 0) and (Result[Length(Result)] = '/') do
    SetLength(Result, Length(Result) - 1);
  Result := Result + '/' + GSettings.GeminiModel + ':generateContent?key=' + GSettings.GeminiAPIKey;
end;

function TAIClient.BuildGeminiJSON(const APrompt: string): string;
const
  SYSTEM_TEXT = 'You are an expert Delphi/Pascal developer. ' +
    'Return ONLY the raw Delphi/Pascal source code — no markdown, no code fences, ' +
    'no explanations before or after the code. ' +
    'Use 2-space indentation. Follow Delphi naming conventions (T prefix for types, ' +
    'F prefix for fields). Output plain text that can be pasted directly into the IDE.';
var
  Root, SysInstruct, SysPart, GenConfig: TJSONObject;
  SysPartsArr, Contents, PartsArr: TJSONArray;
  UserMsg, UserPart: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    SysInstruct := TJSONObject.Create;
    SysPartsArr := TJSONArray.Create;
    SysPart := TJSONObject.Create;
    SysPart.AddPair('text', SYSTEM_TEXT);
    SysPartsArr.Add(SysPart);
    SysInstruct.AddPair('parts', SysPartsArr);
    Root.AddPair('system_instruction', SysInstruct);

    Contents := TJSONArray.Create;
    UserMsg := TJSONObject.Create;
    UserMsg.AddPair('role', 'user');
    PartsArr := TJSONArray.Create;
    UserPart := TJSONObject.Create;
    UserPart.AddPair('text', APrompt);
    PartsArr.Add(UserPart);
    UserMsg.AddPair('parts', PartsArr);
    Contents.Add(UserMsg);
    Root.AddPair('contents', Contents);

    GenConfig := TJSONObject.Create;
    GenConfig.AddPair('maxOutputTokens', TJSONNumber.Create(GSettings.MaxTokens));
    GenConfig.AddPair('temperature', TJSONNumber.Create(GSettings.Temperature));
    Root.AddPair('generationConfig', GenConfig);

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.BuildChatGeminiJSON(const AHistory: TArray<TChatMessage>): string;
const
  SYSTEM_TEXT = 'You are an expert Delphi/Pascal developer. ' +
    'When generating files, wrap each file in a fenced code block whose ' +
    'opening fence contains the suggested filename, for example:' + #10 +
    '```pascal MyUnit.pas' + #10 + '...code...' + #10 + '```' + #10 +
    'Supported extensions: .pas .dpr .dpk .dfm .dproj .groupproj .ini .txt. ' +
    'Use 2-space indentation. Follow Delphi naming conventions.';
var
  Root, SysInstruct, SysPart, GenConfig: TJSONObject;
  SysPartsArr, Contents, PartsArr: TJSONArray;
  Msg, Part: TJSONObject;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    SysInstruct := TJSONObject.Create;
    SysPartsArr := TJSONArray.Create;
    SysPart := TJSONObject.Create;
    SysPart.AddPair('text', SYSTEM_TEXT);
    SysPartsArr.Add(SysPart);
    SysInstruct.AddPair('parts', SysPartsArr);
    Root.AddPair('system_instruction', SysInstruct);

    Contents := TJSONArray.Create;
    for I := 0 to High(AHistory) do
    begin
      Msg := TJSONObject.Create;
      // Gemini uses 'user' / 'model' (not 'assistant')
      if AHistory[I].Role = crUser then
        Msg.AddPair('role', 'user')
      else
        Msg.AddPair('role', 'model');
      PartsArr := TJSONArray.Create;
      Part := TJSONObject.Create;
      Part.AddPair('text', AHistory[I].Content);
      PartsArr.Add(Part);
      Msg.AddPair('parts', PartsArr);
      Contents.Add(Msg);
    end;
    Root.AddPair('contents', Contents);

    GenConfig := TJSONObject.Create;
    GenConfig.AddPair('maxOutputTokens', TJSONNumber.Create(GSettings.MaxTokens));
    GenConfig.AddPair('temperature', TJSONNumber.Create(GSettings.Temperature));
    Root.AddPair('generationConfig', GenConfig);

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TAIClient.ExtractGeminiResponse(const AJSON: string): string;
var
  Root, ErrObj, Candidate, Content, Part: TJSONObject;
  Candidates, Parts: TJSONArray;
begin
  Result := '';
  Root := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if Root = nil then
    Exit;
  try
    if Root.GetValue('error') <> nil then
    begin
      ErrObj := Root.GetValue('error') as TJSONObject;
      if ErrObj <> nil then
        raise Exception.Create('Gemini API Error: ' + ErrObj.GetValue<string>('message', 'Unknown error'));
    end;
    Candidates := Root.GetValue('candidates') as TJSONArray;
    if (Candidates = nil) or (Candidates.Count = 0) then
      Exit;
    Candidate := Candidates.Items[0] as TJSONObject;
    if Candidate = nil then Exit;
    Content := Candidate.GetValue('content') as TJSONObject;
    if Content = nil then Exit;
    Parts := Content.GetValue('parts') as TJSONArray;
    if (Parts = nil) or (Parts.Count = 0) then Exit;
    Part := Parts.Items[0] as TJSONObject;
    if Part <> nil then
      Result := Part.GetValue<string>('text', '');
  finally
    Root.Free;
  end;
end;

procedure TAIClient.SendGemini(const APrompt: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 120000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json')];
    RequestBody := TStringStream.Create(BuildGeminiJSON(APrompt), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GeminiEndpointURL, RequestBody, nil, Headers);
        ResultText := StripCodeFences(ExtractGeminiResponse(Response.ContentAsString(TEncoding.UTF8)));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendGeminiChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 180000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json')];
    RequestBody := TStringStream.Create(BuildChatGeminiJSON(AHistory), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GeminiEndpointURL, RequestBody, nil, Headers);
        ResultText := ExtractGeminiResponse(Response.ContentAsString(TEncoding.UTF8));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendAsync(const APrompt: string; ACallback: TAIResultCallback);
begin
  TTask.Run(
    procedure
    begin
      case GSettings.Provider of
        apClaude:
          SendClaude(APrompt, ACallback);
        apZai:
          SendZai(APrompt, ACallback);
        apOpenAI:
          SendOpenAI(APrompt, ACallback);
        apOllama:
          SendOllama(APrompt, ACallback);
        apGroq:
          SendOpenAICompatible(APrompt, GSettings.GroqEndpoint, GSettings.GroqAPIKey, GSettings.GroqModel, ACallback);
        apMistral:
          SendOpenAICompatible(APrompt, GSettings.MistralEndpoint, GSettings.MistralAPIKey, GSettings.MistralModel, ACallback);
        apGemini:
          SendGemini(APrompt, ACallback);
      end;
    end);
end;

// ---------------------------------------------------------------------------
// Multi-turn chat senders
// ---------------------------------------------------------------------------

procedure TAIClient.SendClaudeChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 180000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json'), TNameValuePair.Create('x-api-key', GSettings.ClaudeAPIKey),
      TNameValuePair.Create('anthropic-version', '2023-06-01')];

    RequestBody := TStringStream.Create(BuildChatClaudeJSON(AHistory), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GSettings.ClaudeEndpoint, RequestBody, nil, Headers);
        ResultText := ExtractClaudeResponse(Response.ContentAsString(TEncoding.UTF8));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message + #13#10 + Response.ContentAsString(TEncoding.UTF8);
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendZaiChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 180000);
  try
    Headers := [TNameValuePair.Create('Authorization', 'Bearer ' + GSettings.ClaudeAPIKey), TNameValuePair.Create('Content-Type', 'application/json')];

    RequestBody := TStringStream.Create(BuildChatZaiJSON(AHistory), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GSettings.ClaudeEndpoint, RequestBody, nil, Headers);
        ResultText := ExtractZaiResponse(Response.ContentAsString(TEncoding.UTF8));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendOpenAIChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 180000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json'), TNameValuePair.Create('Authorization', 'Bearer ' + GSettings.OpenAIAPIKey)];
    RequestBody := TStringStream.Create(BuildChatOpenAIJSON(AHistory, GSettings.OpenAIModel), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(GSettings.OpenAIEndpoint, RequestBody, nil, Headers);
        ResultText := ExtractOpenAIResponse(Response.ContentAsString(TEncoding.UTF8));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendOllamaChat(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody, ResponseStream: TStringStream;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(10000, 300000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json')];
    RequestBody := TStringStream.Create(BuildChatOllamaJSON(AHistory), TEncoding.UTF8);
    ResponseStream := TStringStream.Create('', TEncoding.UTF8);
    try
      try
        HTTP.Post(GSettings.OllamaEndpoint, RequestBody, ResponseStream, Headers);
        ResultText := ReadOllamaStream(ResponseStream.DataString);
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := 'Ollama error (is it running?): ' + E.Message;
      end;
    finally
      RequestBody.Free;
      ResponseStream.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendOpenAICompatibleChat(const AHistory: TArray<TChatMessage>; const AEndpoint, AAPIKey, AModel: string; ACallback: TAIResultCallback);
var
  HTTP: THTTPClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  Headers: TNetHeaders;
  ResultText: string;
  ErrorText: string;
begin
  HTTP := CreateHTTP(30000, 180000);
  try
    Headers := [TNameValuePair.Create('Content-Type', 'application/json'), TNameValuePair.Create('Authorization', 'Bearer ' + AAPIKey)];
    RequestBody := TStringStream.Create(BuildChatOpenAIJSON(AHistory, AModel), TEncoding.UTF8);
    try
      try
        Response := HTTP.Post(AEndpoint, RequestBody, nil, Headers);
        ResultText := ExtractOpenAIResponse(Response.ContentAsString(TEncoding.UTF8));
      except
        on E: Exception do
          if not FCancelled then
            ErrorText := E.Message;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    DestroyHTTP(HTTP);
  end;
  if FCancelled then
    Exit;
  TThread.Synchronize(nil,
    procedure
    begin
      ACallback(ResultText, ErrorText);
    end);
end;

procedure TAIClient.SendChatAsync(const AHistory: TArray<TChatMessage>; ACallback: TAIResultCallback);
begin
  TTask.Run(
    procedure
    begin
      case GSettings.Provider of
        apClaude:
          SendClaudeChat(AHistory, ACallback);
        apZai:
          SendZaiChat(AHistory, ACallback);
        apOpenAI:
          SendOpenAIChat(AHistory, ACallback);
        apOllama:
          SendOllamaChat(AHistory, ACallback);
        apGroq:
          SendOpenAICompatibleChat(AHistory, GSettings.GroqEndpoint, GSettings.GroqAPIKey, GSettings.GroqModel, ACallback);
        apMistral:
          SendOpenAICompatibleChat(AHistory, GSettings.MistralEndpoint, GSettings.MistralAPIKey, GSettings.MistralModel, ACallback);
        apGemini:
          SendGeminiChat(AHistory, ACallback);
      end;
    end);
end;

end.
