# --- FrontNox Constants ---
$NoxVersion     = "1.0.0"
$NoxBaseDir     = Join-Path $HOME ".config\FrontNox"
$NoxBinDir      = Join-Path $NoxBaseDir "bin"
$NoxConfigDir   = $NoxBaseDir
$NoxProjFile    = Join-Path $NoxConfigDir "proj.json"
$NoxLangFile    = Join-Path $NoxConfigDir "lang.conf"
$NoxI18nDir     = Join-Path $NoxBinDir "i18n"
$NoxProxyLogDir = "$env:TEMP\NoxProxyLogs"

# Legacy paths for cleanup
$NoxLegacyDocsDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Scripts\FrontNox"
$NoxLegacyTempDir = Join-Path $HOME ".frontnox"
