{===============================================================================
  ParseLang™ - Describe It. Parse It. Build It.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://parselang.org

  See LICENSE for license information
===============================================================================}

unit UPLC;

interface

procedure RunCLI();

implementation

uses
  System.SysUtils,
  Parse,
  ParseLang;

type
  { TPLC }
  TPLC = class
  private
    FParseLang:  TParseLang;
    FLangFile:   string;
    FSourceFile: string;
    FOutputPath: string;
    FBuild:      Boolean;
    FAutoRun:    Boolean;
    procedure Print(const AText: string);
    procedure ShowHelp();
    procedure ShowBanner();
    procedure ShowErrors();
    procedure SetupCallbacks();
    function  ParseArgs(): Boolean;
    procedure RunCompile();
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Execute();
  end;

{ TPLC }

constructor TPLC.Create();
begin
  inherited Create();
  FParseLang  := nil;
  FLangFile   := '';
  FSourceFile := '';
  FOutputPath := 'output';
  FBuild      := True;
  FAutoRun    := False;

  FParseLang := TParseLang.Create();
end;

destructor TPLC.Destroy();
begin
  FreeAndNil(FParseLang);
  inherited Destroy();
end;

procedure TPLC.Print(const AText: string);
begin
  TParseUtils.PrintLn(AText);
end;

procedure TPLC.ShowHelp();
begin
  Print(COLOR_WHITE + 'Syntax: PLC [options] -l <file> -s <file> [options]');
  Print('');

  Print(COLOR_BOLD + 'USAGE:');
  Print('  PLC ' + COLOR_CYAN + '-l <file> -s <file>' + ' [OPTIONS]');
  Print('');
  Print(COLOR_BOLD + 'REQUIRED:');
  Print('  ' + COLOR_CYAN + '-l, --lang    <file>' + '   Language definition file (.parse)');
  Print('  ' + COLOR_CYAN + '-s, --source  <file>' + '   Source file to compile');
  Print('');
  Print(COLOR_BOLD + 'OPTIONS:');
  Print('  ' + COLOR_CYAN + '-o, --output  <path>' + '   Output path (default: output)');
  Print('  ' + COLOR_CYAN + '-nb, --no-build     ' + '   Generate sources only, skip binary build');
  Print('  ' + COLOR_CYAN + '-r, --autorun       ' + '   Build and run the compiled binary');
  Print('  ' + COLOR_CYAN + '-h, --help          ' + '   Display this help message');
  Print('');
  Print(COLOR_BOLD + 'EXAMPLES:');
  Print('  ' + COLOR_CYAN + 'PLC -l mylang.parse -s hello.src');
  Print('  ' + COLOR_CYAN + 'PLC -l mylang.parse -s hello.src -o build');
  Print('  ' + COLOR_CYAN + 'PLC -l mylang.parse -s hello.src -r');
  Print('');
end;

procedure TPLC.ShowBanner();
begin
  Print(COLOR_WHITE + COLOR_BOLD + 'ParseLang™ Compiler for Win64 version ' + FParseLang.GetVersionStr());
  Print(COLOR_WHITE + 'Copyright © 2025-present tinyBigGAMES™ LLC. All Rights Reserved.');
  Print('');
end;

procedure TPLC.ShowErrors();
var
  LErrors: TParseErrors;
  LError:  TParseError;
  LColor:  string;
  LI:      Integer;
begin
  if not FParseLang.HasErrors() then
    Exit;

  LErrors := FParseLang.GetErrors();

  Print('');
  Print(COLOR_WHITE + Format('Errors (%d):', [LErrors.Count()]));

  for LI := 0 to LErrors.GetItems().Count - 1 do
  begin
    LError := LErrors.GetItems()[LI];

    case LError.Severity of
      esHint:    LColor := COLOR_CYAN;
      esWarning: LColor := COLOR_YELLOW;
      esError:   LColor := COLOR_RED;
      esFatal:   LColor := COLOR_BOLD + COLOR_RED;
    else
      LColor := COLOR_WHITE;
    end;

    Print(LColor + '  ' + LError.ToFullString());
  end;
