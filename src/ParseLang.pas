{===============================================================================
  ParseLang™ - Describe It. Parse It. Build It.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://parselang.org

  See LICENSE for license information
===============================================================================}

(*
  ParseLang — TParseLang Wrapper

  A two-phase compiler that reads a .parse language definition file and then
  uses the resulting configuration to compile source files written in that
  defined language.

  Usage:
    LPL := TParseLang.Create();
    LPL.SetLangFile('mylang.parse');
    LPL.SetSourceFile('hello.ml');
    LPL.SetOutputPath('output');
    LPL.SetTargetPlatform(tpWin64);
    LPL.SetBuildMode(bmExe);
    LPL.SetOptimizeLevel(olDebug);
    LPL.SetStatusCallback(...);
    LPL.Compile();
    LPL.Free();

  LIFETIME CONTRACT
  -----------------
  FBootstrapParse owns the .parse AST. Closures registered on FCustomParse
  capture references to nodes in that AST. Therefore FCustomParse MUST be
  freed before FBootstrapParse. This ordering is enforced in Destroy() and
  at the start of each Compile() call.

  Each call to Compile() creates fresh FBootstrapParse and FCustomParse
  instances, ensuring a clean slate for repeated compilations.
*)

unit ParseLang;

{$I ParseLang.Defines.inc}

interface

uses
  System.SysUtils,
  Parse,
  ParseLang.Common;

const
  PARSELANG_VERSION_MAJOR = 0;
  PARSELANG_VERSION_MINOR = 1;
  PARSELANG_VERSION_PATCH = 0;
  PARSELANG_VERSION_STR   = '0.1.0';

type

  { TParseLang }
  TParseLang = class(TParseOutputObject)
  private
    // FBootstrapParse: parses the .parse lang definition file.
    // Owns the AST that phase-2 closures reference — must outlive FCustomParse.
    FBootstrapParse: TParse;

    // FCustomParse: the configured custom language compiler.
    // Created fresh each Compile(); closures from ConfigCodeGen are wired here.
    FCustomParse: TParse;

    // Paths and settings accumulated between Compile() calls
    FLangFile:       string;
    FSourceFile:     string;
    FOutputPath:     string;
    FTargetPlatform: TParseTargetPlatform;
    FBuildMode:      TParseBuildMode;
    FOptimizeLevel:  TParseOptimizeLevel;
    FSubsystem:      TParseSubsystemType;
    FLineDirectives:  Boolean;
    FAddVersionInfo:  Boolean;
    FExeIcon:         string;
    FVIMajor:         Word;
    FVIMinor:         Word;
    FVIPatch:         Word;
    FVIProductName:   string;
    FVIDescription:   string;
    FVIFilename:      string;
    FVICompanyName:   string;
    FVICopyright:     string;

    // Tracks which phase produced the last set of errors:
    //   True  = bootstrap phase (.parse file errors)
    //   False = custom lang phase (source file errors)
    FLastErrorsFromBootstrap: Boolean;

    // Free both parse instances in the correct order (custom first, then bootstrap)
    procedure FreeParseInstances();

    // Forward accumulated settings to FCustomParse before running it
    procedure ForwardSettingsToCustom();

    // Apply icon and version info to the built executable/DLL
    procedure ApplyPostBuildResources(const AExePath: string);

    // Build the TParseLangPipelineCallbacks record pointing at FCustomParse
    function BuildPipelineCallbacks(): TParseLangPipelineCallbacks;

  public
    constructor Create(); override;
    destructor  Destroy(); override;

    // ---- Language definition ----

    // Path to the .parse language definition file.
    // Must be set before calling Compile().
    procedure SetLangFile(const AFilename: string);
    function  GetLangFile(): string;

    // ---- Source and output ----

    procedure SetSourceFile(const AFilename: string);
    function  GetSourceFile(): string;

    procedure SetOutputPath(const APath: string);
    function  GetOutputPath(): string;

    // ---- Build configuration ----

    procedure SetTargetPlatform(const APlatform: TParseTargetPlatform);
    procedure SetBuildMode(const ABuildMode: TParseBuildMode);
    procedure SetOptimizeLevel(const ALevel: TParseOptimizeLevel);
    procedure SetSubsystem(const ASubsystem: TParseSubsystemType);
    procedure SetLineDirectives(const AEnabled: Boolean);
    procedure SetAddVersionInfo(const AValue: Boolean);
    procedure SetExeIcon(const AValue: string);
    procedure SetVersionInfoMajor(const AValue: Word);
    procedure SetVersionInfoMinor(const AValue: Word);
    procedure SetVersionInfoPatch(const AValue: Word);
    procedure SetVersionInfoProductName(const AValue: string);
    procedure SetVersionInfoDescription(const AValue: string);
    procedure SetVersionInfoFilename(const AValue: string);
    procedure SetVersionInfoCompanyName(const AValue: string);
    procedure SetVersionInfoCopyright(const AValue: string);

    // ---- Callbacks — forwarded to both parse instances ----

    procedure SetStatusCallback(const ACallback: TParseStatusCallback;
      const AUserData: Pointer = nil); override;
    procedure SetOutputCallback(
      const ACallback: TParseCaptureConsoleCallback;
      const AUserData: Pointer = nil); override;

    // ---- Error access ----

    // Returns True if the last Compile() produced any errors.
    function HasErrors(): Boolean;

    // Returns the error collection from the last Compile() phase that ran.
    function GetErrors(): TParseErrors;

    // ---- Pipeline ----

    // Phase 1: parse FLangFile → configure FCustomParse.
    // Phase 2: compile FSourceFile with FCustomParse.
    // ABuild:   if True, invoke the Zig toolchain to produce a native binary.
    // AAutoRun: if True and ABuild succeeded, run the produced binary.
    // Returns True if both phases completed without errors.
    function Compile(const ABuild: Boolean = True;
      const AAutoRun: Boolean = False): Boolean;

    // Run the last successfully compiled binary.
    function Run(): Cardinal;

    // Exit code from the last Run() call.
    function GetLastExitCode(): Cardinal;

    // Version string
    function GetVersionStr(): string;
  end;

