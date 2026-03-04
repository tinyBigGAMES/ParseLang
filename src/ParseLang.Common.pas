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
  end;

implementation

end.
