object DiffViewerForm: TDiffViewerForm
  Left = 0
  Top = 0
  Caption = 'Cypheros AI Assistant - Review Changes'
  ClientHeight = 571
  ClientWidth = 958
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
    Width = 958
    Height = 52
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
      Width = 958
      Height = 52
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Align = alClient
      Caption = '  Review AI Changes - Accept or discard the AI-generated code'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindow
      Font.Height = -18
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitWidth = 534
      ExplicitHeight = 25
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 519
    Width = 958
    Height = 52
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      958
      52)
    object LabelStats: TLabel
      Left = 10
      Top = 18
      Width = 91
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Computing diff...'
    end
    object BtnApply: TButton
      Left = 543
      Top = 10
      Width = 140
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Apply to Editor'
      Default = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      OnClick = BtnApplyClick
    end
    object BtnCopyNew: TButton
      Left = 698
      Top = 10
      Width = 140
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Copy AI Result'
      TabOrder = 1
      OnClick = BtnCopyClick
    end
    object BtnClose: TButton
      Left = 843
      Top = 10
      Width = 100
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'X  Close'
      TabOrder = 2
      OnClick = BtnCloseClick
    end
  end
  object PageControl: TPageControl
    Left = 0
    Top = 52
    Width = 958
    Height = 467
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    ActivePage = TabSideBySide
    Align = alClient
    TabOrder = 2
    ExplicitTop = 50
    ExplicitHeight = 469
    object TabSideBySide: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Side by Side Diff  '
      object SplitterSide: TSplitter
        Left = 467
        Top = 0
        Width = 4
        Height = 437
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        ExplicitLeft = 783
        ExplicitHeight = 442
      end
      object PanelOriginal: TPanel
        Left = 0
        Top = 0
        Width = 467
        Height = 437
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alLeft
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitHeight = 439
        object LabelOrig: TLabel
          Left = 0
          Top = 0
          Width = 467
          Height = 15
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alTop
          Caption = '  Original Code'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          Layout = tlCenter
          ExplicitWidth = 80
        end
        object MemoOriginal: TMemo
          Left = 0
          Top = 15
          Width = 467
          Height = 422
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
          TabOrder = 0
          WordWrap = False
          ExplicitHeight = 424
        end
      end
      object PanelNew: TPanel
        Left = 471
        Top = 0
        Width = 479
        Height = 437
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitHeight = 439
        object LabelNew: TLabel
          Left = 0
          Top = 0
          Width = 479
          Height = 15
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Align = alTop
          Caption = '  AI Generated Code'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          Layout = tlCenter
          ExplicitWidth = 112
        end
        object MemoNew: TMemo
          Left = 0
          Top = 15
          Width = 479
          Height = 422
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
          TabOrder = 0
          WordWrap = False
          ExplicitHeight = 424
        end
      end
    end
    object TabDiff: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  Unified Diff  '
      object MemoDiff: TRichEdit
        Left = 0
        Top = 0
        Width = 950
        Height = 439
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alClient
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -10
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
    object TabAIOnly: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = '  AI Result (editable)  '
      object MemoAIEdit: TMemo
        Left = 0
        Top = 0
        Width = 950
        Height = 439
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
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
  end
end
