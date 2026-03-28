# Copyright 2026 gor-dey
# Licensed under the Apache License, Version 2.0 (the "License")
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is "AS IS" BASIS.

. (Join-Path $PSScriptRoot 'constants.ps1')

if (-not (Test-Path $NoxBinDir))
{
  New-Item -ItemType Directory -Force -Path $NoxBinDir | Out-Null
}

$ModuleI18nDir = Join-Path $PSScriptRoot 'i18n'
if (Test-Path $ModuleI18nDir)
{
  if (-not (Test-Path $NoxI18nDir))
  {
    New-Item -ItemType Directory -Force -Path $NoxI18nDir | Out-Null
  }
  Copy-Item -Path "$ModuleI18nDir\*" -Destination $NoxI18nDir -Force
}

. (Join-Path $PSScriptRoot 'proj.ps1')
. (Join-Path $PSScriptRoot 'corsproxy.ps1')
