object SettingsDialog: TSettingsDialog
  Left = 0
  Top = 0
  Caption = 'Cypheros AI Assistant - Settings'
  ClientHeight = 359
  ClientWidth = 700
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object PanelBottom: TPanel
    Left = 0
    Top = 311
    Width = 700
    Height = 48
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      700
      48)
    object BtnOK: TButton
      Left = 495
      Top = 9
      Width = 90
      Height = 30
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = BtnOKClick
    end
    object BtnCancel: TButton
      Left = 597
      Top = 9
      Width = 90
      Height = 30
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 700
    Height = 311
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    ActivePage = TabGeneral
    Align = alClient
    MultiLine = True
    TabOrder = 1
    object TabClaude: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Claude (Anthropic)  '
      object LblClaudeKey: TLabel
        Left = 16
        Top = 20
        Width = 43
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Key:'
      end
      object LblClaudeModel: TLabel
        Left = 16
        Top = 57
        Width = 37
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Model:'
      end
      object LblClaudeEndpoint: TLabel
        Left = 16
        Top = 93
        Width = 72
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Endpoint:'
      end
      object LblClaudeInfo: TLabel
        Left = 16
        Top = 132
        Width = 450
        Height = 30
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 
          'Get your API key at: https://console.anthropic.com'#13#10'The key is s' +
          'tored in the Windows registry under HKCU\Software\CyAIAssistant\' +
          'Delphi'
      end
      object Bevel3: TBevel
        Left = 10
        Top = 120
        Width = 650
        Height = 2
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Shape = bsTopLine
      end
      object EditClaudeKey: TEdit
        Left = 200
        Top = 17
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        PasswordChar = '*'
        TabOrder = 0
      end
      object EditClaudeModel: TComboBox
        Left = 200
        Top = 54
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        Items.Strings = (
          'claude-opus-4-6'
          'claude-opus-4-5'
          'claude-sonnet-4-6'
          'claude-sonnet-4-5'
          'claude-haiku-4-5'
          'claude-3-5-sonnet-20241022'
          'claude-3-opus-20240229')
      end
      object EditClaudeEndpoint: TEdit
        Left = 200
        Top = 90
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
    end
    object TabOpenAI: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  OpenAI / GPT  '
      object LblOpenAIKey: TLabel
        Left = 16
        Top = 20
        Width = 43
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Key:'
      end
      object LblOpenAIModel: TLabel
        Left = 16
        Top = 57
        Width = 37
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Model:'
      end
      object LblOpenAIEndpoint: TLabel
        Left = 16
        Top = 93
        Width = 72
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Endpoint:'
      end
      object LblOpenAIInfo: TLabel
        Left = 16
        Top = 132
        Width = 258
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Get your API key at: https://platform.openai.com'
      end
      object Bevel4: TBevel
        Left = 10
        Top = 120
        Width = 650
        Height = 2
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Shape = bsTopLine
      end
      object EditOpenAIKey: TEdit
        Left = 200
        Top = 17
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        PasswordChar = '*'
        TabOrder = 0
      end
      object EditOpenAIModel: TComboBox
        Left = 200
        Top = 54
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        Items.Strings = (
          'gpt-4o'
          'gpt-4o-mini'
          'gpt-4-turbo'
          'gpt-4'
          'gpt-3.5-turbo')
      end
      object EditOpenAIEndpoint: TEdit
        Left = 200
        Top = 90
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
    end
    object TabOllama: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Ollama (Local)  '
      object LblOllamaEndpoint: TLabel
        Left = 16
        Top = 20
        Width = 75
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Endpoint URL:'
      end
      object LblOllamaModel: TLabel
        Left = 16
        Top = 57
        Width = 81
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Primary Model:'
      end
      object LblOllamaCompletionModel: TLabel
        Left = 16
        Top = 132
        Width = 134
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Code Completion Model:'
      end
      object LblOllamaInfo: TLabel
        Left = 16
        Top = 204
        Width = 530
        Height = 60
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 
          'Install Ollama from https://ollama.ai  |  Pull a model: ollama p' +
          'ull qwen2.5-coder:7b'#13#10#13#10'Recommended for Chat: qwen2.5-coder:7b, ' +
          'codellama:13b, deepseek-coder:6.7b'#13#10'Recommended for Completion: ' +
          'qwen2.5-coder:1.5b, qwen2.5-coder:7b, starcoder2:3b, codellama:7' +
          'b'
      end
      object LblOllamaModelRating: TPanel
        Left = 448
        Top = 54
        Width = 120
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 7
        StyleElements = [seClient, seBorder]
      end
      object LblCompletionRating: TPanel
        Left = 451
        Top = 129
        Width = 120
        Height = 22
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 6
        StyleElements = [seClient, seBorder]
      end
      object EditOllamaEndpoint: TEdit
        Left = 200
        Top = 17
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 0
      end
      object ComboOllamaModel: TComboBox
        Left = 200
        Top = 54
        Width = 240
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        OnChange = ComboOllamaModelChange
      end
      object BtnTestOllama: TButton
        Left = 200
        Top = 90
        Width = 130
        Height = 26
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Test Connection'
        TabOrder = 2
        OnClick = BtnTestOllamaClick
      end
      object BtnLoadModels: TButton
        Left = 338
        Top = 90
        Width = 120
        Height = 26
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Reload Model List'
        TabOrder = 3
        OnClick = BtnLoadModelsClick
      end
      object ComboOllamaCompletionModel: TComboBox
        Left = 200
        Top = 129
        Width = 240
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 4
        OnChange = ComboOllamaCompletionModelChange
        Items.Strings = (
          'qwen2.5-coder:1.5b'
          'qwen2.5-coder:7b'
          'qwen2.5-coder:14b'
          'starcoder2:3b'
          'starcoder2:7b'
          'codellama:7b'
          'codellama:13b'
          'codellama:code'
          'codegemma:2b'
          'codegemma:7b'
          'deepseek-coder:1.3b'
          'deepseek-coder:6.7b')
      end
      object ChkCodeCompletion: TCheckBox
        Left = 200
        Top = 161
        Width = 340
        Height = 21
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Enable Code Completion (Ctrl+Alt+Space)'
        TabOrder = 5
      end
    end
    object TabGroq: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Groq  '
      object LblGroqKey: TLabel
        Left = 16
        Top = 20
        Width = 43
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Key:'
      end
      object LblGroqModel: TLabel
        Left = 16
        Top = 57
        Width = 37
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Model:'
      end
      object LblGroqEndpoint: TLabel
        Left = 16
        Top = 93
        Width = 72
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Endpoint:'
      end
      object LblGroqInfo: TLabel
        Left = 16
        Top = 132
        Width = 242
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Get your API key at: https://console.groq.com'
      end
      object Bevel5: TBevel
        Left = 10
        Top = 120
        Width = 650
        Height = 2
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Shape = bsTopLine
      end
      object EditGroqKey: TEdit
        Left = 200
        Top = 17
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        PasswordChar = '*'
        TabOrder = 0
      end
      object EditGroqModel: TComboBox
        Left = 200
        Top = 54
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        Items.Strings = (
          'llama-3.3-70b-versatile'
          'llama-3.1-70b-versatile'
          'llama-3.1-8b-instant'
          'mixtral-8x7b-32768'
          'gemma2-9b-it')
      end
      object EditGroqEndpoint: TEdit
        Left = 200
        Top = 90
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
    end
    object TabMistral: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Mistral  '
      object LblMistralKey: TLabel
        Left = 16
        Top = 20
        Width = 43
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Key:'
      end
      object LblMistralModel: TLabel
        Left = 16
        Top = 57
        Width = 37
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Model:'
      end
      object LblMistralEndpoint: TLabel
        Left = 16
        Top = 93
        Width = 72
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Endpoint:'
      end
      object LblMistralInfo: TLabel
        Left = 16
        Top = 132
        Width = 238
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Get your API key at: https://console.mistral.ai'
      end
      object Bevel6: TBevel
        Left = 10
        Top = 120
        Width = 650
        Height = 2
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Shape = bsTopLine
      end
      object EditMistralKey: TEdit
        Left = 200
        Top = 17
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        PasswordChar = '*'
        TabOrder = 0
      end
      object EditMistralModel: TComboBox
        Left = 200
        Top = 54
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        Items.Strings = (
          'mistral-large-latest'
          'mistral-medium-latest'
          'codestral-latest'
          'open-mixtral-8x22b'
          'open-mistral-7b')
      end
      object EditMistralEndpoint: TEdit
        Left = 200
        Top = 90
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
    end
    object TabGemini: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Gemini  '
      object LblGeminiKey: TLabel
        Left = 16
        Top = 20
        Width = 43
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Key:'
      end
      object LblGeminiModel: TLabel
        Left = 16
        Top = 57
        Width = 37
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Model:'
      end
      object LblGeminiEndpoint: TLabel
        Left = 16
        Top = 93
        Width = 72
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Endpoint:'
      end
      object LblGeminiInfo: TLabel
        Left = 16
        Top = 132
        Width = 319
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Get your API key at: https://aistudio.google.com/app/apikey'
      end
      object Bevel7: TBevel
        Left = 10
        Top = 120
        Width = 650
        Height = 2
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Shape = bsTopLine
      end
      object EditGeminiKey: TEdit
        Left = 200
        Top = 17
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        PasswordChar = '*'
        TabOrder = 0
      end
      object EditGeminiModel: TComboBox
        Left = 200
        Top = 54
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        Items.Strings = (
          'gemini-2.5-flash'
          'gemini-2.5-pro'
          'gemini-2.0-flash'
          'gemini-1.5-pro'
          'gemini-1.5-flash'
          'gemini-1.5-flash-8b')
      end
      object EditGeminiEndpoint: TEdit
        Left = 200
        Top = 90
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
    end
    object TabZai: TTabSheet
      Caption = 'GLM (Z.ai)'
      ImageIndex = 8
      object Label1: TLabel
        Left = 18
        Top = 22
        Width = 43
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Key:'
      end
      object Label2: TLabel
        Left = 18
        Top = 59
        Width = 37
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Model:'
      end
      object Label3: TLabel
        Left = 18
        Top = 95
        Width = 72
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'API Endpoint:'
      end
      object Label4: TLabel
        Left = 18
        Top = 134
        Width = 450
        Height = 75
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 
          'Get your API key at: https://z.ai/manage-apikey/apikey-list'#13#10'The' +
          ' key is stored in the Windows registry under HKCU\Software\CyAIA' +
          'ssistant\Delphi'#13#10#13#10'Coding plan user end point: https://api.z.ai/' +
          'api/coding/paas/v4'#13#10'Pay-as-you-go user end point: https://api.z.' +
          'ai/api/paas/v4/chat/completions'
      end
      object Bevel1: TBevel
        Left = 12
        Top = 122
        Width = 650
        Height = 2
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Shape = bsTopLine
      end
      object EditZaiKey: TEdit
        Left = 202
        Top = 19
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        PasswordChar = '*'
        TabOrder = 0
      end
      object EditZaiModel: TComboBox
        Left = 202
        Top = 56
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        Items.Strings = (
          'glm-5.1'
          'glm-5'
          'glm-5-turbo'
          'glm-4.7'
          'glm-4.7-flash'
          'glm-4.7-flashx'
          'glm-4.6'
          'glm-4.5'
          'glm-4.5-air'
          'glm-4.5-x'
          'glm-4.5-airx'
          'glm-4.5-flash'
          'glm-4-32b-0414-128k')
      end
      object EditZaiEndpoint: TEdit
        Left = 202
        Top = 92
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
    end
    object TabGeneral: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  General  '
      object LblDefaultProvider: TLabel
        Left = 16
        Top = 23
        Width = 88
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Default Provider:'
      end
      object LblMaxTokens: TLabel
        Left = 16
        Top = 59
        Width = 65
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Max Tokens:'
      end
      object LblTemperature: TLabel
        Left = 16
        Top = 95
        Width = 70
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Temperature:'
      end
      object LblGeneralInfo: TLabel
        Left = 16
        Top = 135
        Width = 359
        Height = 30
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 
          'Keyboard shortcut: Ctrl+Alt+A  (when a source code editor is act' +
          'ive)'#13#10'Access via: Tools > Cypheros AI Assistant > Code Assistant'
      end
      object ComboDefaultProvider: TComboBox
        Left = 200
        Top = 20
        Width = 200
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Style = csDropDownList
        TabOrder = 0
        Items.Strings = (
          'Claude (Anthropic)'
          'GPT (OpenAI)'
          'Ollama (Local)'
          'Groq'
          'Mistral'
          'Google Gemini'
          'GLM (Z.ai)')
      end
      object EditMaxTokens: TEdit
        Left = 200
        Top = 56
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
      end
      object EditTemperature: TEdit
        Left = 200
        Top = 92
        Width = 440
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
    end
    object TabCustomPrompts: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Prompt Templates  '
      object PanelPromptsLeft: TPanel
        Left = 0
        Top = 0
        Width = 220
        Height = 261
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alLeft
        BevelOuter = bvNone
        TabOrder = 0
        object LblPromptTemplates: TLabel
          Left = 0
          Top = 0
          Width = 108
          Height = 15
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alTop
          Caption = '  Prompt Templates'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          Layout = tlCenter
        end
        object ListCustomPrompts: TListBox
          Left = 0
          Top = 15
          Width = 220
          Height = 210
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alClient
          ItemHeight = 15
          TabOrder = 0
          OnClick = ListCustomPromptsClick
        end
        object PanelListBtns: TPanel
          Left = 0
          Top = 225
          Width = 220
          Height = 36
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object BtnMoveUp: TButton
            Left = 2
            Top = 4
            Width = 36
            Height = 28
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 'Up'
            TabOrder = 0
            OnClick = BtnMoveUpClick
          end
          object BtnMoveDown: TButton
            Left = 40
            Top = 4
            Width = 36
            Height = 28
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 'Dn'
            TabOrder = 1
            OnClick = BtnMoveDownClick
          end
          object BtnDeletePrompt: TButton
            Left = 80
            Top = 4
            Width = 36
            Height = 28
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 'Del'
            TabOrder = 2
            OnClick = BtnDeletePromptClick
          end
        end
      end
      object PanelPromptsRight: TPanel
        Left = 220
        Top = 0
        Width = 472
        Height = 261
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object PanelPromptTop: TPanel
          Left = 0
          Top = 0
          Width = 472
          Height = 62
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          DesignSize = (
            472
            62)
          object LblPromptName: TLabel
            Left = 8
            Top = 12
            Width = 78
            Height = 15
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 'Prompt Name:'
          end
          object LblTemplate: TLabel
            Left = 8
            Top = 40
            Width = 377
            Height = 15
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 
              'Template  ({CODE} = selected code,  {CUSTOM_PREFIX} = free-text ' +
              'box):'
          end
          object EditPromptName: TEdit
            Left = 120
            Top = 9
            Width = 342
            Height = 23
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
        end
        object PanelPromptBtns: TPanel
          Left = 0
          Top = 221
          Width = 472
          Height = 40
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object BtnAddPrompt: TButton
            Left = 4
            Top = 5
            Width = 100
            Height = 30
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 'Add New'
            TabOrder = 0
            OnClick = BtnAddPromptClick
          end
          object BtnUpdatePrompt: TButton
            Left = 112
            Top = 5
            Width = 130
            Height = 30
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 'Update Selected'
            TabOrder = 1
            OnClick = BtnUpdatePromptClick
          end
          object BtnClearFields: TButton
            Left = 250
            Top = 5
            Width = 100
            Height = 30
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Caption = 'Clear Fields'
            TabOrder = 2
            OnClick = BtnClearFieldsClick
          end
        end
        object MemoPromptTemplate: TMemo
          Left = 0
          Top = 62
          Width = 472
          Height = 159
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alClient
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -15
          Font.Name = 'Consolas'
          Font.Style = []
          ParentFont = False
          ScrollBars = ssVertical
          TabOrder = 2
        end
      end
    end
  end
end