implementation

uses
  System.IOUtils,
  ParseLang.Lexer,
  ParseLang.Grammar,
  ParseLang.Semantics,
  ParseLang.CodeGen;

{ TParseLang }

constructor TParseLang.Create();
begin
  inherited Create();
  FBootstrapParse           := nil;
  FCustomParse              := nil;
  FLangFile                 := '';
  FSourceFile               := '';
  FOutputPath               := '';
  FTargetPlatform           := tpWin64;
  FBuildMode                := bmExe;
  FOptimizeLevel            := olDebug;
  FSubsystem                := stConsole;
  FLineDirectives           := False;
  FAddVersionInfo           := False;
  FExeIcon                  := '';
  FVIMajor                  := 0;
  FVIMinor                  := 0;
  FVIPatch                  := 0;
  FVIProductName            := '';
  FVIDescription            := '';
  FVIFilename               := '';
  FVICompanyName            := '';
  FVICopyright              := '';
  FLastErrorsFromBootstrap  := False;
end;

destructor TParseLang.Destroy();
begin
  // Free in correct order: custom first (holds closures referencing bootstrap AST),
  // then bootstrap (owns the AST).
  FreeParseInstances();
  inherited Destroy();
end;

procedure TParseLang.FreeParseInstances();
begin
  // FCustomParse must be freed before FBootstrapParse because its registered
  // closures hold references to AST nodes owned by FBootstrapParse.
  FreeAndNil(FCustomParse);
  FreeAndNil(FBootstrapParse);
end;

