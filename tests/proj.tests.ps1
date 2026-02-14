BeforeAll {
  $RepoRoot = Split-Path $PSScriptRoot -Parent
  . (Join-Path $RepoRoot "src\constants.ps1")
  . (Join-Path $RepoRoot "src\proj.ps1")

  # Save original paths and override with test-isolated paths (script scope
  # ensures the proj function sees these overrides via dynamic scoping)
  $script:OrigNoxConfigDir = $NoxConfigDir
  $script:OrigNoxProjFile  = $NoxProjFile
  $script:OrigNoxLangFile  = $NoxLangFile
  $script:OrigNoxI18nDir   = $NoxI18nDir

  $script:NoxConfigDir = Join-Path $TestDrive "FrontNox"
  $script:NoxProjFile  = Join-Path $script:NoxConfigDir "proj.json"
  $script:NoxLangFile  = Join-Path $script:NoxConfigDir "lang.conf"
  $script:NoxI18nDir   = Join-Path $RepoRoot "src\i18n"
}

AfterAll {
  # Restore original paths so the real config is never polluted
  $script:NoxConfigDir = $script:OrigNoxConfigDir
  $script:NoxProjFile  = $script:OrigNoxProjFile
  $script:NoxLangFile  = $script:OrigNoxLangFile
  $script:NoxI18nDir   = $script:OrigNoxI18nDir
}

