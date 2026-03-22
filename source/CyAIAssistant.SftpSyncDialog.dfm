object SftpSyncDialog: TSftpSyncDialog
  Left = 0
  Top = 0
  Caption = 'SFTP Sync Settings'
  ClientHeight = 519
  ClientWidth = 650
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnClose = FormClose
  TextHeight = 15
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 650
    Height = 52
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alTop
    BevelOuter = bvNone
    Color = 12607488
    ParentBackground = False
    TabOrder = 1
    StyleElements = [seFont, seBorder]
    DesignSize = (
      650
      52)
    object LabelTitle: TLabel
      Left = 14
      Top = 14
      Width = 134
      Height = 21
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'SFTP Project Sync'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object LabelStatus: TLabel
      Left = 579
      Top = 17
      Width = 41
      Height = 15
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Inactive'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ExplicitLeft = 629
    end
    object PaintBox1: TPaintBox
      Left = 552
      Top = 14
      Width = 20
      Height = 20
      Anchors = [akTop, akRight]
      OnPaint = PaintBox1Paint
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 477
    Width = 650
    Height = 42
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      650
      42)
    object BtnStartStop: TButton
      Left = 10
      Top = 6
      Width = 110
      Height = 28
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Start Sync'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      OnClick = BtnStartStopClick
    end
    object BtnPushAll: TButton
      Left = 174
      Top = 6
      Width = 120
      Height = 28
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Push all to remote'
      Enabled = False
      TabOrder = 2
      OnClick = BtnPushAllClick
    end
    object BtnPullAll: TButton
      Left = 304
      Top = 6
      Width = 120
      Height = 28
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Pull all from remote'
      Enabled = False
      TabOrder = 3
      OnClick = BtnPullAllClick
    end
    object BtnClose: TButton
      Left = 560
      Top = 7
      Width = 80
      Height = 28
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Close'
      TabOrder = 1
      OnClick = BtnCloseClick
    end
  end
  object PageControl: TPageControl
    Left = 0
    Top = 52
    Width = 650
    Height = 425
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    ActivePage = TabConnection
    Align = alClient
    TabOrder = 0
    object TabConnection: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Connection'
      object LabelHost: TLabel
        Left = 14
        Top = 20
        Width = 78
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'SFTP Host / IP:'
      end
      object LabelPort: TLabel
        Left = 14
        Top = 56
        Width = 25
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Port:'
      end
      object LabelUser: TLabel
        Left = 14
        Top = 92
        Width = 56
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Username:'
      end
      object LabelPass: TLabel
        Left = 14
        Top = 128
        Width = 53
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Password:'
      end
      object LabelKeyPath: TLabel
        Left = 14
        Top = 189
        Width = 116
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Private Key (optional):'
      end
      object LabelKeyNote: TLabel
        Left = 160
        Top = 169
        Width = 412
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 
          'Leave Password empty and supply both key files for key-based aut' +
          'hentication.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelPubKeyPath: TLabel
        Left = 14
        Top = 226
        Width = 113
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Public Key (optional):'
      end
      object EditHost: TEdit
        Left = 160
        Top = 16
        Width = 300
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 0
      end
      object EditPort: TEdit
        Left = 160
        Top = 52
        Width = 80
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 1
        Text = '22'
      end
      object EditUser: TEdit
        Left = 160
        Top = 88
        Width = 200
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
      object EditPass: TEdit
        Left = 160
        Top = 124
        Width = 200
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        PasswordChar = '*'
        TabOrder = 3
      end
      object EditKeyPath: TEdit
        Left = 160
        Top = 186
        Width = 360
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 4
      end
      object BtnBrowseKey: TButton
        Left = 528
        Top = 186
        Width = 80
        Height = 24
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Browse...'
        TabOrder = 5
        OnClick = BtnBrowseKeyClick
      end
      object EditPubKeyPath: TEdit
        Left = 160
        Top = 222
        Width = 360
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 6
      end
      object BtnBrowsePubKey: TButton
        Left = 528
        Top = 222
        Width = 80
        Height = 24
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Browse...'
        TabOrder = 7
        OnClick = BtnBrowsePubKeyClick
      end
      object BtnTestConnection: TButton
        Left = 488
        Top = 14
        Width = 120
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Test Connection'
        TabOrder = 8
        OnClick = BtnTestConnectionClick
      end
    end
    object TabPaths: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Paths'
      object LabelLocalBase: TLabel
        Left = 14
        Top = 20
        Width = 107
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Local Project Folder:'
      end
      object LabelRemoteBase: TLabel
        Left = 14
        Top = 64
        Width = 98
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Remote Base Path:'
      end
      object LabelPathNote: TLabel
        Left = 14
        Top = 108
        Width = 455
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 
          'The remote path for each file is built by appending its relative' +
          ' path to the remote base.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object EditLocalBase: TEdit
        Left = 160
        Top = 16
        Width = 380
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 0
      end
      object BtnBrowseLocal: TButton
        Left = 548
        Top = 16
        Width = 80
        Height = 24
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Browse...'
        TabOrder = 1
        OnClick = BtnBrowseLocalClick
      end
      object EditRemoteBase: TEdit
        Left = 160
        Top = 60
        Width = 460
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 2
      end
      object CheckIncludeSubDirs: TCheckBox
        Left = 14
        Top = 144
        Width = 250
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Include sub-directories'
        Checked = True
        State = cbChecked
        TabOrder = 3
      end
      object CheckAutoDetectProject: TCheckBox
        Left = 14
        Top = 172
        Width = 400
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Auto-detect project folder from active project on Start'
        Checked = True
        State = cbChecked
        TabOrder = 4
      end
    end
    object TabOptions: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Options'
      object LabelInterval: TLabel
        Left = 14
        Top = 20
        Width = 124
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Sync interval (seconds):'
      end
      object LabelIntervalNote: TLabel
        Left = 84
        Top = 41
        Width = 303
        Height = 26
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Alignment = taCenter
        Caption = 
          'Changed files are batched and uploaded once per interval.'#13#10'Minim' +
          'um: 1 second.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelWatchedExts: TLabel
        Left = 14
        Top = 188
        Width = 127
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Watched file extensions:'
      end
      object LabelWatchedExtsHint: TLabel
        Left = 178
        Top = 210
        Width = 419
        Height = 13
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Alignment = taCenter
        Caption = 
          'Space or comma separated. Example: .pas .dfm .dpr .dpk .dproj .r' +
          'es .rc .txt .ini .xml'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelQuietPeriod: TLabel
        Left = 12
        Top = 150
        Width = 165
        Height = 15
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Remote quiet period (seconds):'
      end
      object EditInterval: TEdit
        Left = 200
        Top = 16
        Width = 80
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 0
        Text = '5'
      end
      object CheckStartWithProject: TCheckBox
        Left = 14
        Top = 90
        Width = 420
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Start sync automatically when a project is opened in the IDE'
        TabOrder = 1
      end
      object CheckBackupEnabled: TCheckBox
        Left = 14
        Top = 116
        Width = 500
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 
          'Backup overwritten local files to __backup\backup_NNN.zip before' +
          ' downloading'
        TabOrder = 2
      end
      object EditQuietPeriod: TEdit
        Left = 214
        Top = 146
        Width = 80
        Height = 23
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        TabOrder = 3
        Text = '60'
      end
      object EditWatchedExts: TEdit
        Left = 170
        Top = 185
        Width = 437
        Height = 23
        Hint = 'Space or comma separated list, e.g.: .pas .dfm .dpr .dproj'
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
      end
      object GroupBoxPermissions: TGroupBox
        Left = 14
        Top = 250
        Width = 373
        Height = 129
        Caption = 'Remote file permissions'
        TabOrder = 4
        object CheckPermGroupRead: TCheckBox
          Left = 32
          Top = 60
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Group Read'
          TabOrder = 0
        end
        object CheckPermUserExec: TCheckBox
          Left = 262
          Top = 30
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'User Exec'
          TabOrder = 1
        end
        object CheckPermUserWrite: TCheckBox
          Left = 145
          Top = 30
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'User Write'
          TabOrder = 2
        end
        object CheckPermUserRead: TCheckBox
          Left = 32
          Top = 30
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'User Read'
          TabOrder = 3
        end
        object CheckPermGroupWrite: TCheckBox
          Left = 145
          Top = 60
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Group Write'
          TabOrder = 4
        end
        object CheckPermOtherExec: TCheckBox
          Left = 262
          Top = 90
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Other Exec'
          TabOrder = 5
        end
        object CheckPermOtherWrite: TCheckBox
          Left = 145
          Top = 90
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Other Write'
          TabOrder = 6
        end
        object CheckPermOtherRead: TCheckBox
          Left = 32
          Top = 90
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Other Read'
          TabOrder = 7
        end
        object CheckPermGroupExec: TCheckBox
          Left = 262
          Top = 60
          Width = 110
          Height = 20
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Group Exec'
          TabOrder = 8
        end
      end
    end
    object TabLog: TTabSheet
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Log'
      object MemoLog: TRichEdit
        Left = 0
        Top = 0
        Width = 642
        Height = 367
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alClient
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
        WordWrap = False
        StyleElements = [seClient, seBorder]
      end
      object PanelLogBtns: TPanel
        Left = 0
        Top = 367
        Width = 642
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        object BtnClearLog: TButton
          Left = 4
          Top = 2
          Width = 80
          Height = 24
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Clear Log'
          TabOrder = 0
          OnClick = BtnClearLogClick
        end
      end
    end
  end
end
