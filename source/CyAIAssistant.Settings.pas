unit CyAIAssistant.Settings;

// CyAIAssistant.Settings.pas
// Persistent settings for AI provider configuration and prompt templates.
//
// Registry layout:
// HKCU\Software\CyAIAssistant\Delphi\          <- provider / general settings
// HKCU\Software\CyAIAssistant\Delphi\Prompts\  <- prompt template subkeys
//
// Each prompt is stored as a numbered subkey ("000", "001", ...) with two
// string values:
// Name     - display name shown in the prompt list
// Template - prompt text; use [CODE] where selected code should appear
// and [CUSTOM_PREFIX] for an optional user-typed prefix
//
// On the very first run the Prompts subkey does not exist, so the 10
// built-in defaults are written to the registry automatically.  After that
// the user can add, edit, reorder, or delete any entry - including the
// defaults - via the Settings dialog.

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Win.Registry,
  Winapi.Windows;

const
  REG_ROOT = 'Software\CyAIAssistant\Delphi';
  REG_PROMPTS = 'Software\CyAIAssistant\Delphi\Prompts';

type
  TAIProvider = (apClaude, apOpenAI, apOllama, apGroq, apMistral, apGemini);

  TPromptTemplate = record
    Name: string;
    Template: string;
  end;

  // Alias kept so existing PromptDialog / SettingsDialog code compiles unchanged
  TCustomPrompt = TPromptTemplate;

  TAISettings = class
  private
    FProvider: TAIProvider;
    FClaudeAPIKey: string;
    FClaudeModel: string;
    FClaudeEndpoint: string;
    FOpenAIAPIKey: string;
    FOpenAIModel: string;
    FOpenAIEndpoint: string;
    FOllamaEndpoint: string;
    FOllamaModel: string;
    FGroqAPIKey: string;
    FGroqModel: string;
    FGroqEndpoint: string;
    FMistralAPIKey: string;
    FMistralModel: string;
    FMistralEndpoint: string;
    FGeminiAPIKey: string;
    FGeminiModel: string;
    FGeminiEndpoint: string;
    FMaxTokens: Integer;
    FTemperature: Double;
    FLastPromptIndex: Integer;
    FOllamaCompletionModel: string;
    FCodeCompletionEnabled: Boolean;
    FPrompts: TList<TPromptTemplate>;
    procedure SeedDefaultPrompts;
    procedure LoadPrompts;
    procedure SavePrompts;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load;
    procedure Save;
    procedure AddPrompt(const AName, ATemplate: string);
    procedure RemovePrompt(Index: Integer);

    // Old name forwarded for source compatibility
    procedure AddCustomPrompt(const AName, ATemplate: string);
    procedure RemoveCustomPrompt(Index: Integer);

    property Provider: TAIProvider read FProvider write FProvider;
    property ClaudeAPIKey: string read FClaudeAPIKey write FClaudeAPIKey;
    property ClaudeModel: string read FClaudeModel write FClaudeModel;
    property ClaudeEndpoint: string read FClaudeEndpoint write FClaudeEndpoint;
    property OpenAIAPIKey: string read FOpenAIAPIKey write FOpenAIAPIKey;
    property OpenAIModel: string read FOpenAIModel write FOpenAIModel;
    property OpenAIEndpoint: string read FOpenAIEndpoint write FOpenAIEndpoint;
    property OllamaEndpoint: string read FOllamaEndpoint write FOllamaEndpoint;
    property OllamaModel: string read FOllamaModel write FOllamaModel;
    property GroqAPIKey: string read FGroqAPIKey write FGroqAPIKey;
    property GroqModel: string read FGroqModel write FGroqModel;
    property GroqEndpoint: string read FGroqEndpoint write FGroqEndpoint;
    property MistralAPIKey: string read FMistralAPIKey write FMistralAPIKey;
    property MistralModel: string read FMistralModel write FMistralModel;
    property MistralEndpoint: string read FMistralEndpoint write FMistralEndpoint;
    property GeminiAPIKey: string read FGeminiAPIKey write FGeminiAPIKey;
    property GeminiModel: string read FGeminiModel write FGeminiModel;
    property GeminiEndpoint: string read FGeminiEndpoint write FGeminiEndpoint;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property Temperature: Double read FTemperature write FTemperature;
    property LastPromptIndex: Integer read FLastPromptIndex write FLastPromptIndex;
    property OllamaCompletionModel: string read FOllamaCompletionModel write FOllamaCompletionModel;
    property CodeCompletionEnabled: Boolean read FCodeCompletionEnabled write FCodeCompletionEnabled;

    // Unified prompt list - all templates in display order
    property Prompts: TList<TPromptTemplate> read FPrompts;
    // Alias so SettingsDialog needs no changes
    property CustomPrompts: TList<TPromptTemplate> read FPrompts;
  end;

