unit CyAIAssistant.GPUMonitor;

// (c) 2026 Cypheros
// License: GPL 2.0
//
// GPUMonitor - GPU/VRAM utilization via D3DKMT
// Delphi 10+ , Windows 10 1709+
interface

uses
  Windows, SysUtils, Classes, Math;

type
  // -------------------------------------------------------------------------
  // Exception class
  // -------------------------------------------------------------------------
  EGPUMonitorError = class(Exception);
  // -------------------------------------------------------------------------
  // D3DKMT API types (internal)
  // -------------------------------------------------------------------------
  D3DKMT_HANDLE = UINT;

  _LUID = record
    LowPart: DWORD;
    HighPart: LONG;
  end;

  D3DKMT_ADAPTERINFO = record
    hAdapter: D3DKMT_HANDLE;
    AdapterLuid: _LUID;
    NumOfSources: ULONG;
    bPresentMoveRegionsPreferred: BOOL;
  end;

  PD3DKMT_ADAPTERINFO = ^D3DKMT_ADAPTERINFO;

  D3DKMT_ENUMADAPTERS2 = record
    NumAdapters: ULONG;
    pAdapters: PD3DKMT_ADAPTERINFO;
  end;

  D3DKMT_OPENADAPTERFROMLUID = record
    AdapterLuid: _LUID;
    hAdapter: D3DKMT_HANDLE;
  end;

  D3DKMT_CLOSEADAPTER = record
    hAdapter: D3DKMT_HANDLE;
  end;

  D3DKMT_QUERYADAPTERINFO = record
    hAdapter: D3DKMT_HANDLE;
    InfoType: UINT;
    pPrivateDriverData: Pointer;
    PrivateDriverDataSize: UINT;
  end;

  D3DKMT_SEGMENTSIZEINFO = record
    DedicatedVideoMemorySize: UInt64;
    DedicatedSystemMemorySize: UInt64;
    SharedSystemMemorySize: UInt64;
  end;

  D3DKMT_NODEMETADATA = record
    NodeOrdinalAndAdapterIndex: UINT;

    NodeData: record
      EngineType: UINT;
      FriendlyName: array [0 .. 31] of WideChar;
      Reserved: UINT;
      GpuMmuSupported: BOOLEAN;
      IoMmuSupported: BOOLEAN;
    end;
  end;

  D3DKMT_ADAPTER_PERFDATA = record
    PhysicalAdapterIndex: UINT;
    MemoryFrequency: UInt64;
    MaxMemoryFrequency: UInt64;
    MaxMemoryFrequencyOC: UInt64;
    MemoryBandwidth: UInt64;
    PCIEBandwidth: UInt64;
    FanRPM: ULONG;
    Power: ULONG;
    Temperature: ULONG;
    PowerStateOverride: Byte;
  end;

const
  KMTQAITYPE_GETSEGMENTSIZE = 3;
  KMTQAITYPE_ADAPTERTYPE = 15;
  KMTQAITYPE_NODEMETADATA = 25;
  KMTQAITYPE_ADAPTERPERFDATA = 62;