Describe "proj" {

  BeforeEach {
    New-Item -ItemType Directory -Force -Path $NoxConfigDir | Out-Null
    "{}" | Set-Content $NoxProjFile -Encoding UTF8
    "en" | Set-Content $NoxLangFile -Encoding UTF8

    # Prevent OSC 8 escape sequences and ANSI codes from reaching VS Code terminal
    Mock Write-Host { Write-Information "$Object" }
  }

  Context "version" {
    It "outputs version string" {
      $output = (proj -Version) *>&1 | Out-String
      $output | Should -Match "FrontNox v\d+\.\d+\.\d+"
    }
  }

  Context "usage" {
    It "shows usage when no action given" {
      $output = (proj) *>&1 | Out-String
      $output | Should -Match "Usage"
    }
  }

  Context "add" {
    It "saves the current directory as a project" {
      Push-Location $TestDrive
      try { proj add testproj *>&1 | Out-Null } finally { Pop-Location }

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.testproj | Should -Be $TestDrive
    }

    It "overwrites an existing project path" {
      $dir1 = Join-Path $TestDrive "a"
      $dir2 = Join-Path $TestDrive "b"
      New-Item -ItemType Directory -Force -Path $dir1, $dir2 | Out-Null

      Push-Location $dir1
      try { proj add sameproj *>&1 | Out-Null } finally { Pop-Location }

      Push-Location $dir2
      try { proj add sameproj *>&1 | Out-Null } finally { Pop-Location }

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.sameproj | Should -Be $dir2
    }

    It "shows error when name is missing" {
      $output = (proj add) *>&1 | Out-String
      $output | Should -Match "required|name"
    }

    It "rejects invalid project name with spaces" {
      Push-Location $TestDrive
      try {
        proj add "my project" *>&1 | Out-Null
      } finally { Pop-Location }

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.psobject.Properties.Name | Should -Not -Contain "my project"
    }

    It "rejects invalid project name with special chars" {
      Push-Location $TestDrive
      try {
        proj add "../../etc" *>&1 | Out-Null
      } finally { Pop-Location }

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.psobject.Properties.Name | Should -Not -Contain "../../etc"
    }

    It "accepts valid project name with dots and dashes" {
      Push-Location $TestDrive
      try { proj add "my-app.v2" *>&1 | Out-Null } finally { Pop-Location }

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.'my-app.v2' | Should -Be $TestDrive
    }
  }

  Context "list" {
    It "shows empty message when no projects" {
      $output = (proj list) *>&1 | Out-String
      $output | Should -Match "No projects|proj add|no projects"
    }

    It "lists added projects" {
      Push-Location $TestDrive
      try { proj add myproj *>&1 | Out-Null } finally { Pop-Location }

      $output = (proj list) *>&1 | Out-String
      $output | Should -Match "myproj"
    }
  }

  Context "remove" {
    It "removes an existing project" {
      Push-Location $TestDrive
      try { proj add toremove *>&1 | Out-Null } finally { Pop-Location }

      proj remove toremove *>&1 | Out-Null

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.psobject.Properties.Name | Should -Not -Contain "toremove"
    }

    It "shows message for non-existent project" {
      $output = (proj remove ghost) *>&1 | Out-String
      $output | Should -Match "not found"
    }

    It "shows error when name is missing" {
      $output = (proj remove) *>&1 | Out-String
      $output | Should -Match "required|name"
    }
  }

  Context "rename" {
    It "renames a project preserving its path" {
      Push-Location $TestDrive
      try { proj add oldname *>&1 | Out-Null } finally { Pop-Location }

      proj rename oldname newname *>&1 | Out-Null

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.psobject.Properties.Name | Should -Contain "newname"
      $json.psobject.Properties.Name | Should -Not -Contain "oldname"
      $json.newname | Should -Be $TestDrive
    }

    It "fails when source project does not exist" {
      $output = (proj rename nosuch newname) *>&1 | Out-String
      $output | Should -Match "not found"
    }

    It "fails when target name already exists" {
      $dir1 = Join-Path $TestDrive "x"
      $dir2 = Join-Path $TestDrive "y"
      New-Item -ItemType Directory -Force -Path $dir1, $dir2 | Out-Null

      Push-Location $dir1
      try { proj add first *>&1 | Out-Null } finally { Pop-Location }
      Push-Location $dir2
      try { proj add second *>&1 | Out-Null } finally { Pop-Location }

      $output = (proj rename first second) *>&1 | Out-String
      $output | Should -Match "already exists"
    }

    It "shows error when names are missing" {
      $output = (proj rename) *>&1 | Out-String
      $output | Should -Match "Usage|rename"
    }
  }

  Context "go" {
    It "changes directory to the project path" {
      $projDir = Join-Path $TestDrive "myproject"
      New-Item -ItemType Directory -Force -Path $projDir | Out-Null

      Push-Location $projDir
      try { proj add gotest *>&1 | Out-Null } finally { Pop-Location }

      $origDir = (Get-Location).Path
      try {
        proj go gotest *>&1 | Out-Null
        (Get-Location).Path | Should -Be $projDir
      } finally {
        Set-Location $origDir
      }
    }

    It "shows error for non-existent project" {
      $output = (proj go nowhere) *>&1 | Out-String
      $output | Should -Match "not found"
    }

    It "shows error when name is missing" {
      $output = (proj go) *>&1 | Out-String
      $output | Should -Match "required|name"
    }
  }

  Context "run" {
    It "shows error when name is missing" {
      $output = (proj run) *>&1 | Out-String
      $output | Should -Match "required|name"
    }

    It "runs current directory with dot argument" {
      $projDir = Join-Path $TestDrive "dotproj"
      New-Item -ItemType Directory -Force -Path $projDir | Out-Null

      '{"scripts":{"dev":"echo ok"}}' | Set-Content (Join-Path $projDir "package.json") -Encoding UTF8
      New-Item -ItemType Directory -Force -Path (Join-Path $projDir "node_modules") | Out-Null

      $origDir = (Get-Location).Path
      try {
        Set-Location $projDir
        $output = (proj run .) *>&1 | Out-String
        $output | Should -Match "npm run dev|echo ok|ok"
      } finally {
        Set-Location $origDir
      }
    }
  }

  Context "localization" {
    It "loads Russian without errors" {
      "ru" | Set-Content $NoxLangFile -Encoding UTF8

      Push-Location $TestDrive
      try { proj add rutest *>&1 | Out-Null } finally { Pop-Location }

      $json = Get-Content $NoxProjFile -Raw | ConvertFrom-Json
      $json.rutest | Should -Be $TestDrive
    }

    It "falls back to English for unknown language" {
      "xx" | Set-Content $NoxLangFile -Encoding UTF8

      $output = (proj -Version) *>&1 | Out-String
      $output | Should -Match "FrontNox v"
    }
  }
}