procedure TParseLang.ForwardSettingsToCustom();
begin
  if FCustomParse = nil then
    Exit;
  FCustomParse.SetSourceFile(FSourceFile);
  if FOutputPath <> '' then
    FCustomParse.SetOutputPath(FOutputPath);
  FCustomParse.SetTargetPlatform(FTargetPlatform);
  FCustomParse.SetBuildMode(FBuildMode);
  FCustomParse.SetOptimizeLevel(FOptimizeLevel);
  FCustomParse.SetSubsystem(FSubsystem);
  FCustomParse.SetLineDirectives(FLineDirectives);
  // Forward callbacks so status/output messages flow through to the caller
  FCustomParse.SetStatusCallback(
    FStatusCallback.Callback, FStatusCallback.UserData);
  FCustomParse.SetOutputCallback(
    FOutput.Callback, FOutput.UserData);
end;

function TParseLang.BuildPipelineCallbacks(): TParseLangPipelineCallbacks;
begin
  // Each callback captures FCustomParse by reference. At the time these
  // closures fire (Phase 2), FCustomParse is alive and fully wired.
  Result.OnSetPlatform :=
    procedure(AValue: string)
    begin
      if AValue = 'win64'        then FCustomParse.SetTargetPlatform(tpWin64)
      else if AValue = 'linux64' then FCustomParse.SetTargetPlatform(tpLinux64);
    end;

  Result.OnSetBuildMode :=
    procedure(AValue: string)
    begin
      if AValue = 'exe'     then FCustomParse.SetBuildMode(bmExe)
      else if AValue = 'lib'     then FCustomParse.SetBuildMode(bmLib)
      else if AValue = 'dll'     then FCustomParse.SetBuildMode(bmDll);
    end;

  Result.OnSetOptimize :=
    procedure(AValue: string)
    begin
      if AValue = 'debug'   then FCustomParse.SetOptimizeLevel(olDebug)
      else if AValue = 'release'  then FCustomParse.SetOptimizeLevel(olReleaseSafe)
      else if AValue = 'speed'    then FCustomParse.SetOptimizeLevel(olReleaseFast)
      else if AValue = 'size'     then FCustomParse.SetOptimizeLevel(olReleaseSmall);
    end;

  Result.OnSetSubsystem :=
    procedure(AValue: string)
    begin
      if AValue = 'console' then FCustomParse.SetSubsystem(stConsole)
      else if AValue = 'gui'      then FCustomParse.SetSubsystem(stGui);
    end;

  Result.OnSetOutputPath :=
    procedure(AValue: string)
    begin
      FCustomParse.SetOutputPath(AValue);
    end;

  Result.OnSetVIEnabled :=
    procedure(AValue: string)
    begin
      FAddVersionInfo := SameText(AValue, 'true');
    end;

  Result.OnSetVIExeIcon :=
    procedure(AValue: string)
    begin
      FExeIcon := AValue;
    end;

  Result.OnSetVIMajor :=
    procedure(AValue: string)
    begin
      FVIMajor := Word(StrToIntDef(AValue, 0));
    end;

  Result.OnSetVIMinor :=
    procedure(AValue: string)
    begin
      FVIMinor := Word(StrToIntDef(AValue, 0));
    end;

  Result.OnSetVIPatch :=
    procedure(AValue: string)
    begin
      FVIPatch := Word(StrToIntDef(AValue, 0));
    end;

  Result.OnSetVIProductName :=
    procedure(AValue: string)
    begin
      FVIProductName := AValue;
    end;

  Result.OnSetVIDescription :=
    procedure(AValue: string)
    begin
      FVIDescription := AValue;
    end;

  Result.OnSetVIFilename :=
    procedure(AValue: string)
    begin
      FVIFilename := AValue;
    end;

  Result.OnSetVICompanyName :=
    procedure(AValue: string)
    begin
      FVICompanyName := AValue;
    end;

  Result.OnSetVICopyright :=
    procedure(AValue: string)
    begin
      FVICopyright := AValue;
    end;

  Result.OnAddSourceFile :=
    procedure(AValue: string)
    begin
      FCustomParse.AddSourceFile(AValue);
    end;

  Result.OnAddIncludePath :=
    procedure(AValue: string)
    begin
      FCustomParse.AddIncludePath(AValue);
    end;

  Result.OnAddLibraryPath :=
    procedure(AValue: string)
    begin
      FCustomParse.AddLibraryPath(AValue);
    end;

  Result.OnAddLinkLibrary :=
    procedure(AValue: string)
    begin
      FCustomParse.AddLinkLibrary(AValue);
    end;

  Result.OnSetDefine :=
    procedure(AName: string; AValue: string)
    begin
      if AValue = '' then
        FCustomParse.SetDefine(AName)
      else
        FCustomParse.SetDefine(AName, AValue);
    end;

  Result.OnHasDefine :=
    function(AName: string): Boolean
    begin
      Result := FCustomParse.HasDefine(AName);
    end;

  Result.OnUnsetDefine :=
    procedure(AValue: string)
    begin
      FCustomParse.UnsetDefine(AValue);
    end;

  Result.OnHasUndefine :=
    function(AName: string): Boolean
    begin
      Result := FCustomParse.HasUndefine(AName);
    end;

  Result.OnAddCopyDLL :=
    procedure(AValue: string)
    begin
      FCustomParse.AddCopyDLL(AValue);
    end;