type
  // -------------------------------------------------------------------------
  // Public data types
  // -------------------------------------------------------------------------
  TGPUEngineInfo = record
    NodeIndex: Integer;
    EngineType: UINT;
    EngineTypeName: string;
    FriendlyName: string;
    UsagePercent: Double;
  end;

  TGPUInfo = record
    AdapterIndex: Integer;
    AdapterLuid: _LUID;
    Description: string;
    IsRenderSupported: BOOLEAN;
    IsDisplaySupported: BOOLEAN;
    IsSoftwareDevice: BOOLEAN;
    UsagePercent: Double;
    Engines: array of TGPUEngineInfo;
    DedicatedTotalMB: Int64;
    DedicatedUsedMB: Int64;
    SharedTotalMB: Int64;
    SharedUsedMB: Int64;
    TemperatureC: Integer;
    MemoryClockMHz: Int64;
    FanRPM: Integer;
    PowerWatt: Integer;
    LastError: string;
  end;

  // -------------------------------------------------------------------------
  // Initialization state
  // -------------------------------------------------------------------------
  TGPUMonitorState = (msOK, // Everything OK
    msNotInitialized, // Create has not been called yet
    msGdi32NotFound, // gdi32.dll could not be loaded
    msAPINotFound, // One or more D3DKMT functions missing (Windows too old)
    msNoAdapters, // No GPU adapters found
    msProbeSegmentFailed, // Could not query segment information
    msProbeInputFailed // Input offset could not be determined
    );

  // -------------------------------------------------------------------------
  // TGPUMonitor
  // -------------------------------------------------------------------------
  TGPUMonitor = class
  private type
    TNodeTiming = record
      LastRunningTime: Int64;
      LastQPC: Int64;
    end;

    TAdapterEntry = record
      Info: D3DKMT_ADAPTERINFO;
      Description: string;
      NodeCount: ULONG;
      SegmentCount: ULONG;
      AdapterTypeValue: UINT;
      SegmentSizes: D3DKMT_SEGMENTSIZEINFO;
      ApertureBits: array of BOOLEAN;
      NodeTimings: array of TNodeTiming;
      NodeEngineTypes: array of UINT;
      NodeFriendlyNames: array of string;
    end;
  private
    FAdapters: array of TAdapterEntry;
    FGPUs: array of TGPUInfo;
    FState: TGPUMonitorState;
    FInitError: string;
    FQPCFreq: Int64;
    FGdi32: THandle;
    FResultOffset: Integer;
    FInputOffset: Integer;
    FMissingFunctions: string;
    FD3DKMTEnumAdapters2: function(var A: D3DKMT_ENUMADAPTERS2): Integer; stdcall;
    FD3DKMTQueryAdapterInfo: function(var A: D3DKMT_QUERYADAPTERINFO): Integer; stdcall;
    FD3DKMTQueryStatistics: function(P: Pointer): Integer; stdcall;
    FD3DKMTOpenAdapterFromLuid: function(var A: D3DKMT_OPENADAPTERFROMLUID): Integer; stdcall;
    FD3DKMTCloseAdapter: function(var A: D3DKMT_CLOSEADAPTER): Integer; stdcall;
    function LoadAPI: BOOLEAN;
    function FindInputOffset(const Luid: _LUID; NbSegments: ULONG): Integer;
    function DoEnumerate: BOOLEAN;
    procedure InitAdapter(var Ad: TAdapterEntry);
    function ReadDescription(AdapterHandle: D3DKMT_HANDLE): string;
    procedure QS_Prepare(Buffer: PByte; QueryTyp: UINT; const Luid: _LUID);
    function AdapterOpen(const Luid: _LUID): D3DKMT_HANDLE;
    procedure AdClose(h: D3DKMT_HANDLE);
    function GetCount: Integer;
    function GetItem(Idx: Integer): TGPUInfo;
    function GetIsReady: BOOLEAN;
    procedure SetError(AState: TGPUMonitorState; const AMsg: string);
    function CheckWindowsVersion: BOOLEAN;
    function GetStateText: string;
  public
    /// Creates the GPU monitor.
    /// ARaiseOnError = True (default): raises EGPUMonitorError on problems.
    /// ARaiseOnError = False: no exception; check InitError / State instead.
    constructor Create(ARaiseOnError: BOOLEAN = True);
    destructor Destroy; override;
    /// Re-detect adapters (e.g. after GPU hotplug)
    procedure Refresh;
    /// Update all GPU data (call periodically, e.g. every 1000 ms via timer)
    procedure Update;
    /// Query a single GPU (calls Update internally)
    function QueryGPU(Index: Integer): TGPUInfo;
    /// True when ready and Update/QueryGPU will work
    property IsReady: BOOLEAN read GetIsReady;
    /// Current state
    property State: TGPUMonitorState read FState;
    /// Human-readable status text (e.g. for display in the UI)
    property StateText: string read GetStateText;
    /// Detailed error text (empty when OK)
    property InitError: string read FInitError;
    /// Number of detected GPUs (0 when not initialized)
    property GPUCount: Integer read GetCount;
    /// Access to last measurement results
    property GPUs[Index: Integer]: TGPUInfo read GetItem; default;
  end;

function EngineTypeName(ET: UINT): string;

implementation

const
  BUF_SIZE = 4096;
  // Minimum Windows version: Windows 10 1709 (Build 16299)
  MIN_BUILD = 16299;

function EngineTypeName(ET: UINT): string;
begin
  case ET of
    1:
      Result := '3D';
    2:
      Result := 'Video Decode';
    3:
      Result := 'Video Encode';
    4:
      Result := 'Video Processing';
    5:
      Result := 'Scene Assembly';
    6:
      Result := 'Copy';
    7:
      Result := 'Overlay';
    8:
      Result := 'Crypto';
  else
    Result := Format('Engine %d', [ET]);
  end;
