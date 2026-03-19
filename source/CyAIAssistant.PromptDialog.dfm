object PromptDialog: TPromptDialog
  Left = 0
  Top = 0
  Caption = 'Cypheros AI Assistant - Code Assistant'
  ClientHeight = 606
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object Splitter: TSplitter
    Left = 280
    Top = 94
    Width = 4
    Height = 464
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    ExplicitHeight = 506
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 56
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alTop
    BevelOuter = bvNone
    Color = 12607488
    ParentBackground = False
    TabOrder = 0
    StyleElements = [seFont, seBorder]
    object LabelTitle: TLabel
      Left = 0
      Top = 0
      Width = 900
      Height = 56
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alClient
      Caption = '  Cypheros AI Assistant - Select a prompt and submit your code'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindow
      Font.Height = -18
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitWidth = 536
      ExplicitHeight = 25
    end
  end
  object PanelProvider: TPanel
    Left = 0
    Top = 56
    Width = 900
    Height = 38
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object LabelProvider: TLabel
      Left = 10
      Top = 11
      Width = 47
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Provider:'
    end
    object LabelModel: TLabel
      Left = 215
      Top = 11
      Width = 37
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Model:'
    end
    object ComboProvider: TComboBox
      Left = 70
      Top = 8
      Width = 130
      Height = 23
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Style = csDropDownList
      TabOrder = 0
      OnChange = ComboProviderChange
      Items.Strings = (
        'Claude (Anthropic)'
        'GPT (OpenAI)'
        'Ollama (Local)'
        'Groq'
        'Mistral')
    end
    object EditModel: TEdit
      Left = 260
      Top = 8
      Width = 200
      Height = 23
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      TabOrder = 1
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 558
    Width = 900
    Height = 48
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      900
      48)
    object LabelStatus: TLabel
      Left = 10
      Top = 16
      Width = 35
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Ready.'
    end
    object CheckStripFences: TCheckBox
      Left = 316
      Top = 15
      Width = 230
      Height = 17
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Auto-strip ``` fences from result'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object ProgressBar: TProgressBar
      Left = 10
      Top = 14
      Width = 300
      Height = 20
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Style = pbstMarquee
      TabOrder = 1
      Visible = False
    end
    object BtnSubmit: TButton
      Left = 570
      Top = 9
      Width = 130
      Height = 30
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Send to AI'
      Default = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 2
      OnClick = BtnSubmitClick
    end
    object BtnStop: TButton
      Left = 710
      Top = 9
      Width = 80
      Height = 30
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Stop'
      Enabled = False
      TabOrder = 3
      OnClick = BtnStopClick
    end
    object BtnCancel: TButton
      Left = 800
      Top = 9
      Width = 90
      Height = 30
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = '&Cancel'
      ModalResult = 2
      TabOrder = 4
      OnClick = BtnCancelClick
    end
  end
  object PanelLeft: TPanel
    Left = 0
    Top = 94
    Width = 280
    Height = 464
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 3
    object LabelPrompts: TLabel
      Left = 0
      Top = 0
      Width = 280
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alTop
      Caption = '  Prompt Template'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitWidth = 103
    end
    object LabelCustom: TLabel
      Left = 0
      Top = 15
      Width = 280
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alTop
      Caption = '  Custom Prefix (prepended to prompt)'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitWidth = 217
    end
    object ListPrompts: TListBox
      Left = 0
      Top = 30
      Width = 280
      Height = 200
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alTop
      ItemHeight = 15
      TabOrder = 0
      OnClick = ListPromptsClick
    end
    object MemoCustomPrefix: TMemo
      Left = 0
      Top = 230
      Width = 280
      Height = 234
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
      TabOrder = 1
      OnChange = MemoCustomPrefixChange
    end
  end
  object PanelRight: TPanel
    Left = 284
    Top = 94
    Width = 616
    Height = 464
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 4
    object LabelCode: TLabel
      Left = 0
      Top = 0
      Width = 616
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alTop
      Caption = '  Selected Code  (read-only preview)'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitWidth = 202
    end
    object LabelFinal: TLabel
      Left = 0
      Top = 15
      Width = 616
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alTop
      Caption = '  Final Prompt Preview (sent to AI)'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitWidth = 190
    end
    object MemoCode: TMemo
      Left = 0
      Top = 30
      Width = 616
      Height = 200
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alTop
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
    object MemoFinalPrompt: TMemo
      Left = 0
      Top = 230
      Width = 616
      Height = 234
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
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 1
      WordWrap = False
    end
  end
end
