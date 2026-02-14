# --- Fix Encoding for PowerShell 5.1 ---
if ($PSVersionTable.PSVersion.Major -le 5)
{
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  [Console]::InputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
}

# --- Language Selection ---
# Load Constants first (try local then installed)
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ConstPath = if (Test-Path (Join-Path $RepoRoot "src\constants.ps1"))
{ Join-Path $RepoRoot "src\constants.ps1"
} else
{ Join-Path $HOME ".config\FrontNox\bin\constants.ps1"
}

if (Test-Path $ConstPath)
{ . $ConstPath
}

$Lang = if (Test-Path $NoxLangFile)
{ (Get-Content $NoxLangFile -Raw).Trim()
} else
{ "en"
}

# Try to find i18n resources
$I18nDir = if (Test-Path (Join-Path $RepoRoot "src\i18n"))
{ Join-Path $RepoRoot "src\i18n"
} else
{ $NoxI18nDir
}

$I18nPath = Join-Path $I18nDir "$Lang.json"
if (-not (Test-Path $I18nPath))
{ $I18nPath = Join-Path $I18nDir "en.json"
}

$M = (Get-Content $I18nPath -Raw -Encoding UTF8 | ConvertFrom-Json).uninstall

$Choice = Read-Host $M.Confirm
if ($Choice -ne 'y')
{
  Write-Host $M.Aborted -ForegroundColor Yellow
  return
}

Write-Host "`n$($M.Cleaning)" -ForegroundColor Cyan

# --- Remove from Profile ---
$AllProfiles = @(
  $PROFILE,
  (Join-Path $HOME "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
  (Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
) | Select-Object -Unique

foreach ($Path in $AllProfiles)
{
  if (Test-Path $Path)
  {
    $Lines = Get-Content $Path -ErrorAction SilentlyContinue
    if ($null -ne $Lines)
    {
      $NewLines = $Lines | Where-Object {
        $_ -notmatch "# --- FrontNox ---" -and
        $_ -notmatch "Scripts[\\/]FrontNox" -and
        $_ -notmatch "\.frontnox[\\/]bin" -and
        $_ -notmatch "\.config[\\/]FrontNox[\\/]bin"
      }

      try
      {
        $TempFile = [System.IO.Path]::GetTempFileName()
        $NewLines | Set-Content $TempFile -Encoding UTF8
        if (Test-Path $Path)
        { Set-ItemProperty -Path $Path -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        }
        Move-Item -Path $TempFile -Destination $Path -Force -ErrorAction Stop

        if ($Path -eq $PROFILE)
        { Write-Host $M.Profile -ForegroundColor Green
        }
      } catch
      {
        Write-Host "$($M.AccessError) $Path" -ForegroundColor Red
      }
    }
  }
}

# --- Delete Files ---
if ($NoxLegacyDocsDir)
{ if (Test-Path $NoxLegacyDocsDir)
  { Remove-Item $NoxLegacyDocsDir -Recurse -Force
  }
}
if ($NoxLegacyTempDir)
{ if (Test-Path $NoxLegacyTempDir)
  { Remove-Item $NoxLegacyTempDir -Recurse -Force
  }
}
if ($NoxBinDir)
{ if (Test-Path $NoxBinDir)
  { Remove-Item $NoxBinDir -Recurse -Force
  }
}

Write-Host $M.Files -ForegroundColor Green

# --- Delete Proxy Logs ---
if (Test-Path $NoxProxyLogDir)
{
  Remove-Item $NoxProxyLogDir -Recurse -Force
  Write-Host $M.Logs -ForegroundColor Green
}

# --- Delete Config ---
if (Test-Path $NoxConfigDir)
{
  $Keep = Read-Host $M.KeepProjects
  if ($Keep -eq 'y')
  {
    # Only remove language config, keep proj.json
    if (Test-Path $NoxLangFile)
    { Remove-Item $NoxLangFile -Force
    }
    Write-Host $M.Config -ForegroundColor Green
  } else
  {
    Remove-Item $NoxConfigDir -Recurse -Force
    Write-Host $M.Config -ForegroundColor Green
  }
}

Write-Host "`n$($M.Done)" -ForegroundColor Gray