end;

function ToMB(B: UInt64): Int64; inline;
begin
  Result := B div (1024 * 1024);
end;

// ---------------------------------------------------------------------------
// Windows version check
// ---------------------------------------------------------------------------
function TGPUMonitor.CheckWindowsVersion: BOOLEAN;
var
  Ver: TOSVersionInfo;
begin
  FillChar(Ver, SizeOf(Ver), 0);
  Ver.dwOSVersionInfoSize := SizeOf(Ver);
{$WARN SYMBOL_DEPRECATED OFF}
  GetVersionEx(Ver);
{$WARN SYMBOL_DEPRECATED ON}
  // Windows 10+ = MajorVersion >= 10
  // Build 16299+ = D3DKMTEnumAdapters2 available
  Result := (Ver.dwMajorVersion > 10) or ((Ver.dwMajorVersion = 10) and (Ver.dwBuildNumber >= MIN_BUILD));
end;

// ---------------------------------------------------------------------------
procedure TGPUMonitor.SetError(AState: TGPUMonitorState; const AMsg: string);
begin
  FState := AState;
  FInitError := AMsg;
end;

function TGPUMonitor.GetIsReady: BOOLEAN;
begin
  Result := FState = msOK;
end;

function TGPUMonitor.GetStateText: string;
begin
  case FState of
    msOK:
      Result := Format('Ready (%d GPU(s) detected)', [Length(FAdapters)]);
    msNotInitialized:
      Result := 'Not initialized';
    msGdi32NotFound:
      Result := 'gdi32.dll could not be loaded';
    msAPINotFound:
      Result := 'D3DKMT API not available (Windows too old?)';
    msNoAdapters:
      Result := 'No GPU adapters found';
    msProbeSegmentFailed:
      Result := 'Segment query failed';
    msProbeInputFailed:
      Result := 'Structure layout could not be determined';
  else
    Result := 'Unknown state';
  end;
end;

// ---------------------------------------------------------------------------
// Load API
// ---------------------------------------------------------------------------
function TGPUMonitor.LoadAPI: BOOLEAN;
  function Load(const FuncName: string): Pointer;
  begin
    Result := GetProcAddress(FGdi32, PChar(FuncName));
    if Result = nil then
    begin
      if FMissingFunctions <> '' then
        FMissingFunctions := FMissingFunctions + ', ';
      FMissingFunctions := FMissingFunctions + FuncName;
    end;
  end;

begin
  Result := False;
  FMissingFunctions := '';
  FGdi32 := LoadLibrary('gdi32.dll');
  if FGdi32 = 0 then
  begin
    SetError(msGdi32NotFound, 'gdi32.dll could not be loaded. ' + 'This DLL is a core component of Windows and should always be present. ' +
      'Possible cause: corrupted Windows installation.');
    Exit;
  end;
  @FD3DKMTEnumAdapters2 := Load('D3DKMTEnumAdapters2');
  @FD3DKMTQueryAdapterInfo := Load('D3DKMTQueryAdapterInfo');
  @FD3DKMTQueryStatistics := Load('D3DKMTQueryStatistics');
  @FD3DKMTOpenAdapterFromLuid := Load('D3DKMTOpenAdapterFromLuid');
  @FD3DKMTCloseAdapter := Load('D3DKMTCloseAdapter');
  if FMissingFunctions <> '' then
  begin
    SetError(msAPINotFound, Format('The following D3DKMT functions are missing from gdi32.dll: %s. ' +
      'These functions require Windows 10 version 1709 (Build %d) or newer. ' + 'Please update Windows.', [FMissingFunctions, MIN_BUILD]));
    Exit;
  end;
  Result := True;
end;

// ---------------------------------------------------------------------------
// Offset-Probing
// ---------------------------------------------------------------------------
function TGPUMonitor.FindInputOffset(const Luid: _LUID; NbSegments: ULONG): Integer;
var
  Buf: array [0 .. BUF_SIZE - 1] of Byte;
  HeaderEnd, Ofs: Integer;
