{===============================================================================
  ParseLang™ - Describe It. Parse It. Build It.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://parselang.org

  See LICENSE for license information
===============================================================================}

unit UTestbed;

interface

procedure RunTestbed();

implementation

uses
  System.SysUtils,
  Parse,
  ParseLang;

procedure ShowErrors(const AParseLang: TParseLang);
var
  LErrors: TParseErrors;
  LError:  TParseError;
  LColor:  string;
  LI:      Integer;
begin
  if not AParseLang.HasErrors() then
    Exit;

  LErrors := AParseLang.GetErrors();
  if LErrors = nil then
    Exit;

  TParseUtils.PrintLn('');
  TParseUtils.PrintLn(COLOR_WHITE + Format('Errors (%d):', [LErrors.Count()]));
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
    TParseUtils.PrintLn(LColor + LError.ToFullString());
  end;
end;

procedure Test01();
var
  LParseLang: TParseLang;
begin
  LParseLang := TParseLang.Create();
  try
    LParseLang.SetLangFile('tests\mylang.parse');
    LParseLang.SetSourceFile('tests\hello.ml');
    LParseLang.SetOutputPath('output');
    LParseLang.SetLineDirectives(True);

    (*
    LParseLang.SetAddVersionInfo(True);
    LParseLang.SetExeIcon('');
    LParseLang.SetVersionInfoMajor(1);
    LParseLang.SetVersionInfoMinor(0);
    LParseLang.SetVersionInfoPatch(0);
    LParseLang.SetVersionInfoProductName('Hello');
    LParseLang.SetVersionInfoDescription('MyLang Hello World');
    LParseLang.SetVersionInfoFilename('hello.exe');
    LParseLang.SetVersionInfoCompanyName('ParseLang');
    LParseLang.SetVersionInfoCopyright('Copyright 2025 ParseLang');
    *)

    LParseLang.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        TParseUtils.PrintLn(AText);
      end
    );

    LParseLang.SetOutputCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        TParseUtils.Print(ALine);
      end
    );

    LParseLang.Compile(True, True);
    ShowErrors(LParseLang);

  finally
    LParseLang.Free();
  end;
end;

procedure Test02();
var
  LParseLang: TParseLang;
begin
  LParseLang := TParseLang.Create();
  try
    LParseLang.SetLangFile('..\..\..\CPascal\repo\bin\CPascal.parse');
    LParseLang.SetSourceFile('..\..\..\CPascal\repo\bin\tests\test_program_hello.cp');
    LParseLang.SetOutputPath('..\..\..\CPascal\repo\bin\output');
    LParseLang.SetLineDirectives(True);

    (*
    LParseLang.SetAddVersionInfo(True);
    LParseLang.SetExeIcon('');
    LParseLang.SetVersionInfoMajor(1);
    LParseLang.SetVersionInfoMinor(0);
    LParseLang.SetVersionInfoPatch(0);
    LParseLang.SetVersionInfoProductName('Hello');
    LParseLang.SetVersionInfoDescription('MyLang Hello World');
    LParseLang.SetVersionInfoFilename('hello.exe');
    LParseLang.SetVersionInfoCompanyName('ParseLang');
    LParseLang.SetVersionInfoCopyright('Copyright 2025 ParseLang');
    *)

    LParseLang.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        TParseUtils.PrintLn(AText);
      end
    );

    LParseLang.SetOutputCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        TParseUtils.Print(ALine);
      end
    );

    LParseLang.Compile(True, True);
    ShowErrors(LParseLang);

  finally
    LParseLang.Free();
  end;
end;

procedure RunTestbed();
begin
  try
    //Test01();
    Test02();

  except
    on E: Exception do
    begin
      TParseUtils.PrintLn('');
      TParseUtils.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message);
    end;
  end;

  if TParseUtils.RunFromIDE() then
    TParseUtils.Pause();
end;

end.
