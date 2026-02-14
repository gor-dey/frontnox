# --- Fix Encoding for PowerShell 5.1 ---
if ($PSVersionTable.PSVersion.Major -le 5)
{
  $OutputEncoding = [System.Text.Encoding]::UTF8
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  [Console]::InputEncoding = [System.Text.Encoding]::UTF8
  chcp 65001 | Out-Null
}

# --- Language Selection ---
function Select-WithTab
{
  param(
    [string]$Prompt,
    [string[]]$Options,
    [int]$Default = 0
  )

  # Fallback to Read-Host when console input is redirected
  if ([Console]::IsInputRedirected)
  {
    $input = Read-Host "$Prompt ($($Options -join '/'))"
    if ($input -in $Options)
    { return $input
    }
    return $Options[$Default]
  }

  $idx = $Default

  Write-Host "$Prompt " -NoNewline
  $optCol = [Console]::CursorLeft
  $optRow = [Console]::CursorTop

  while ($true)
  {
    [Console]::SetCursorPosition($optCol, $optRow)
    for ($i = 0; $i -lt $Options.Count; $i++)
    {
      if ($i -gt 0)
      { Write-Host " · " -NoNewline -ForegroundColor DarkGray
      }
      if ($i -eq $idx)
      { Write-Host $Options[$i] -NoNewline -ForegroundColor Cyan
      } else
      { Write-Host $Options[$i] -NoNewline -ForegroundColor DarkGray
      }
    }
    Write-Host "  " -NoNewline

    $key = [Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::Tab -or $key.Key -eq [ConsoleKey]::RightArrow)
    { $idx = ($idx + 1) % $Options.Count
    } elseif ($key.Key -eq [ConsoleKey]::LeftArrow)
    { $idx = ($idx - 1 + $Options.Count) % $Options.Count
    } elseif ($key.Key -eq [ConsoleKey]::Enter)
    {
      Write-Host ""
      return $Options[$idx]
    }
  }
}

$Lang = Select-WithTab -Prompt "Select language / Выберите язык:" -Options @("en", "ru") -Default 0

# Determine repository root (script lives in <repo>/scripts)
$RepoRoot = Split-Path $PSScriptRoot -Parent

# Load Constants
. (Join-Path $RepoRoot "src\constants.ps1")

$I18nPath = Join-Path $RepoRoot "src\i18n\$Lang.json"
$M = (Get-Content $I18nPath -Raw -Encoding UTF8 | ConvertFrom-Json).install

# --- Configuration ---
$Tools = @(
  @{ Name = "Project Manager"; Command = "proj"; File = "proj.ps1" },
  @{ Name = "CORS Proxy";      Command = "corsproxy"; File = "corsproxy.ps1" }
)

Write-Host $M.Welcome -ForegroundColor Cyan
Write-Host $M.Select

$ToInstall = @()

foreach ($Tool in $Tools)
{
  $Choice = Read-Host ($M.Install -f $Tool.Name, $Tool.Command)
  if ($Choice -eq 'y')
  { $ToInstall += $Tool
  }
}

if ($ToInstall.Count -eq 0)
{
  Write-Host $M.NoTools -ForegroundColor Red
  return
}

# --- Installation Process ---
if (-not (Test-Path $NoxBinDir))
{ New-Item -ItemType Directory -Force -Path $NoxBinDir | Out-Null
}

# Copy Constants & i18n
Copy-Item (Join-Path $RepoRoot "src\constants.ps1") -Destination $NoxBinDir -Force
$I18nSource = Join-Path $RepoRoot "src\i18n"
if (Test-Path $I18nSource)
{
  Copy-Item $I18nSource -Destination $NoxBinDir -Recurse -Force
}

# --- Configuration & Profile ---
if (-not (Test-Path $NoxConfigDir))
{ New-Item -ItemType Directory -Force -Path $NoxConfigDir | Out-Null
}
$Lang | Set-Content $NoxLangFile -Encoding UTF8 -NoNewline

# Clean all possible profiles
$AllProfiles = @(
  $PROFILE,
  (Join-Path $HOME "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
  (Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
) | Select-Object -Unique

$LinesToAdd = @("`n# --- FrontNox ---")
foreach ($Tool in $ToInstall)
{
  $Source = Join-Path $RepoRoot "src\$($Tool.File)"
  $Dest = Join-Path $NoxBinDir $Tool.File
  Copy-Item $Source -Destination $Dest -Force
  $LinesToAdd += ". '$Dest'"
  Write-Host ($M.Inst -f $Tool.Name) -ForegroundColor Green
}

foreach ($Path in $AllProfiles)
{
  if (Test-Path $Path)
  {
    $ProfileContent = Get-Content $Path
    $NewProfile = $ProfileContent | Where-Object {
      $_ -notmatch "# --- FrontNox ---" -and
      $_ -notmatch "Scripts[\\/]FrontNox" -and
      $_ -notmatch "\.frontnox[\\/]bin" -and
      $_ -notmatch "\.config[\\/]FrontNox[\\/]bin"
    }

    # Only add lines to the current profile, others just clean
    $FinalContent = if ($Path -eq $PROFILE)
    { $NewProfile + $LinesToAdd
    } else
    { $NewProfile
    }

    try
    {
      $TempFile = [System.IO.Path]::GetTempFileName()
      $FinalContent | Set-Content -Path $TempFile -Encoding UTF8

      if (Test-Path $Path)
      { Set-ItemProperty -Path $Path -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
      }
      Move-Item -Path $TempFile -Destination $Path -Force -ErrorAction Stop

      if ($Path -eq $PROFILE)
      { Write-Host $M.Profile -ForegroundColor Cyan
      }
    } catch
    {
      Write-Host ("  Error: Cannot write to profile: $Path") -ForegroundColor Red
      if ($Path -eq $PROFILE)
      {
        Write-Host "  Close other terminal windows or editors and try again." -ForegroundColor Yellow
        Write-Host "  Or add these lines to your profile manually:" -ForegroundColor Gray
        $LinesToAdd | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
      }
    }
  }
}

Write-Host $M.Done -ForegroundColor Gray