begin
  Result := -1;
  if NbSegments = 0 then
    Exit;
{$IFDEF CPUX64}
  HeaderEnd := 24;
{$ELSE}
  HeaderEnd := 16;
{$ENDIF}
  Ofs := HeaderEnd;
  while Ofs < BUF_SIZE - 4 do
  begin
    FillChar(Buf, SizeOf(Buf), $FF);
    PUINT(@Buf[0])^ := 3; // SEGMENT
    Move(Luid, Buf[4], 8);
    FillChar(Buf[12], HeaderEnd - 12, 0);
    PULONG(@Buf[Ofs])^ := 0;
    if FD3DKMTQueryStatistics(@Buf[0]) = 0 then
    begin
      FillChar(Buf, SizeOf(Buf), $FF);
      PUINT(@Buf[0])^ := 3;
      Move(Luid, Buf[4], 8);
      FillChar(Buf[12], HeaderEnd - 12, 0);
      PULONG(@Buf[Ofs])^ := NbSegments + 1000;
      if FD3DKMTQueryStatistics(@Buf[0]) <> 0 then
      begin
        Result := Ofs;
        Exit;
      end;
    end;
    Inc(Ofs, 4);
  end;
end;

// ---------------------------------------------------------------------------
procedure TGPUMonitor.QS_Prepare(Buffer: PByte; QueryTyp: UINT; const Luid: _LUID);
begin
  FillChar(Buffer^, BUF_SIZE, 0);
  PUINT(@Buffer[0])^ := QueryTyp;
  Move(Luid, Buffer[4], 8);
end;

function TGPUMonitor.AdapterOpen(const Luid: _LUID): D3DKMT_HANDLE;
var
  A: D3DKMT_OPENADAPTERFROMLUID;
begin
  FillChar(A, SizeOf(A), 0);
  A.AdapterLuid := Luid;
  if FD3DKMTOpenAdapterFromLuid(A) = 0 then
    Result := A.hAdapter
  else
    Result := 0;
end;

procedure TGPUMonitor.AdClose(h: D3DKMT_HANDLE);
var
  A: D3DKMT_CLOSEADAPTER;
begin
  if h <> 0 then
  begin
    A.hAdapter := h;
    FD3DKMTCloseAdapter(A);
  end;
end;

// ---------------------------------------------------------------------------
// Enumeration
// ---------------------------------------------------------------------------
function TGPUMonitor.DoEnumerate: BOOLEAN;
var
  EnumAdapters: D3DKMT_ENUMADAPTERS2;
  AdapterArray: array of D3DKMT_ADAPTERINFO;
  Buffer: array [0 .. BUF_SIZE - 1] of Byte;
  i: Integer;
  NumberOfSegments: ULONG;
begin
  Result := False;
  FillChar(EnumAdapters, SizeOf(EnumAdapters), 0);
  FD3DKMTEnumAdapters2(EnumAdapters);
  if EnumAdapters.NumAdapters = 0 then
  begin
    SetError(msNoAdapters, 'D3DKMTEnumAdapters2 returned no GPU adapters. ' + 'Possible causes: no graphics driver installed, ' +
      'GPU disabled, or remote desktop session without GPU access.');
    Exit;
  end;
  SetLength(AdapterArray, EnumAdapters.NumAdapters);
  EnumAdapters.pAdapters := @AdapterArray[0];
  if FD3DKMTEnumAdapters2(EnumAdapters) <> 0 then
  begin
    SetError(msNoAdapters, 'D3DKMTEnumAdapters2 failed on second call.');
    Exit;
  end;
  // Calculate ResultOffset
{$IFDEF CPUX64}
  FResultOffset := 24;
{$ELSE}
  FResultOffset := 16;
{$ENDIF}
  // NbSegments for probing
  NumberOfSegments := 0;
  FillChar(Buffer, SizeOf(Buffer), 0);
  PUINT(@Buffer[0])^ := 0; // ADAPTER
  Move(AdapterArray[0].AdapterLuid, Buffer[4], 8);
  if FD3DKMTQueryStatistics(@Buffer[0]) = 0 then
    NumberOfSegments := PULONG(@Buffer[FResultOffset])^;
  if NumberOfSegments = 0 then
  begin
    SetError(msProbeSegmentFailed, 'D3DKMTQueryStatistics(ADAPTER) returned 0 segments. ' + 'The graphics driver reports no memory segments. ' +
      'Please update your graphics driver.');
    Exit;
  end;
  // Find input offset
  FInputOffset := FindInputOffset(AdapterArray[0].AdapterLuid, NumberOfSegments);
  if FInputOffset < 0 then
  begin
    SetError(msProbeInputFailed, 'The memory layout of the D3DKMT_QUERYSTATISTICS structure could not ' +
      'be determined. This may indicate an unsupported Windows version. ' + Format('(Tested: %d positions, NbSegments=%d, ResultOffset=%d)',
      [BUF_SIZE div 4, NumberOfSegments, FResultOffset]));
    Exit;
  end;
  SetLength(FAdapters, EnumAdapters.NumAdapters);
  for i := 0 to EnumAdapters.NumAdapters - 1 do
  begin
    FillChar(FAdapters[i], SizeOf(TAdapterEntry), 0);
    FAdapters[i].Info := AdapterArray[i];
    InitAdapter(FAdapters[i]);
  end;
  SetLength(FGPUs, Length(FAdapters));
  SetError(msOK, '');
  Result := True;