end;

// =========================================================================
// Public Setters
// =========================================================================

procedure TParseLang.SetLangFile(const AFilename: string);
begin
  FLangFile := AFilename;
end;

function TParseLang.GetLangFile(): string;
begin
  Result := FLangFile;
end;

procedure TParseLang.SetSourceFile(const AFilename: string);
begin
  FSourceFile := AFilename;
end;

function TParseLang.GetSourceFile(): string;
begin
  Result := FSourceFile;
end;

procedure TParseLang.SetOutputPath(const APath: string);
begin
  FOutputPath := APath;
end;

function TParseLang.GetOutputPath(): string;
begin
  Result := FOutputPath;
end;

procedure TParseLang.SetTargetPlatform(const APlatform: TParseTargetPlatform);
begin
  FTargetPlatform := APlatform;
end;

procedure TParseLang.SetBuildMode(const ABuildMode: TParseBuildMode);
begin
  FBuildMode := ABuildMode;
end;

procedure TParseLang.SetOptimizeLevel(const ALevel: TParseOptimizeLevel);
begin
  FOptimizeLevel := ALevel;
end;

procedure TParseLang.SetSubsystem(const ASubsystem: TParseSubsystemType);
begin
  FSubsystem := ASubsystem;
end;

procedure TParseLang.SetLineDirectives(const AEnabled: Boolean);
begin
  FLineDirectives := AEnabled;
end;

procedure TParseLang.SetAddVersionInfo(const AValue: Boolean);
begin
  FAddVersionInfo := AValue;
end;

procedure TParseLang.SetExeIcon(const AValue: string);
begin
  FExeIcon := AValue;
end;

procedure TParseLang.SetVersionInfoMajor(const AValue: Word);
begin
  FVIMajor := AValue;
end;

procedure TParseLang.SetVersionInfoMinor(const AValue: Word);
begin
  FVIMinor := AValue;
end;

procedure TParseLang.SetVersionInfoPatch(const AValue: Word);
begin
  FVIPatch := AValue;
end;

procedure TParseLang.SetVersionInfoProductName(const AValue: string);
begin
  FVIProductName := AValue;
end;

procedure TParseLang.SetVersionInfoDescription(const AValue: string);
begin
  FVIDescription := AValue;
end;

procedure TParseLang.SetVersionInfoFilename(const AValue: string);
begin
  FVIFilename := AValue;
end;

procedure TParseLang.SetVersionInfoCompanyName(const AValue: string);
begin
  FVICompanyName := AValue;
end;

procedure TParseLang.SetVersionInfoCopyright(const AValue: string);
begin
  FVICopyright := AValue;
end;

procedure TParseLang.SetStatusCallback(const ACallback: TParseStatusCallback;
  const AUserData: Pointer);
begin
  inherited SetStatusCallback(ACallback, AUserData);
  // Forward to live instances if they exist (e.g. callback set before Compile)
  if FBootstrapParse <> nil then
    FBootstrapParse.SetStatusCallback(ACallback, AUserData);
  if FCustomParse <> nil then
    FCustomParse.SetStatusCallback(ACallback, AUserData);
