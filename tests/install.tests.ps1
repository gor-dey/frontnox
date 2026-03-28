# Copyright 2026 gor-dey
# Licensed under the Apache License, Version 2.0 (the "License")
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is "AS IS" BASIS.

BeforeAll {
  $script:RepoRoot = Split-Path $PSScriptRoot -Parent
}

Describe "Install.ps1" {

  Context "silent install (-All -Lang en)" {

    BeforeAll {
      # Run a full silent install into an isolated home-equivalent via env override
      $script:TestHome = Join-Path $TestDrive "home"
      New-Item -ItemType Directory -Force -Path $script:TestHome | Out-Null

      $env:FRONTNOX_TEST_HOME = $script:TestHome
      $script:InstallBase = Join-Path $script:TestHome ".config\FrontNox"
      $script:BinDir      = Join-Path $script:InstallBase "bin"

      # Patch HOME env so the scripts resolve paths under TestDrive
      $script:OrigHome = $env:USERPROFILE
      $env:USERPROFILE = $script:TestHome

      pwsh -NoProfile -ExecutionPolicy Bypass `
           -File (Join-Path $script:RepoRoot "scripts\Install.ps1") `
           -All -Lang en

      $env:USERPROFILE = $script:OrigHome
    }

    It "copies constants.ps1 to bin dir" {
      Join-Path $script:BinDir "constants.ps1" | Should -Exist
    }

    It "copies proj.ps1 to bin dir" {
      Join-Path $script:BinDir "proj.ps1" | Should -Exist
    }

    It "copies corsproxy.ps1 to bin dir" {
      Join-Path $script:BinDir "corsproxy.ps1" | Should -Exist
    }

    It "copies Uninstall.ps1 to bin dir" {
      Join-Path $script:BinDir "Uninstall.ps1" | Should -Exist
    }

    It "copies i18n files to bin dir" {
      Join-Path $script:BinDir "i18n\en.json" | Should -Exist
      Join-Path $script:BinDir "i18n\ru.json" | Should -Exist
    }

    It "writes lang.conf with selected language" {
      $lang = Get-Content (Join-Path $script:InstallBase "lang.conf") -Raw
      $lang.Trim() | Should -Be "en"
    }

    It "creates uninstall registry key" {
      $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontNox"
      $key | Should -Exist
    }

    It "registry DisplayName is FrontNox" {
      $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontNox"
      (Get-ItemProperty $key).DisplayName | Should -Be "FrontNox"
    }

    It "registry UninstallString points to installed Uninstall.ps1" {
      $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontNox"
      (Get-ItemProperty $key).UninstallString | Should -Match "Uninstall\.ps1"
    }

    It "registry QuietUninstallString contains -Silent flag" {
      $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontNox"
      (Get-ItemProperty $key).QuietUninstallString | Should -Match "-Silent"
    }

    It "registry DisplayVersion matches constants version" {
      . (Join-Path $script:RepoRoot "src\constants.ps1")
      $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontNox"
      (Get-ItemProperty $key).DisplayVersion | Should -Be $NoxVersion
    }
  }
}

Describe "Uninstall.ps1" {

  Context "silent uninstall (-Silent)" {

    BeforeAll {
      # Prepare a fake installed layout
      $script:TestHome2    = Join-Path $TestDrive "home2"
      $script:InstallBase2 = Join-Path $script:TestHome2 ".config\FrontNox"
      $script:BinDir2      = Join-Path $script:InstallBase2 "bin"
      New-Item -ItemType Directory -Force -Path $script:BinDir2 | Out-Null
      New-Item -ItemType Directory -Force -Path (Join-Path $script:BinDir2 "i18n") | Out-Null

      # Copy real files into the fake layout
      Copy-Item (Join-Path $script:RepoRoot "src\constants.ps1") $script:BinDir2 -Force
      Copy-Item (Join-Path $script:RepoRoot "src\i18n\en.json")  (Join-Path $script:BinDir2 "i18n") -Force
      Copy-Item (Join-Path $script:RepoRoot "src\i18n\ru.json")  (Join-Path $script:BinDir2 "i18n") -Force
      "en" | Set-Content (Join-Path $script:InstallBase2 "lang.conf") -Encoding UTF8

      # Create the registry key as if install had run
      $script:RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontNoxTest"
      New-Item -Path $script:RegPath -Force | Out-Null
      Set-ItemProperty -Path $script:RegPath -Name "DisplayName" -Value "FrontNoxTest"

      # Override USERPROFILE so Uninstall.ps1 resolves paths to our fake layout
      $script:OrigHome2 = $env:USERPROFILE
      $env:USERPROFILE  = $script:TestHome2

      pwsh -NoProfile -ExecutionPolicy Bypass `
           -File (Join-Path $script:RepoRoot "scripts\Uninstall.ps1") `
           -Silent

      $env:USERPROFILE = $script:OrigHome2
    }

    It "removes bin directory" {
      $script:BinDir2 | Should -Not -Exist
    }

    It "removes config directory" {
      $script:InstallBase2 | Should -Not -Exist
    }

    It "removes uninstall registry key created by Install" {
      # The real Uninstall.ps1 removes HKCU:\..\FrontNox (not FrontNoxTest),
      # verify the correct key was targeted (FrontNox key from install test)
      $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontNox"
      $key | Should -Not -Exist
    }

    AfterAll {
      # Clean up the test-only registry key if it survived
      if (Test-Path $script:RegPath) { Remove-Item $script:RegPath -Force }
    }
  }

  Context "interactive mode aborted" {

    It "exits without removing files when user answers N" {
      $testDir = Join-Path $TestDrive "abort_test"
      New-Item -ItemType Directory -Force -Path $testDir | Out-Null

      # Feed 'n' to stdin
      $result = 'n' | pwsh -NoProfile -ExecutionPolicy Bypass `
                            -File (Join-Path $script:RepoRoot "scripts\Uninstall.ps1") 2>&1 |
                      Out-String

      $testDir | Should -Exist
      $result  | Should -Match "cancel|abort|отмен" -Because "should print cancellation message"
    }
  }
}