end;

// ---------------------------------------------------------------------------
procedure TGPUMonitor.InitAdapter(var Ad: TAdapterEntry);
var
  StatsBuffer: array [0 .. BUF_SIZE - 1] of Byte;
  AdapterHandle: D3DKMT_HANDLE;
  QueryAdapterInfo: D3DKMT_QUERYADAPTERINFO;
  AdapterTypeRec: record
    Value: UINT;
  end;
  SegmentSizeInfo: D3DKMT_SEGMENTSIZEINFO;
  NodeMetadata: D3DKMT_NODEMETADATA;
  Idx: Integer;
  CurrentQPC: Int64;
  FriendlyName: string;
const
  STATS_TYPE_ADAPTER = 0;
  STATS_TYPE_SEGMENT = 3;
  STATS_TYPE_NODE = 5;
  OFFSET_APERTURE = 40;
begin
  QS_Prepare(@StatsBuffer[0], STATS_TYPE_ADAPTER, Ad.Info.AdapterLuid);
  if FD3DKMTQueryStatistics(@StatsBuffer[0]) = 0 then
  begin
    Ad.SegmentCount := PULONG(@StatsBuffer[FResultOffset])^;
    Ad.NodeCount := PULONG(@StatsBuffer[FResultOffset + 4])^;
  end;

  AdapterHandle := AdapterOpen(Ad.Info.AdapterLuid);
  if AdapterHandle = 0 then
    Exit;

  try
    FillChar(AdapterTypeRec, SizeOf(AdapterTypeRec), 0);
    FillChar(QueryAdapterInfo, SizeOf(QueryAdapterInfo), 0);
    QueryAdapterInfo.hAdapter := AdapterHandle;
    QueryAdapterInfo.InfoType := KMTQAITYPE_ADAPTERTYPE;
    QueryAdapterInfo.pPrivateDriverData := @AdapterTypeRec;
    QueryAdapterInfo.PrivateDriverDataSize := SizeOf(AdapterTypeRec);
    if FD3DKMTQueryAdapterInfo(QueryAdapterInfo) = 0 then
      Ad.AdapterTypeValue := AdapterTypeRec.Value;

    FillChar(SegmentSizeInfo, SizeOf(SegmentSizeInfo), 0);
    FillChar(QueryAdapterInfo, SizeOf(QueryAdapterInfo), 0);
    QueryAdapterInfo.hAdapter := AdapterHandle;
    QueryAdapterInfo.InfoType := KMTQAITYPE_GETSEGMENTSIZE;
    QueryAdapterInfo.pPrivateDriverData := @SegmentSizeInfo;
    QueryAdapterInfo.PrivateDriverDataSize := SizeOf(SegmentSizeInfo);
    if FD3DKMTQueryAdapterInfo(QueryAdapterInfo) = 0 then
      Ad.SegmentSizes := SegmentSizeInfo;

    Ad.Description := ReadDescription(AdapterHandle);

    SetLength(Ad.ApertureBits, Ad.SegmentCount);
    for Idx := 0 to Integer(Ad.SegmentCount) - 1 do
    begin
      QS_Prepare(@StatsBuffer[0], STATS_TYPE_SEGMENT, Ad.Info.AdapterLuid);
      PULONG(@StatsBuffer[FInputOffset])^ := ULONG(Idx);
      if FD3DKMTQueryStatistics(@StatsBuffer[0]) = 0 then
        Ad.ApertureBits[Idx] := (PULONG(@StatsBuffer[FResultOffset + OFFSET_APERTURE])^ <> 0)
      else
        Ad.ApertureBits[Idx] := False;
    end;

    QueryPerformanceCounter(CurrentQPC);
    SetLength(Ad.NodeTimings, Ad.NodeCount);
    SetLength(Ad.NodeEngineTypes, Ad.NodeCount);
    SetLength(Ad.NodeFriendlyNames, Ad.NodeCount);

    for Idx := 0 to Integer(Ad.NodeCount) - 1 do
    begin
      FillChar(NodeMetadata, SizeOf(NodeMetadata), 0);
      FillChar(QueryAdapterInfo, SizeOf(QueryAdapterInfo), 0);
      QueryAdapterInfo.hAdapter := AdapterHandle;
      QueryAdapterInfo.InfoType := KMTQAITYPE_NODEMETADATA;
      QueryAdapterInfo.pPrivateDriverData := @NodeMetadata;
      QueryAdapterInfo.PrivateDriverDataSize := SizeOf(NodeMetadata);

      if FD3DKMTQueryAdapterInfo(QueryAdapterInfo) = 0 then
      begin
        Ad.NodeEngineTypes[Idx] := NodeMetadata.NodeData.EngineType;
        FriendlyName := Trim(WideCharToString(@NodeMetadata.NodeData.FriendlyName[0]));
        if FriendlyName = '' then
          FriendlyName := EngineTypeName(NodeMetadata.NodeData.EngineType);
        Ad.NodeFriendlyNames[Idx] := FriendlyName;
      end
      else
      begin
        Ad.NodeEngineTypes[Idx] := 0;
        Ad.NodeFriendlyNames[Idx] := Format('Node %d', [Idx]);
      end;

      Ad.NodeTimings[Idx].LastQPC := CurrentQPC;
      Ad.NodeTimings[Idx].LastRunningTime := 0;

      QS_Prepare(@StatsBuffer[0], STATS_TYPE_NODE, Ad.Info.AdapterLuid);
      PULONG(@StatsBuffer[FInputOffset])^ := ULONG(Idx);
      if FD3DKMTQueryStatistics(@StatsBuffer[0]) = 0 then
        Ad.NodeTimings[Idx].LastRunningTime := PInt64(@StatsBuffer[FResultOffset])^;
    end;
  finally
    AdClose(AdapterHandle);
  end;
