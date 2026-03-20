object AboutDialog: TAboutDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'About Cypheros AI Assistant'
  ClientHeight = 351
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindow
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  DesignSize = (
    400
    351)
  TextHeight = 15
  object LabelVersion: TLabel
    Left = 20
    Top = 76
    Width = 41
    Height = 15
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'Version:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object LabelDev: TLabel
    Left = 20
    Top = 100
    Width = 112
    Height = 15
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'Developer: Frank Siek'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object Bevel1: TBevel
    Left = 12
    Top = 126
    Width = 376
    Height = 8
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Shape = bsTopLine
  end
  object LabelLicenseGPLText: TLabel
    Left = 20
    Top = 140
    Width = 252
    Height = 15
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'This software is open source, released under the'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object LinkLicenseGPL: TLabel
    Left = 20
    Top = 158
    Width = 226
    Height = 15
    Cursor = crHandPoint
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'GNU General Public License v2 (GPL-2.0)'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold, fsUnderline]
    ParentFont = False
    OnClick = LinkLicenseGPLClick
  end
  object Bevel2: TBevel
    Left = 12
    Top = 269
    Width = 376
    Height = 8
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akBottom]
    Shape = bsTopLine
    ExplicitTop = 279
  end
  object LinkWebsite: TLabel
    Left = 122
    Top = 283
    Width = 142
    Height = 15
    Cursor = crHandPoint
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akBottom]
    Caption = 'https://www.cypheros.de'
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold, fsUnderline]
    ParentColor = False
    ParentFont = False
    StyleElements = []
    OnClick = LinkWebsiteClick
    OnMouseEnter = LinkMouseEnter
    OnMouseLeave = LinkMouseLeave
  end
  object LabelLicenseMITText: TLabel
    Left = 20
    Top = 184
    Width = 314
    Height = 15
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'The SSH-Pascal parts of this software are released under the'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object LinkLicenseMIT: TLabel
    Left = 20
    Top = 202
    Width = 63
    Height = 15
    Cursor = crHandPoint
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'MIT license'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold, fsUnderline]
    ParentFont = False
    OnClick = LinkLicenseMITClick
  end
  object LabelSourceCode: TLabel
    Left = 20
    Top = 228
    Width = 65
    Height = 15
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'Source code'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object LinkSourceCode: TLabel
    Left = 20
    Top = 246
    Width = 312
    Height = 15
    Cursor = crHandPoint
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'https://github.com/Cypheros-de/AI-Assistant-for-Delphi'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold, fsUnderline]
    ParentFont = False
    OnClick = LinkSourceCodeClick
  end
  object PanelHeader: TPanel
    Left = 0
    Top = 0
    Width = 400
    Height = 56
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alTop
    Alignment = taLeftJustify
    BevelOuter = bvNone
    Caption = '   Cypheros AI Assistant'
    Color = 12607488
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindow
    Font.Height = -23
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentBackground = False
    ParentFont = False
    TabOrder = 0
    StyleElements = [seFont, seBorder]
  end
  object BtnClose: TButton
    Left = 150
    Top = 313
    Width = 80
    Height = 28
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Close'
    Default = True
    ModalResult = 1
    TabOrder = 1
  end
end
