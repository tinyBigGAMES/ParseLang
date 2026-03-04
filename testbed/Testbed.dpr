{===============================================================================
  ParseLang™ - Describe It. Parse It. Build It.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://parselang.org

  See LICENSE for license information
===============================================================================}

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ParseLang.CodeGen in '..\src\ParseLang.CodeGen.pas',
  ParseLang.Common in '..\src\ParseLang.Common.pas',
  ParseLang.Grammar in '..\src\ParseLang.Grammar.pas',
  ParseLang.Lexer in '..\src\ParseLang.Lexer.pas',
  ParseLang in '..\src\ParseLang.pas',
  ParseLang.Semantics in '..\src\ParseLang.Semantics.pas',
  UTestbed in 'UTestbed.pas';

begin
  RunTestbed();
end.