end;

// ---------------------------------------------------------------------------
function TGPUMonitor.ReadDescription(AdapterHandle: D3DKMT_HANDLE): string;
const
  BUFFER_SIZE = 4096;
  KMTQAITYPE_DRIVERPRIVATE = 48;
  PROPERTY_NAME = 'HardwareInformation.AdapterString';
  OFFS_NAME = 8;
  OFFS_VERSION = 528;
  OFFS_SIZE = 536;
  OFFS_STATUS = 540;
  OFFS_DATA = 544;
var
  QueryInfo: D3DKMT_QUERYADAPTERINFO;
  Buffer: array [0 .. BUFFER_SIZE - 1] of Byte;
  NameLen: Integer;
begin
  Result := 'GPU';
  FillChar(Buffer, SizeOf(Buffer), 0);

  NameLen := Length(PROPERTY_NAME);
  if NameLen > 0 then
    Move(PROPERTY_NAME[1], Buffer[OFFS_NAME], NameLen * SizeOf(WideChar));

  PULONG(@Buffer[OFFS_VERSION])^ := 1;
  PULONG(@Buffer[OFFS_SIZE])^ := BUFFER_SIZE - OFFS_DATA;

  FillChar(QueryInfo, SizeOf(QueryInfo), 0);
  QueryInfo.hAdapter := AdapterHandle;
  QueryInfo.InfoType := KMTQAITYPE_DRIVERPRIVATE;
  QueryInfo.pPrivateDriverData := @Buffer[0];
  QueryInfo.PrivateDriverDataSize := BUFFER_SIZE;

  if FD3DKMTQueryAdapterInfo(QueryInfo) = 0 then
    if PULONG(@Buffer[OFFS_STATUS])^ = 0 then
      if PWideChar(@Buffer[OFFS_DATA])^ <> #0 then
        Result := WideCharToString(PWideChar(@Buffer[OFFS_DATA]));
end;

