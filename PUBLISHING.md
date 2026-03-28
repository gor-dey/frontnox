# Publishing FrontNox to winget

This document explains how to publish a new version of FrontNox to the
[Windows Package Manager Community Repository](https://github.com/microsoft/winget-pkgs)
so that users can install it with:

```
winget install gor-dey.FrontNox
```

---

## Prerequisites

- A GitHub account with write access to this repository
- [winget-create](https://github.com/microsoft/winget-create) installed:
  ```
  winget install Microsoft.WingetCreate
  ```
- `winget` itself (built into Windows 10 1809+ and Windows 11):
  ```
  winget --version
  ```

---

## Step 1 — Create a GitHub release

1. Commit all changes and push a version tag:
   ```
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. The **Release** GitHub Actions workflow (`.github/workflows/release.yml`) will
   automatically:
   - Package all scripts into `FrontNox-<version>.zip`
   - Create a GitHub Release with that zip attached
   - Print the **SHA256 hash** of the zip in the release body

---

## Step 2 — Generate / update the winget manifests

The manifests in `winget/manifests/g/gor-dey/FrontNox/<version>/` are **templates**.
The `InstallerSha256` field in `gor-dey.FrontNox.installer.yaml` contains a placeholder
(`PLACEHOLDER_SHA256_UPDATE_BEFORE_SUBMISSION`) — **never submit to winget-pkgs with
this placeholder value**. Use **winget-create** to replace it with the real hash:

```powershell
wingetcreate update gor-dey.FrontNox `
  --version 1.0.0 `
  --urls https://github.com/gor-dey/frontnox/releases/download/v1.0.0/FrontNox-1.0.0.zip `
  --out winget/manifests
```

This fetches the zip, computes the real SHA256, and writes the YAML files.

---

## Step 3 — Validate the manifests locally

```powershell
winget validate --manifest winget/manifests/g/gor-dey/FrontNox/1.0.0/
```

All three manifests must pass validation before submission.

---

## Step 4 — Submit to winget-pkgs

Option A — via winget-create (recommended):

```powershell
wingetcreate submit winget/manifests/g/gor-dey/FrontNox/1.0.0/
```

This opens a pull request against
[microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) automatically.

Option B — manual:

1. Fork [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs)
2. Copy the three files from `winget/manifests/g/gor-dey/FrontNox/1.0.0/` to the
   same path inside your fork
3. Open a pull request

---

## Manifest file overview

| File | Purpose |
|------|---------|
| `gor-dey.FrontNox.yaml` | Version manifest (package ID, version, default locale) |
| `gor-dey.FrontNox.installer.yaml` | Installer manifest (URL, SHA256, architecture, install modes) |
| `gor-dey.FrontNox.locale.en-US.yaml` | English locale manifest (name, description, tags, links) |

### Silent install behaviour

The winget installer runs `Install.cmd /S`, which calls:

```powershell
pwsh -ExecutionPolicy Bypass -File scripts\Install.ps1 -All -Lang en
```

The `-All` flag installs every tool without prompting.  
The `-Lang en` flag skips the interactive language selector.

For a Russian-language silent install from the command line (outside winget), run:

```
Install.cmd /S:ru
```

---

## Releasing a new version

1. Update `$NoxVersion` in `src/constants.ps1`
2. Push a new tag (`v1.1.0`, etc.)
3. After the GitHub release is created, repeat Steps 2–4 above with the new
   version number