end;

procedure TParseLang.SetOutputCallback(
  const ACallback: TParseCaptureConsoleCallback; const AUserData: Pointer);
begin
  inherited SetOutputCallback(ACallback, AUserData);
  if FBootstrapParse <> nil then
    FBootstrapParse.SetOutputCallback(ACallback, AUserData);
  if FCustomParse <> nil then
    FCustomParse.SetOutputCallback(ACallback, AUserData);
end;

// =========================================================================
// Error Access
// =========================================================================

function TParseLang.HasErrors(): Boolean;
begin
  if FLastErrorsFromBootstrap then
  begin
    if FBootstrapParse <> nil then
      Result := FBootstrapParse.HasErrors()
    else
      Result := False;
  end
  else
  begin
    if FCustomParse <> nil then
      Result := FCustomParse.HasErrors()
    else
      Result := False;
  end;
end;

function TParseLang.GetErrors(): TParseErrors;
begin
  if FLastErrorsFromBootstrap then
  begin
    if FBootstrapParse <> nil then
      Result := FBootstrapParse.GetErrors()
    else
      Result := nil;
  end
  else
  begin
    if FCustomParse <> nil then
      Result := FCustomParse.GetErrors()
    else
      Result := nil;
  end;
end;

// =========================================================================
// Post-Build Resources
// =========================================================================

procedure TParseLang.ApplyPostBuildResources(const AExePath: string);
var
  LIsExe:    Boolean;
  LIsDll:    Boolean;
  LIconPath: string;
begin
  LIsExe := AExePath.EndsWith('.exe', True);
  LIsDll := AExePath.EndsWith('.dll', True);

  // Only applies to EXE and DLL files
  if not LIsExe and not LIsDll then
    Exit;

  // 1. Add manifest (EXE only)
  if LIsExe then
  begin
    if TParseUtils.ResourceExist('EXE_MANIFEST') then
    begin
      try
        Status('Applying manifest: %s', [TParseUtils.NormalizePath(TPath.GetFullPath(AExePath))]);
        if not TParseUtils.AddResManifestFromResource('EXE_MANIFEST', AExePath) then
          FCustomParse.GetErrors().Add(esWarning, 'W980',
            'Failed to add manifest to executable');
      except
        on E: Exception do
          FCustomParse.GetErrors().Add(esWarning, 'W980',
            Format('Failed to add manifest to executable: %s', [E.Message]));
      end;
    end;
  end;

  // 2. Add icon if specified (EXE only)
  if LIsExe and (FExeIcon <> '') then
  begin
    try
      LIconPath := FExeIcon;

      // Resolve relative paths against the directory of the running executable
      if not TPath.IsPathRooted(LIconPath) then
        LIconPath := TPath.GetFullPath(
          TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), LIconPath));

      if TFile.Exists(LIconPath) then
      begin
        try
          Status('Applying icon: %s', [TParseUtils.NormalizePath(LIconPath)]);
          TParseUtils.UpdateIconResource(AExePath, LIconPath);
        except
          on E: Exception do
            FCustomParse.GetErrors().Add(esWarning, 'W981',
              Format('Failed to add icon: %s', [E.Message]));
        end;
      end
      else
        FCustomParse.GetErrors().Add(esWarning, 'W982',
          Format('Icon file not found: %s', [LIconPath]));
    except
      on E: Exception do
        FCustomParse.GetErrors().Add(esWarning, 'W981',
          Format('Failed to add icon: %s', [E.Message]));
    end;
  end;

  // 3. Add version info if enabled (EXE and DLL)
  if FAddVersionInfo then
  begin
    try
      TParseUtils.UpdateVersionInfoResource(
        AExePath,
        FVIMajor,
        FVIMinor,
        FVIPatch,
        FVIProductName,
        FVIDescription,
        FVIFilename,
        FVICompanyName,
        FVICopyright);
      Status('Applying version info: %d.%d.%d — %s', [FVIMajor, FVIMinor, FVIPatch,
        TParseUtils.NormalizePath(AExePath)]);
    except
      on E: Exception do
        FCustomParse.GetErrors().Add(esWarning, 'W983',
          Format('Failed to add version info: %s', [E.Message]));
    end;
  end;