// ---------------------------------------------------------------------------
// Constructor / Destructor
// ---------------------------------------------------------------------------
constructor TGPUMonitor.Create(ARaiseOnError: BOOLEAN);
begin
  inherited Create;
  FGdi32 := 0;
  FState := msNotInitialized;
  FInitError := '';
  FResultOffset := 24;
  FInputOffset := -1;
  QueryPerformanceFrequency(FQPCFreq);
  // Step 1: Check Windows version
  if not CheckWindowsVersion then
  begin
    SetError(msAPINotFound, Format('GPU monitoring requires Windows 10 version 1709 (Build %d) or newer. ' +
      'Your Windows version is older and does not support the required ' + 'D3DKMT functions.', [MIN_BUILD]));
    if ARaiseOnError then
      raise EGPUMonitorError.Create(FInitError);
    Exit;
  end;
  // Step 2: Load API
  if not LoadAPI then
  begin
    if ARaiseOnError then
      raise EGPUMonitorError.Create(FInitError);
    Exit;
  end;
  // Step 3: Enumerate adapters and probe offsets
  if not DoEnumerate then
  begin
    if ARaiseOnError then
      raise EGPUMonitorError.Create(FInitError);
    Exit;
  end;
  // Step 4: Initial baseline measurement
  Update;
end;

destructor TGPUMonitor.Destroy;
begin
  if FGdi32 <> 0 then
    FreeLibrary(FGdi32);
  inherited;
end;

// ---------------------------------------------------------------------------
// Update
// ---------------------------------------------------------------------------
procedure TGPUMonitor.Update;
var
  I, J: Integer;
  NowQPC, QPCDiff: Int64;
  RunTime, DeltaGPU, ElapsedHNS: Int64;
  MaxUsage, NodeUsage: Double;
  Buf: array [0 .. BUF_SIZE - 1] of Byte;
  DedUsed, ShrUsed, BytesC: UInt64;
  AdapterHandle: D3DKMT_HANDLE;
  PerfData: D3DKMT_ADAPTER_PERFDATA;
  QueryAadapterInfo: D3DKMT_QUERYADAPTERINFO;
  AdapterLuid: _LUID;
  NodeCount, SegmentCount: Integer;
const
  HNS_PER_SEC = Int64(10000000);
  PERCENT_MULTIPLIER = 100.0;
  TEMP_DIVISOR = 10;
  CLOCK_DIVISOR = 1000000;
  POWER_DIVISOR = 1000;