var
  GSettings: TAISettings;

implementation

// ---------------------------------------------------------------------------
// Default prompt templates written to registry on first run
// ---------------------------------------------------------------------------

procedure WriteDefaultPrompts(Reg: TRegistry);

  procedure W(const SubKey, AName, ATemplate: string);
  begin
    if Reg.OpenKey(REG_PROMPTS + '\' + SubKey, True) then
    begin
      Reg.WriteString('Name', AName);
      Reg.WriteString('Template', ATemplate);
      Reg.CloseKey;
    end;
  end;

const
  LF = #13#10;

begin
  W('000', 'Explain Code', 'Explain the following Delphi/Pascal code clearly and concisely. ' +
    'Describe what it does, how it works, and any important details:' + LF + LF + '```pascal' + LF + '{CODE}' + LF + '```');

  W('001', 'Find Bugs', 'Review the following Delphi/Pascal code for bugs, errors, and potential issues. ' +
    'List each problem found with a clear explanation and suggest a fix:' + LF + LF + '```pascal' + LF + '{CODE}' + LF + '```');

  W('002', 'Refactor & Improve', 'Refactor the following Delphi/Pascal code to improve its quality, readability, ' +
    'and performance. Return ONLY the improved code without explanation, ' + 'preserving all existing functionality:' + LF + LF + '```pascal' + LF + '{CODE}' +
    LF + '```');

  W('003', 'Add Comments / Documentation', 'Add comprehensive XML doc comments and inline comments to the following ' +
    'Delphi/Pascal code. Return ONLY the commented code:' + LF + LF + '```pascal' + LF + '{CODE}' + LF + '```');

  W('004', 'Write Unit Tests', 'Write DUnit/DUnitX unit tests for the following Delphi/Pascal code. ' + 'Cover normal cases, edge cases, and error conditions:'
    + LF + LF + '```pascal' + LF + '{CODE}' + LF + '```');

  W('005', 'Optimize Performance', 'Analyze the following Delphi/Pascal code for performance bottlenecks and ' +
    'optimize it. Return the optimized code with comments explaining each change:' + LF + LF + '```pascal' + LF + '{CODE}' + LF + '```');

  W('006', 'Convert to Modern Delphi', 'Update the following Delphi/Pascal code to use modern Delphi 11 features ' +
    'such as generics, anonymous methods, inline variables, RTTI, etc. ' + 'Return ONLY the modernized code:' + LF + LF + '```pascal' + LF + '{CODE}' +
    LF + '```');

  W('007', 'Add Error Handling', 'Add proper exception handling and error checking to the following Delphi/Pascal code. ' +
    'Use try/except/finally blocks and appropriate exception classes. ' + 'Return ONLY the updated code:' + LF + LF + '```pascal' + LF + '{CODE}' + LF + '```');

  W('008', 'Code Review', 'Perform a thorough code review of the following Delphi/Pascal code. ' +
    'Comment on: correctness, style, naming conventions, potential memory leaks, ' + 'thread safety, and best practices:' + LF + LF + '```pascal' + LF +
    '{CODE}' + LF + '```');

end;

// TAISettings

constructor TAISettings.Create;
begin
  inherited;
  FPrompts := TList<TPromptTemplate>.Create;
  FProvider := apClaude;
  FClaudeModel := 'claude-opus-4-5';
  FClaudeEndpoint := 'https://api.anthropic.com/v1/messages';
  FOpenAIModel := 'gpt-4o';
  FOpenAIEndpoint := 'https://api.openai.com/v1/chat/completions';
  FOllamaEndpoint := 'http://localhost:11434/api/chat';
  FOllamaModel := 'codellama';
  FGroqEndpoint := 'https://api.groq.com/openai/v1/chat/completions';
  FGroqModel := 'llama-3.3-70b-versatile';
  FMistralEndpoint := 'https://api.mistral.ai/v1/chat/completions';
  FMistralModel := 'mistral-large-latest';
  FGeminiEndpoint := 'https://generativelanguage.googleapis.com/v1beta/models';
  FGeminiModel := 'gemini-2.5-flash';
  FMaxTokens := 32768;
  FTemperature := 0.2;
  FLastPromptIndex := 0;
  FOllamaCompletionModel := 'codellama';
  FCodeCompletionEnabled := False;
  Load;
end;

destructor TAISettings.Destroy;
begin
  FPrompts.Free;
  inherited;
end;

procedure TAISettings.AddPrompt(const AName, ATemplate: string);
var
  P: TPromptTemplate;
begin
  P.Name := AName;
  P.Template := ATemplate;
  FPrompts.Add(P);
end;

procedure TAISettings.RemovePrompt(Index: Integer);
begin
  if (Index >= 0) and (Index < FPrompts.Count) then
    FPrompts.Delete(Index);
end;

procedure TAISettings.AddCustomPrompt(const AName, ATemplate: string);
begin
  AddPrompt(AName, ATemplate);
end;

procedure TAISettings.RemoveCustomPrompt(Index: Integer);
begin
  RemovePrompt(Index);
end;

// ---------------------------------------------------------------------------
// SeedDefaultPrompts - called on very first run when Prompts key is absent
// ---------------------------------------------------------------------------
procedure TAISettings.SeedDefaultPrompts;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    WriteDefaultPrompts(Reg);
  finally
    Reg.Free;
  end;
end;

// ---------------------------------------------------------------------------
// LoadPrompts - read all numbered subkeys into FPrompts
// ---------------------------------------------------------------------------
procedure TAISettings.LoadPrompts;
var
  Reg: TRegistry;
  SubKeys: TStringList;
  I: Integer;
  P: TPromptTemplate;
begin
  FPrompts.Clear;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    // First run: seed then re-open with a fresh read handle
    if not Reg.KeyExists(REG_PROMPTS) then
    begin
      Reg.Free;
      SeedDefaultPrompts;
      Reg := TRegistry.Create(KEY_READ);
      Reg.RootKey := HKEY_CURRENT_USER;
    end;

    if not Reg.OpenKey(REG_PROMPTS, False) then
      Exit;

    SubKeys := TStringList.Create;
    try
      Reg.GetKeyNames(SubKeys);
      Reg.CloseKey;
      SubKeys.Sort; // "000" < "001" < ... preserves insertion order

      for I := 0 to SubKeys.Count - 1 do
      begin
        if not Reg.OpenKey(REG_PROMPTS + '\' + SubKeys[I], False) then
          Continue;
        try
          if Reg.ValueExists('Name') and Reg.ValueExists('Template') then
          begin
            P.Name := Reg.ReadString('Name');
            P.Template := Reg.ReadString('Template');
            FPrompts.Add(P);
          end;
        finally
          Reg.CloseKey;
        end;
      end;
    finally
      SubKeys.Free;
    end;
  finally
    Reg.Free;
  end;
end;

// ---------------------------------------------------------------------------
// SavePrompts - wipe old Prompts tree, rewrite from FPrompts in current order
// ---------------------------------------------------------------------------
procedure TAISettings.SavePrompts;
var
  Reg: TRegistry;
  I: Integer;
  P: TPromptTemplate;
  SubKey: string;
begin
  Reg := TRegistry.Create(KEY_ALL_ACCESS);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    // Delete entire subtree so stale / reordered subkeys cannot linger
    if Reg.KeyExists(REG_PROMPTS) then
      Reg.DeleteKey(REG_PROMPTS);

    for I := 0 to FPrompts.Count - 1 do
    begin
      P := FPrompts[I];
      SubKey := Format('%.3d', [I]);
      if Reg.OpenKey(REG_PROMPTS + '\' + SubKey, True) then
      begin
        Reg.WriteString('Name', P.Name);
        Reg.WriteString('Template', P.Template);
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Load / Save  (provider & general settings only - prompts handled above)
// ---------------------------------------------------------------------------
procedure TAISettings.Load;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_ROOT, False) then
    begin
      try
        if Reg.ValueExists('Provider') then
          FProvider := TAIProvider(Reg.ReadInteger('Provider'));
        if Reg.ValueExists('ClaudeAPIKey') then
          FClaudeAPIKey := Reg.ReadString('ClaudeAPIKey');
        if Reg.ValueExists('ClaudeModel') then
          FClaudeModel := Reg.ReadString('ClaudeModel');
        if Reg.ValueExists('ClaudeEndpoint') then
          FClaudeEndpoint := Reg.ReadString('ClaudeEndpoint');
        if Reg.ValueExists('OpenAIAPIKey') then
          FOpenAIAPIKey := Reg.ReadString('OpenAIAPIKey');
        if Reg.ValueExists('OpenAIModel') then
          FOpenAIModel := Reg.ReadString('OpenAIModel');
        if Reg.ValueExists('OpenAIEndpoint') then
          FOpenAIEndpoint := Reg.ReadString('OpenAIEndpoint');
        if Reg.ValueExists('OllamaEndpoint') then
          FOllamaEndpoint := Reg.ReadString('OllamaEndpoint');
        if Reg.ValueExists('OllamaModel') then
          FOllamaModel := Reg.ReadString('OllamaModel');
        if Reg.ValueExists('GroqAPIKey') then
          FGroqAPIKey := Reg.ReadString('GroqAPIKey');
        if Reg.ValueExists('GroqModel') then
          FGroqModel := Reg.ReadString('GroqModel');
        if Reg.ValueExists('GroqEndpoint') then
          FGroqEndpoint := Reg.ReadString('GroqEndpoint');
        if Reg.ValueExists('MistralAPIKey') then
          FMistralAPIKey := Reg.ReadString('MistralAPIKey');
        if Reg.ValueExists('MistralModel') then
          FMistralModel := Reg.ReadString('MistralModel');
        if Reg.ValueExists('MistralEndpoint') then
          FMistralEndpoint := Reg.ReadString('MistralEndpoint');
        if Reg.ValueExists('GeminiAPIKey') then
          FGeminiAPIKey := Reg.ReadString('GeminiAPIKey');
        if Reg.ValueExists('GeminiModel') then
          FGeminiModel := Reg.ReadString('GeminiModel');
        if Reg.ValueExists('GeminiEndpoint') then
          FGeminiEndpoint := Reg.ReadString('GeminiEndpoint');
        if Reg.ValueExists('MaxTokens') then
          FMaxTokens := Reg.ReadInteger('MaxTokens');
        if Reg.ValueExists('Temperature') then
          FTemperature := Reg.ReadFloat('Temperature');
        if Reg.ValueExists('LastPromptIndex') then
          FLastPromptIndex := Reg.ReadInteger('LastPromptIndex');
        if Reg.ValueExists('OllamaCompletionModel') then
          FOllamaCompletionModel := Reg.ReadString('OllamaCompletionModel');
        if Reg.ValueExists('CodeCompletionEnabled') then
          FCodeCompletionEnabled := Reg.ReadBool('CodeCompletionEnabled');
      finally
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;

  LoadPrompts;
end;

procedure TAISettings.Save;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_ROOT, True) then
    begin
      try
        Reg.WriteInteger('Provider', Ord(FProvider));
        Reg.WriteString('ClaudeAPIKey', FClaudeAPIKey);
        Reg.WriteString('ClaudeModel', FClaudeModel);
        Reg.WriteString('ClaudeEndpoint', FClaudeEndpoint);
        Reg.WriteString('OpenAIAPIKey', FOpenAIAPIKey);
        Reg.WriteString('OpenAIModel', FOpenAIModel);
        Reg.WriteString('OpenAIEndpoint', FOpenAIEndpoint);
        Reg.WriteString('OllamaEndpoint', FOllamaEndpoint);
        Reg.WriteString('OllamaModel', FOllamaModel);
        Reg.WriteString('GroqAPIKey', FGroqAPIKey);
        Reg.WriteString('GroqModel', FGroqModel);
        Reg.WriteString('GroqEndpoint', FGroqEndpoint);
        Reg.WriteString('MistralAPIKey', FMistralAPIKey);
        Reg.WriteString('MistralModel', FMistralModel);
        Reg.WriteString('MistralEndpoint', FMistralEndpoint);
        Reg.WriteString('GeminiAPIKey', FGeminiAPIKey);
        Reg.WriteString('GeminiModel', FGeminiModel);
        Reg.WriteString('GeminiEndpoint', FGeminiEndpoint);
        Reg.WriteInteger('MaxTokens', FMaxTokens);
        Reg.WriteFloat('Temperature', FTemperature);
        Reg.WriteInteger('LastPromptIndex', FLastPromptIndex);
        Reg.WriteString('OllamaCompletionModel', FOllamaCompletionModel);
        Reg.WriteBool('CodeCompletionEnabled', FCodeCompletionEnabled);
      finally
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;

  SavePrompts;
end;

initialization

GSettings := TAISettings.Create;

finalization

FreeAndNil(GSettings);

end.
