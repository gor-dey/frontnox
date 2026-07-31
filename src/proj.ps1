# Copyright 2026 gor-dey
# Licensed under the Apache License, Version 2.0 (the "License")
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is "AS IS" BASIS.

# --- Fix Encoding for PowerShell 5.1 ---
if ($PSVersionTable.PSVersion.Major -le 5)
{
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
}

# --- Load Constants ---
$ScriptRoot = $PSScriptRoot
. (Join-Path $ScriptRoot "constants.ps1")

# --- DATA STORAGE SETUP ---
if (-not (Test-Path $NoxConfigDir))
{
  New-Item -ItemType Directory -Force -Path $NoxConfigDir | Out-Null
}

if (-not (Test-Path $NoxProjFile))
{
  "{}" | Set-Content $NoxProjFile -Encoding UTF8
}

if (-not (Test-Path $NoxLangFile))
{
  "en" | Set-Content $NoxLangFile -Encoding UTF8
}

function proj
{
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [ValidateSet("list", "add", "remove", "rename", "run", "go")]
    [string]$Action,

    [Parameter(Position = 1)]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $action = $fakeBoundParameters['Action']
        if ($action -match 'run|remove|go|rename')
        {
          $projFile = Join-Path (Join-Path $HOME ".config\FrontNox") "proj.json"
          if (Test-Path $projFile)
          {
            $map = Get-Content $projFile -Raw -Encoding UTF8 | ConvertFrom-Json
            return $map.psobject.Properties.Name | Where-Object { $_ -like "$wordToComplete*" }
          }
        }
        return $null
      })]
    [string]$Name,

    [Parameter(Position = 2)]
    [string]$NewName,

    [switch]$NoTui,

    [switch]$Version
  )

  # --- Load messages once per invocation ---
  $Lang = if (Test-Path $NoxLangFile)
  { (Get-Content $NoxLangFile -Raw -Encoding UTF8).Trim()
  } else
  { "en"
  }
  $I18nPath = Join-Path $NoxI18nDir "$Lang.json"
  if (-not (Test-Path $I18nPath))
  { $I18nPath = Join-Path $NoxI18nDir "en.json"
  }
  $Messages = Get-Content $I18nPath -Raw -Encoding UTF8 | ConvertFrom-Json

  function Get-Msg($Key, $Arg1, $Arg2, $Arg3)
  {
    $m = $Messages.proj.$Key
    if ($Arg3)
    { return $m -f $Arg1, $Arg2, $Arg3
    }
    if ($Arg2)
    { return $m -f $Arg1, $Arg2
    }
    if ($Arg1)
    { return $m -f $Arg1
    }
    return $m
  }

  function Test-ProjName($n)
  {
    if ($n -notmatch '^[a-zA-Z0-9_\.\-]{1,50}$')
    {
      Write-Host $(Get-Msg ErrBadName) -ForegroundColor Red
      return $false
    }
    return $true
  }

  if ($Version)
  {
    Write-Host "FrontNox v$NoxVersion"
    return
  }

  if (-not $Action)
  {
    Write-Host (Get-Msg Usage) -ForegroundColor Gray
    return
  }

  # Reload project map from disk
  $ProjMap = Get-Content $NoxProjFile -Raw -Encoding UTF8 | ConvertFrom-Json

  switch ($Action)
  {
    "list"
    {
      Write-Host "`n$(Get-Msg Header)" -ForegroundColor Cyan
      if (@($ProjMap.psobject.Properties).Count -eq 0)
      {
        Write-Host $(Get-Msg Empty) -ForegroundColor DarkGray
      } else
      {
        $esc = [char]27
        foreach ($prop in $ProjMap.psobject.Properties)
        {
          $path = $prop.Value
          try
          {
            $uri = ([Uri]$path).AbsoluteUri
          } catch
          {
            $uri = $path
          }
          $clickablePath = "$esc]8;;$uri$esc\$path$esc]8;;$esc\"
          Write-Host "  $($prop.Name)" -NoNewline -ForegroundColor White
          Write-Host " -> " -NoNewline -ForegroundColor DarkGray
          Write-Host $clickablePath -ForegroundColor Gray
        }
      }
      Write-Host ""
    }

    "add"
    {
      if (-not $Name)
      {
        Write-Host $(Get-Msg ErrNameReq) -ForegroundColor Red
        return
      }
      if (-not (Test-ProjName $Name))
      {
        return
      }
      $Path = (Get-Location).Path
      if ($null -eq $ProjMap.psobject.Properties[$Name])
      {
        $ProjMap | Add-Member -MemberType NoteProperty -Name $Name -Value $Path
      } else
      {
        $ProjMap.$Name = $Path
      }
      $ProjMap | ConvertTo-Json | Set-Content $NoxProjFile -Encoding UTF8
      Write-Host $(Get-Msg Saved $Name) -ForegroundColor Green
    }

    "remove"
    {
      if (-not $Name)
      {
        Write-Host $(Get-Msg ErrNameReq) -ForegroundColor Red
        return
      }
      if ($null -ne $ProjMap.psobject.Properties[$Name])
      {
        $ProjMap.psobject.Properties.Remove($Name)
        $ProjMap | ConvertTo-Json | Set-Content $NoxProjFile -Encoding UTF8
        Write-Host $(Get-Msg Removed $Name) -ForegroundColor Yellow
      } else
      {
        Write-Host $(Get-Msg NotFound $Name) -ForegroundColor DarkGray
      }
    }

    "rename"
    {
      if (-not $Name -or -not $NewName)
      {
        Write-Host $(Get-Msg ErrRenameArgs) -ForegroundColor Red
        return
      }
      if (-not (Test-ProjName $Name))
      {
        return
      }
      if (-not (Test-ProjName $NewName))
      {
        return
      }
      if ($null -eq $ProjMap.psobject.Properties[$Name])
      {
        Write-Host $(Get-Msg NotFound $Name) -ForegroundColor Red
        return
      }
      if ($null -ne $ProjMap.psobject.Properties[$NewName])
      {
        Write-Host $(Get-Msg ErrRenameExists $NewName) -ForegroundColor Red
        return
      }
      $Path = $ProjMap.$Name
      $ProjMap.psobject.Properties.Remove($Name)
      $ProjMap | Add-Member -MemberType NoteProperty -Name $NewName -Value $Path
      $ProjMap | ConvertTo-Json | Set-Content $NoxProjFile -Encoding UTF8
      Write-Host $(Get-Msg Renamed $Name $NewName) -ForegroundColor Green
    }

    "run"
    {
      if (-not $Name)
      {
        Write-Host $(Get-Msg ErrNameReq) -ForegroundColor Red
        return
      }

      if ($Name -eq '.')
      {
        $p = (Get-Location).Path
      } else
      {
        $p = $ProjMap.$Name
      }

      if ($p -and (Test-Path $p))
      {
        Set-Location $p
        $launchMsg = if ($Name -eq '.')
        {
          Get-Msg LaunchingCwd $p
        } else
        {
          Get-Msg Launching $p
        }
        Write-Host "`n$launchMsg" -ForegroundColor Cyan

        # Project title for the banner and the console tab
        $projTitle = if ($Name -eq '.')
        {
          Split-Path $p -Leaf
        } else
        {
          $Name
        }
        try
        {
          $Host.UI.RawUI.WindowTitle = $projTitle
        } catch
        {
          # No console window (CI, ISE) — the title is cosmetic, skip it
        }

        if (Test-Path "package.json")
        {
          # Detect package manager by lock file
          $pm = "npm"
          if (Test-Path "bun.lockb")
          { $pm = "bun"
          } elseif (Test-Path "pnpm-lock.yaml")
          { $pm = "pnpm"
          } elseif (Test-Path "yarn.lock")
          { $pm = "yarn"
          }

          if ($pm -ne "npm")
          {
            Write-Host $(Get-Msg DetectedPM $pm) -ForegroundColor DarkGray
          }

          if (-not (Test-Path "node_modules"))
          {
            Write-Host $(Get-Msg MissingNodes $pm) -ForegroundColor Yellow
            & $pm install
            if ($LASTEXITCODE -ne 0)
            {
              Write-Host $(Get-Msg InstallFail $pm) -ForegroundColor Red
              return
            }
          }
          try
          {
            $pkg = Get-Content "package.json" -Raw -Encoding UTF8 | ConvertFrom-Json
            $scripts = $pkg.scripts.psobject.Properties.Name
            $cmd = if ($scripts -contains "dev")
            {
              "dev"
            } elseif ($scripts -contains "start")
            {
              "start"
            } else
            {
              $null
            }

            if ($cmd)
            {
              # Pinned-header TUI on VT-capable terminals; plain stream otherwise
              $rows = 0
              try
              {
                $rows = $Host.UI.RawUI.WindowSize.Height
              } catch
              {
                # No console window — plain mode
              }
              $useTui = -not $NoTui -and $Host.UI.SupportsVirtualTerminal -and $rows -gt 6

              $esc = [char]27
              if ($useTui)
              {
                $cols = $Host.UI.RawUI.WindowSize.Width
                $headerTitle = Get-Msg TuiTitle $projTitle
                $drawHeader = {
                  param($status)
                  $max = $cols - $headerTitle.Length - 5
                  if ($max -gt 0 -and $status.Length -gt $max)
                  {
                    $status = $status.Substring(0, $max)
                  }
                  [Console]::Write("${esc}7${esc}[1;1H${esc}[2K${esc}[96m$headerTitle${esc}[90m  |  ${esc}[93m$status${esc}[0m${esc}8")
                }

                Clear-Host
                # Reserve the two top rows for the header, scroll logs below them
                [Console]::Write("${esc}[3;${rows}r")
                & $drawHeader (Get-Msg TuiStarting)
                $sub = "$p  |  $pm run $cmd"
                if ($sub.Length -gt $cols)
                {
                  $sub = $sub.Substring(0, $cols)
                }
                [Console]::Write("${esc}[2;1H${esc}[2K${esc}[2m$($sub.PadRight($cols))${esc}[0m")
                [Console]::Write("${esc}[3;1H")
              } else
              {
                Write-Host (Get-Msg Banner $projTitle $p "$pm run $cmd") -ForegroundColor Cyan
              }

              # Stream the dev-server output, watching for the bound URL
              # to report the actual port and pin it to the header / tab title
              $script:FrontNoxLastPort = $null
              try
              {
                & $pm run $cmd 2>&1 | ForEach-Object {
                  $line = "$_"
                  Write-Host $line
                  # Strip ANSI escapes: colored output (e.g. Vite on a PTY)
                  # can split the URL with SGR codes and break the match
                  $clean = $line -replace "${esc}\[[0-9;?]*[A-Za-z]", ''
                  if ($clean -match '(https?://(?:localhost|127\.0\.0\.1|\[::1\]):(\d+))')
                  {
                    $url = $Matches[1]
                    $port = $Matches[2]
                    if ($port -ne $script:FrontNoxLastPort)
                    {
                      $script:FrontNoxLastPort = $port
                      if ($useTui)
                      {
                        & $drawHeader $url
                      }
                      try
                      {
                        $Host.UI.RawUI.WindowTitle = "$projTitle :$port"
                      } catch
                      {
                        # No console window (CI, ISE) — the title is cosmetic, skip it
                      }
                      Write-Host (Get-Msg Live $projTitle $url) -ForegroundColor Green
                    }
                  }
                }
              } finally
              {
                if ($useTui)
                {
                  # Give the whole window back to normal scrolling
                  [Console]::Write("${esc}[r")
                }
              }
            } else
            {
              Write-Host $(Get-Msg NoScripts) -ForegroundColor Yellow
              Write-Host $(Get-Msg Available ($scripts -join ', ')) -ForegroundColor DarkGray
            }
          } catch
          {
            Write-Host $(Get-Msg InvalidPkg) -ForegroundColor Red
          }
        } else
        {
          Write-Host $(Get-Msg NoPkg) -ForegroundColor DarkGray
        }
      } else
      {
        Write-Host $(Get-Msg NotFound $Name) -ForegroundColor Red
      }
    }

    "go"
    {
      if (-not $Name)
      {
        Write-Host $(Get-Msg ErrNameReq) -ForegroundColor Red
        return
      }
      $p = $ProjMap.$Name
      if ($p -and (Test-Path $p))
      {
        Set-Location -Path $p
        Write-Host "  $p" -ForegroundColor Gray
      } else
      {
        Write-Host $(Get-Msg NotFound $Name) -ForegroundColor Red
      }
    }


  }
}