begin
  if not IsReady then
    Exit;
  QueryPerformanceCounter(NowQPC);

  for I := 0 to High(FAdapters) do
  begin
    AdapterLuid := FAdapters[I].Info.AdapterLuid;
    NodeCount := Integer(FAdapters[I].NodeCount);
    SegmentCount := Integer(FAdapters[I].SegmentCount);

    // Initialize GPU Info
    FGPUs[I] := Default (TGPUInfo);
    FGPUs[I].AdapterIndex := I;
    FGPUs[I].AdapterLuid := AdapterLuid;
    FGPUs[I].Description := FAdapters[I].Description;
    FGPUs[I].IsRenderSupported := (FAdapters[I].AdapterTypeValue and 1) <> 0;
    FGPUs[I].IsDisplaySupported := (FAdapters[I].AdapterTypeValue and 2) <> 0;
    FGPUs[I].IsSoftwareDevice := (FAdapters[I].AdapterTypeValue and 4) <> 0;

    // ---- Usage Calculation ----
    MaxUsage := 0;
    SetLength(FGPUs[I].Engines, NodeCount);

    for J := 0 to NodeCount - 1 do
    begin
      FGPUs[I].Engines[J].NodeIndex := J;
      FGPUs[I].Engines[J].EngineType := FAdapters[I].NodeEngineTypes[J];
      FGPUs[I].Engines[J].EngineTypeName := EngineTypeName(FAdapters[I].NodeEngineTypes[J]);
      FGPUs[I].Engines[J].FriendlyName := FAdapters[I].NodeFriendlyNames[J];

      QS_Prepare(@Buf[0], 5, AdapterLuid);
      PULONG(@Buf[FInputOffset])^ := ULONG(J);

      if FD3DKMTQueryStatistics(@Buf[0]) = 0 then
      begin
        RunTime := PInt64(@Buf[FResultOffset])^;
        QPCDiff := NowQPC - FAdapters[I].NodeTimings[J].LastQPC;

        if QPCDiff > 0 then
        begin
          DeltaGPU := RunTime - FAdapters[I].NodeTimings[J].LastRunningTime;
          ElapsedHNS := (QPCDiff * HNS_PER_SEC) div FQPCFreq;

          if ElapsedHNS > 0 then
          begin
            NodeUsage := (DeltaGPU / ElapsedHNS) * PERCENT_MULTIPLIER;
            NodeUsage := Max(0.0, Min(100.0, NodeUsage));

            FGPUs[I].Engines[J].UsagePercent := NodeUsage;
            if NodeUsage > MaxUsage then
              MaxUsage := NodeUsage;
          end;
        end;

        FAdapters[I].NodeTimings[J].LastRunningTime := RunTime;
        FAdapters[I].NodeTimings[J].LastQPC := NowQPC;
      end;
    end;
    FGPUs[I].UsagePercent := MaxUsage;

    // ---- Memory Calculation ----
    DedUsed := 0;
    ShrUsed := 0;

    for J := 0 to SegmentCount - 1 do
    begin
      QS_Prepare(@Buf[0], 3, AdapterLuid);
      PULONG(@Buf[FInputOffset])^ := ULONG(J);

      if FD3DKMTQueryStatistics(@Buf[0]) = 0 then
      begin
        BytesC := PUInt64(@Buf[FResultOffset + 8])^;

        if (J < Length(FAdapters[I].ApertureBits)) and FAdapters[I].ApertureBits[J] then
          Inc(ShrUsed, BytesC)
        else
          Inc(DedUsed, BytesC);
      end;
    end;

    FGPUs[I].DedicatedTotalMB := ToMB(FAdapters[I].SegmentSizes.DedicatedVideoMemorySize);
    FGPUs[I].DedicatedUsedMB := ToMB(DedUsed);
    FGPUs[I].SharedTotalMB := ToMB(FAdapters[I].SegmentSizes.SharedSystemMemorySize);
    FGPUs[I].SharedUsedMB := ToMB(ShrUsed);

    // ---- Performance Data ----
    AdapterHandle := AdapterOpen(AdapterLuid);
    if AdapterHandle <> 0 then
    begin
      try
        FillChar(PerfData, SizeOf(PerfData), 0);
        FillChar(QueryAadapterInfo, SizeOf(QueryAadapterInfo), 0);

        QueryAadapterInfo.hAdapter := AdapterHandle;
        QueryAadapterInfo.InfoType := KMTQAITYPE_ADAPTERPERFDATA;
        QueryAadapterInfo.pPrivateDriverData := @PerfData;
        QueryAadapterInfo.PrivateDriverDataSize := SizeOf(PerfData);

        if FD3DKMTQueryAdapterInfo(QueryAadapterInfo) = 0 then
        begin
          if PerfData.Temperature > 0 then
            FGPUs[I].TemperatureC := PerfData.Temperature div TEMP_DIVISOR;

          FGPUs[I].MemoryClockMHz := PerfData.MemoryFrequency div CLOCK_DIVISOR;
          FGPUs[I].FanRPM := PerfData.FanRPM;

          if PerfData.Power > 0 then
            FGPUs[I].PowerWatt := PerfData.Power div POWER_DIVISOR;
        end;
      finally
        AdClose(AdapterHandle);
      end;
    end;
  end;
end;

// ---------------------------------------------------------------------------
procedure TGPUMonitor.Refresh;
begin
  SetLength(FAdapters, 0);
  SetLength(FGPUs, 0);
  if FState in [msOK, msNoAdapters, msProbeSegmentFailed, msProbeInputFailed] then
    DoEnumerate;
  if IsReady then
    Update;
end;

function TGPUMonitor.QueryGPU(Index: Integer): TGPUInfo;
begin
  if not IsReady then
  begin
    Result := Default (TGPUInfo);
    Result.LastError := 'GPU monitor not ready: ' + FInitError;
    Exit;
  end;
  Update;
  Result := GetItem(Index);
end;

function TGPUMonitor.GetCount: Integer;
begin
  Result := Length(FAdapters);
end;

function TGPUMonitor.GetItem(Idx: Integer): TGPUInfo;
begin
  if (Idx >= 0) and (Idx < Length(FGPUs)) then
    Result := FGPUs[Idx]
  else
  begin
    Result := Default (TGPUInfo);
    if not IsReady then
      Result.LastError := 'GPU monitor not ready: ' + FInitError
    else
      Result.LastError := Format('GPU index %d out of range (0..%d)', [Idx, High(FGPUs)]);
  end;
end;

end.
