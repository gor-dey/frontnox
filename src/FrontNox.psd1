@{
  RootModule        = 'FrontNox.psm1'
  ModuleVersion     = '1.0.0'
  GUID              = '6e5d4c3b-2a19-4e8f-a7b6-c5d4e3f2a1b0'
  Author            = 'gor-dey'
  CompanyName       = 'gor-dey'
  Copyright         = 'Copyright 2026 gor-dey. Licensed under the Apache License, Version 2.0.'
  Description       = 'Frontend developer toolkit: manage project shortcuts (proj) and run a local CORS proxy (corsproxy). Zero dependencies, pure PowerShell.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('proj', 'corsproxy')
  CmdletsToExport   = @()
  VariablesToExport = @()
  AliasesToExport   = @()
  PrivateData       = @{
    PSData = @{
      Tags         = @('frontend', 'developer-tools', 'cors', 'cors-proxy', 'project-manager', 'workflow')
      LicenseUri   = 'https://github.com/gor-dey/frontnox/blob/main/LICENSE'
      ProjectUri   = 'https://github.com/gor-dey/frontnox'
      ReleaseNotes = 'Initial release'
    }
  }
}