end;

// =========================================================================
// Compile
// =========================================================================

function TParseLang.Compile(const ABuild: Boolean;
  const AAutoRun: Boolean): Boolean;
var
  LPipeline: TParseLangPipelineCallbacks;
  LExePath:  string;
begin
  Result := False;

  // --- Pre-flight validation ---
  if FLangFile = '' then
    raise Exception.Create('TParseLang.Compile: LangFile not set');
  if not TFile.Exists(FLangFile) then
    raise Exception.CreateFmt(
      'TParseLang.Compile: LangFile not found: %s', [FLangFile]);
  if FSourceFile = '' then
    raise Exception.Create('TParseLang.Compile: SourceFile not set');

  // --- Free any previous instances (custom first, then bootstrap) ---
  FreeParseInstances();

  // =======================================================================
  // PHASE 1 — Parse the .parse language definition file
  // =======================================================================

  FBootstrapParse := TParse.Create();
  FCustomParse    := TParse.Create();

  // Forward callbacks to bootstrap so status messages reach the caller
  FBootstrapParse.SetStatusCallback(
    FStatusCallback.Callback, FStatusCallback.UserData);
  FBootstrapParse.SetOutputCallback(
    FOutput.Callback, FOutput.UserData);

  // Configure the bootstrap parser to understand the .parse meta-language
  ConfigLexer(FBootstrapParse);
  ConfigGrammar(FBootstrapParse);
  ConfigSemantics(FBootstrapParse);

  // Apply caller-supplied settings as defaults on FCustomParse BEFORE Phase 1
  // runs. The .parse file can override any of these via setPlatform() etc.
  ForwardSettingsToCustom();

  // Build pipeline callbacks that delegate into FCustomParse
  LPipeline := BuildPipelineCallbacks();

  // Register emitters: walking the .parse AST will call Config() on FCustomParse
  ConfigCodeGen(FBootstrapParse, FCustomParse, LPipeline);

  // Point bootstrap at the .parse file and compile (no Zig build, no run)
  FBootstrapParse.SetSourceFile(FLangFile);
  FBootstrapParse.SetOutputPath(FOutputPath);  // emit bootstrap artefacts alongside user output
  FBootstrapParse.Compile(False, False);

  // Check for bootstrap errors before proceeding to Phase 2
  FLastErrorsFromBootstrap := True;
  if FBootstrapParse.HasErrors() then
    Exit;

  // =======================================================================
  // PHASE 2 — Compile the user source file with the configured language
  // =======================================================================

  FLastErrorsFromBootstrap := False;

  // Compile the source file: lexer/grammar/semantic/codegen fire using the
  // handlers registered by ConfigCodeGen above.
  // Always pass AAutoRun=False — we apply post-build resources before running.
  Result := FCustomParse.Compile(ABuild, False);

  // Apply icon and version info AFTER build, BEFORE run
  if Result and ABuild then
  begin
    LExePath := TPath.Combine(FCustomParse.GetOutputPath(),
      'zig-out/bin/' + FCustomParse.GetOutputFilename());
    if LExePath <> '' then
      ApplyPostBuildResources(LExePath);
  end;

  // Run only if caller explicitly requested it
  if Result and AAutoRun then
    FCustomParse.Run();
end;

// =========================================================================
// Run / Exit Code
// =========================================================================

function TParseLang.Run(): Cardinal;
begin
  if FCustomParse <> nil then
    Result := FCustomParse.Run()
  else
    Result := High(Cardinal);
end;

function TParseLang.GetLastExitCode(): Cardinal;
begin
  if FCustomParse <> nil then
    Result := FCustomParse.GetLastExitCode()
  else
    Result := High(Cardinal);
end;

function TParseLang.GetVersionStr(): string;
begin
  Result := PARSELANG_VERSION_STR;
end;

end.
