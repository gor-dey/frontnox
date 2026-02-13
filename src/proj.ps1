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

# --- LOCALIZATION ---
function Get-Msg($Key, $Arg)
{
  $Lang = if (Test-Path $NoxLangFile)
  { (Get-Content $NoxLangFile -Raw).Trim()
  } else
  { "en"
  }
  $I18nPath = Join-Path $NoxI18nDir "$Lang.json"
  if (-not (Test-Path $I18nPath))
  { $I18nPath = Join-Path $NoxI18nDir "en.json"
  }

  $Messages = Get-Content $I18nPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $m = $Messages.proj.$Key
  if ($Arg)
  {
    return $m -f $Arg
  }
  return $m
}

# Load project map
$Global:ProjMap = Get-Content $NoxProjFile -Raw -Encoding UTF8 | ConvertFrom-Json

function proj
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("list", "add", "remove", "run", "go")]
    [string]$Action,

    [Parameter(Position = 1)]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $action = $fakeBoundParameters['Action']
        if ($action -match 'run|remove|go')
        {
          return $Global:ProjMap.psobject.Properties.Name | Where-Object { $_ -like "$wordToComplete*" }
        }
        return $null
      })]
    [string]$Name
  )

  switch ($Action)
  {
    "list"
    {
      Write-Host "`n$(Get-Msg Header)" -ForegroundColor Cyan
      if ($Global:ProjMap.psobject.Properties.Count -eq 0)
      {
        Write-Host $(Get-Msg Empty) -ForegroundColor DarkGray
      } else
      {
        $esc = [char]27
        foreach ($prop in $Global:ProjMap.psobject.Properties)
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
      $Path = (Get-Location).Path
      if ($null -eq $Global:ProjMap.psobject.Properties[$Name])
      {
        $Global:ProjMap | Add-Member -MemberType NoteProperty -Name $Name -Value $Path
      } else
      {
        $Global:ProjMap.$Name = $Path
      }
      $Global:ProjMap | ConvertTo-Json | Set-Content $NoxProjFile -Encoding UTF8
      Write-Host $(Get-Msg Saved $Name) -ForegroundColor Green
    }

    "remove"
    {
      if (-not $Name)
      {
        return
      }
      if ($null -ne $Global:ProjMap.psobject.Properties[$Name])
      {
        $Global:ProjMap.psobject.Properties.Remove($Name)
        $Global:ProjMap | ConvertTo-Json | Set-Content $NoxProjFile -Encoding UTF8
        Write-Host $(Get-Msg Removed $Name) -ForegroundColor Yellow
      } else
      {
        Write-Host $(Get-Msg NotFound $Name) -ForegroundColor DarkGray
      }
    }

    "run"
    {
      $p = $Global:ProjMap.$Name
      if ($p -and (Test-Path $p))
      {
        Set-Location $p
        Write-Host "`n$(Get-Msg Launching $p)" -ForegroundColor Cyan

        if (Test-Path "package.json")
        {
          if (-not (Test-Path "node_modules"))
          {
            Write-Host $(Get-Msg MissingNodes) -ForegroundColor Yellow
            npm install
            if ($LASTEXITCODE -ne 0)
            {
              Write-Host $(Get-Msg InstallFail) -ForegroundColor Red
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
              Write-Host $(Get-Msg Executing $cmd) -ForegroundColor Gray
              npm run $cmd
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
      $p = $Global:ProjMap.$Name
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
