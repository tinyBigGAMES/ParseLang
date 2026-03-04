{===============================================================================
  ParseLang™ - Describe It. Parse It. Build It.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://parselang.org

  See LICENSE for license information
===============================================================================}

unit ParseLang.Common;

{$I ParseLang.Defines.inc}

interface

uses
  System.SysUtils;

type

  { TParseLangPipelineCallbacks }
  TParseLangPipelineCallbacks = record
    OnSetPlatform:      TProc<string>;
    OnSetBuildMode:     TProc<string>;
    OnSetOptimize:      TProc<string>;
    OnSetSubsystem:     TProc<string>;
    OnSetOutputPath:    TProc<string>;
    OnSetVIEnabled:     TProc<string>;
    OnSetVIExeIcon:     TProc<string>;
    OnSetVIMajor:       TProc<string>;
    OnSetVIMinor:       TProc<string>;
    OnSetVIPatch:       TProc<string>;
    OnSetVIProductName: TProc<string>;
    OnSetVIDescription: TProc<string>;
    OnSetVIFilename:    TProc<string>;
    OnSetVICompanyName: TProc<string>;
    OnSetVICopyright:   TProc<string>;
    OnAddSourceFile:     TProc<string>;
    OnAddIncludePath:    TProc<string>;
    OnAddLibraryPath:    TProc<string>;
    OnAddLinkLibrary:    TProc<string>;
    OnSetDefine:         TProc<string, string>;
    OnHasDefine:         TFunc<string, Boolean>;
    OnUnsetDefine:       TProc<string>;
    OnHasUndefine:       TFunc<string, Boolean>;
    OnAddCopyDLL:        TProc<string>;
  end;

implementation

end.
