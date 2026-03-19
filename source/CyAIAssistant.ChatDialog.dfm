object ChatDialog: TChatDialog
  Left = 0
  Top = 0
  Caption = 'Cypheros AI Assistant - AI Chat'
  ClientHeight = 513
  ClientWidth = 918
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 918
    Height = 44
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
    DesignSize = (
      918
      44)
    object LabelTitle: TLabel
      Left = 12
      Top = 6
      Width = 69
      Height = 28
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'AI Chat'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindow
      Font.Height = -20
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
    end
    object LabelProvider: TLabel
      Left = 160
      Top = 14
      Width = 47
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Provider:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object LabelModel: TLabel
      Left = 336
      Top = 14
      Width = 37
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Model:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object ComboProvider: TComboBox
      Left = 225
      Top = 10
      Width = 100
      Height = 23
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Style = csDropDownList
      TabOrder = 0
      OnChange = ComboProviderChange
      Items.Strings = (
        'Claude'
        'OpenAI'
        'Ollama'
        'Groq'
        'Mistral')
    end
    object EditModel: TEdit
      Left = 385
      Top = 10
      Width = 200
      Height = 23
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      ReadOnly = True
      TabOrder = 1
    end
    object BtnNewChat: TButton
      Left = 814
      Top = 9
      Width = 90
      Height = 26
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'New Chat'
      TabOrder = 2
      OnClick = BtnNewChatClick
    end
  end
  object PanelMain: TPanel
    Left = 0
    Top = 44
    Width = 918
    Height = 469
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object SplitterMain: TSplitter
      Left = 460
      Top = 0
      Width = 5
      Height = 469
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      ExplicitHeight = 604
    end
    object PanelChat: TPanel
      Left = 0
      Top = 0
      Width = 460
      Height = 469
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
      object PageControl: TPageControl
        Left = 0
        Top = 0
        Width = 460
        Height = 469
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        ActivePage = TabChat
        Align = alClient
        TabOrder = 0
        object TabChat: TTabSheet
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = '  Chat  '
          object LabelInput: TLabel
            Left = 0
            Top = 0
            Width = 452
            Height = 15
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Align = alTop
            Caption = '  Your message:'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
            Layout = tlCenter
            ExplicitWidth = 85
          end
          object MemoInput: TMemo
            Left = 0
            Top = 15
            Width = 452
            Height = 376
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Align = alClient
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            ScrollBars = ssVertical
            TabOrder = 0
          end
          object PanelChatBtns: TPanel
            Left = 0
            Top = 391
            Width = 452
            Height = 48
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Align = alBottom
            BevelOuter = bvNone
            TabOrder = 1
            object LabelStatus: TLabel
              Left = 340
              Top = 31
              Width = 100
              Height = 17
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Alignment = taCenter
              AutoSize = False
              Caption = ' '
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Segoe UI'
              Font.Style = []
              ParentFont = False
            end
            object BtnSend: TButton
              Left = 8
              Top = 9
              Width = 150
              Height = 30
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Caption = 'Send  (Ctrl+Enter)'
              TabOrder = 0
              OnClick = BtnSendClick
            end
            object BtnStop: TButton
              Left = 168
              Top = 9
              Width = 80
              Height = 30
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Caption = 'Stop'
              Enabled = False
              TabOrder = 1
              OnClick = BtnStopClick
            end
            object BtnClearInput: TButton
              Left = 258
              Top = 9
              Width = 70
              Height = 30
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Caption = 'Clear'
              TabOrder = 2
              OnClick = BtnClearInputClick
            end
            object ProgressBar: TProgressBar
              Left = 340
              Top = 16
              Width = 100
              Height = 16
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Style = pbstMarquee
              TabOrder = 3
              Visible = False
            end
          end
        end
        object TabFiles: TTabSheet
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = '  Files Found  '
          TabVisible = False
          object SplitterFiles: TSplitter
            Left = 200
            Top = 0
            Width = 5
            Height = 391
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            ExplicitHeight = 100
          end
          object PanelFileLeft: TPanel
            Left = 0
            Top = 0
            Width = 200
            Height = 391
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Align = alLeft
            BevelOuter = bvNone
            TabOrder = 0
            object LabelFiles: TLabel
              Left = 0
              Top = 0
              Width = 86
              Height = 15
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Align = alTop
              Caption = '  Detected Files'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -12
              Font.Name = 'Segoe UI'
              Font.Style = [fsBold]
              ParentFont = False
              Layout = tlCenter
            end
            object ListFiles: TListBox
              Left = 0
              Top = 15
              Width = 200
              Height = 376
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Align = alClient
              ItemHeight = 15
              TabOrder = 0
              OnClick = ListFilesClick
            end
          end
          object MemoFilePreview: TMemo
            Left = 205
            Top = 0
            Width = 247
            Height = 391
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
          object PanelFileBtns: TPanel
            Left = 0
            Top = 391
            Width = 452
            Height = 48
            Margins.Left = 5
            Margins.Top = 5
            Margins.Right = 5
            Margins.Bottom = 5
            Align = alBottom
            BevelOuter = bvNone
            TabOrder = 2
            object BtnSaveSelected: TButton
              Left = 8
              Top = 9
              Width = 130
              Height = 30
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Caption = 'Save Selected...'
              TabOrder = 0
              OnClick = BtnSaveSelectedClick
            end
            object BtnSaveAll: TButton
              Left = 148
              Top = 9
              Width = 100
              Height = 30
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Caption = 'Save All...'
              TabOrder = 1
              OnClick = BtnSaveAllClick
            end
            object BtnOpenInIDE: TButton
              Left = 258
              Top = 9
              Width = 100
              Height = 30
              Margins.Left = 5
              Margins.Top = 5
              Margins.Right = 5
              Margins.Bottom = 5
              Caption = 'Open in IDE'
              TabOrder = 2
              OnClick = BtnOpenInIDEClick
            end
          end
        end
      end
    end
    object PanelHistory: TPanel
      Left = 465
      Top = 0
      Width = 453
      Height = 469
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object LabelHistory: TLabel
        Left = 0
        Top = 0
        Width = 453
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alTop
        Caption = '  Conversation'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        Layout = tlCenter
        ExplicitWidth = 79
      end
      object RichHistory: TRichEdit
        Left = 0
        Top = 15
        Width = 453
        Height = 454
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alClient
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -10
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
        StyleElements = [seClient, seBorder]
      end
    end
  end
end