end;

procedure TPLC.SetupCallbacks();
begin
  // Print compiler status messages
  FParseLang.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TParseUtils.PrintLn(AText);
    end);

  // Print program output (no newline — output drives its own line endings)
  FParseLang.SetOutputCallback(
    procedure(const ALine: string; const AUserData: Pointer)
    begin
      TParseUtils.Print(ALine);
    end);
end;

function TPLC.ParseArgs(): Boolean;
var
  LI:    Integer;
  LFlag: string;
begin
  Result := True;

  if ParamCount = 0 then
  begin
    ShowHelp();
    Result := False;
    Exit;
  end;

  LI := 1;
  while LI <= ParamCount do
  begin
    LFlag := ParamStr(LI).Trim();

    if (LFlag = '-h') or (LFlag = '--help') then
    begin
      ShowHelp();
      Result := False;
      Exit;
    end
    else if (LFlag = '-l') or (LFlag = '--lang') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a file argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FLangFile := ParamStr(LI).Trim();
    end
    else if (LFlag = '-s') or (LFlag = '--source') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a file argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FSourceFile := ParamStr(LI).Trim();
    end
    else if (LFlag = '-o') or (LFlag = '--output') then
    begin
      Inc(LI);
      if LI > ParamCount then
      begin
        Print(COLOR_RED + 'Error: ' + LFlag + ' requires a path argument');
        Print('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FOutputPath := ParamStr(LI).Trim();
    end
    else if (LFlag = '-nb') or (LFlag = '--no-build') then
    begin
      FBuild := False;
    end
    else if (LFlag = '-r') or (LFlag = '--autorun') then
    begin
      FAutoRun := True;
    end
    else
    begin
      Print(COLOR_RED + 'Error: Unknown flag: ' + COLOR_YELLOW + LFlag);
      Print('');
      Print('Run ' + COLOR_CYAN + 'PLC -h' + ' to see available options');
      Print('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    Inc(LI);
  end;

  // Validate required arguments
  if FLangFile = '' then
  begin
    Print(COLOR_RED + 'Error: Language file is required (-l <file>)');
    Print('');
    Print('Run ' + COLOR_CYAN + 'PLC -h' + ' to see available options');
    Print('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;

  if FSourceFile = '' then
  begin
    Print(COLOR_RED + 'Error: Source file is required (-s <file>)');
    Print('');
    Print('Run ' + COLOR_CYAN + 'PLC -h' + ' to see available options');
    Print('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;
end;

procedure TPLC.RunCompile();
var
  LSuccess: Boolean;
begin
  // Configure the compiler
  FParseLang.SetLangFile(FLangFile);
  FParseLang.SetSourceFile(FSourceFile);
  FParseLang.SetOutputPath(FOutputPath);
  FParseLang.SetLineDirectives(True);

  SetupCallbacks();

  Print('');

  LSuccess := FParseLang.Compile(FBuild, False);

  // Always display all errors/warnings/hints regardless of outcome
  ShowErrors();

  if LSuccess then
    begin
      if FBuild then
        Print(COLOR_GREEN + 'Build OK')
      else
        Print(COLOR_GREEN + 'Compile OK');
    end
  else
    begin
      Print(COLOR_RED + 'Build failed.');
      ExitCode := 1;
    end;

  if FAutoRun then
  begin
    ExitCode := FParseLang.Run;
  end;
end;

procedure TPLC.Execute();
begin
  ShowBanner();

  if not ParseArgs() then
    Exit;

  RunCompile();
end;

{ RunCLI }

procedure RunCLI();
var
  LPLC: TPLC;
begin
  ExitCode := 0;
  LPLC := nil;

  try
    LPLC := TPLC.Create();
    try
      LPLC.Execute();
    finally
      FreeAndNil(LPLC);
    end;
  except
    on E: Exception do
    begin
      TParseUtils.PrintLn('');
      TParseUtils.PrintLn(COLOR_RED + COLOR_BOLD + 'Fatal Error: ' + E.Message);
      TParseUtils.PrintLn('');
      ExitCode := 1;
    end;
  end;
end;

end.
