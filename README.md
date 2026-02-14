# FrontNox

[![Русский](https://img.shields.io/badge/lang-Русский-blue)](README.ru.md)

A lightweight toolkit for frontend developers. Pure PowerShell, zero dependencies.

**Two tools, one installer:**

| Tool | Description |
|------|-------------|
| `proj` | Project manager — save, switch, and launch your projects |
| `corsproxy` | Local CORS proxy — bypass CORS restrictions during development |

> 🌐 Bilingual interface: English & Russian

---

## Installation

**Double-click** `Install.cmd` — or run manually:

```powershell
pwsh .\scripts\Install.ps1
# or
powershell .\scripts\Install.ps1
```

The installer will:

1. Ask for a language (`en` / `ru` — switch with <kbd>Tab</kbd>)
2. Let you choose which tools to install
3. Copy scripts to `~/.config/FrontNox/bin/`
4. Update your PowerShell profile

After installation, **restart your terminal**.

### Uninstall

**Double-click** `Uninstall.cmd` — or:

```powershell
pwsh .\scripts\Uninstall.ps1
```

---

## `proj` — Project Manager

Save directories as named projects, then jump to them or launch `npm run dev` in one command.

### Commands

#### `proj list`

Show all registered projects.

```
📋 Registered Projects:
  myapp -> C:\Users\me\projects\myapp
  landing -> C:\Users\me\projects\landing
```

#### `proj add <name>`

Save the current directory as a project.

```powershell
cd C:\Users\me\projects\myapp
proj add myapp
# ✅ Project 'myapp' saved.
```

#### `proj go <name>`

Navigate to a saved project.

```powershell
proj go myapp
# jumps to C:\Users\me\projects\myapp
```

#### `proj run <name>`

Navigate to the project and launch it:

- Auto-detects package manager (`npm`, `yarn`, `pnpm`, `bun`) by lock file
- Runs install if `node_modules/` is missing
- Runs `dev` script (or `start` as fallback)

```powershell
proj run myapp
# 🚀 Launching: C:\Users\me\projects\myapp
# ▶️ Running 'npm run dev'...
```

#### `proj remove <name>`

Remove a project from the list (does not delete files).

```powershell
proj remove myapp
# 🗑️ Project 'myapp' removed.
```

#### `proj rename <old-name> <new-name>`

Rename a project.

```powershell
proj rename myapp frontend
# ✅ Project 'myapp' renamed to 'frontend'.
```

#### `proj -Version` / `corsproxy -Version`

Show the installed version.

> **Tip:** All project names support <kbd>Tab</kbd> completion.

---

## `corsproxy` — CORS Proxy

A local HTTP proxy that adds CORS headers to any response. Point your frontend at `http://localhost:8080/<target-url>` instead of calling the API directly.

### Usage

```powershell
corsproxy                    # Start on port 8080, log errors only
corsproxy -Port 3001         # Custom port
corsproxy -ShowAll           # Log every request
corsproxy -NoLog             # Disable file logging
```

### How it works

Your frontend makes a request to the proxy:

```
GET http://localhost:8080/https://api.example.com/data
```

The proxy forwards the request to `https://api.example.com/data`, adds CORS headers to the response, and returns it to your app. Preflight `OPTIONS` requests are handled automatically.

### Logging

By default, the proxy logs error responses (status 400+) as JSON files in `%TEMP%\NoxProxyLogs\`. Each log file contains:

- Timestamp & duration
- Request method, URL, headers, and body
- Response status, headers, and body

Clickable file links are shown in the terminal for quick access.

| Flag | Behavior |
|------|----------|
| *(default)* | Log errors only (400+) |
| `-ShowAll` | Log every request |
| `-NoLog` | No file logging at all |

---

## Project Structure

```
frontnox/
├── Install.cmd          # Launcher (double-click to install)
├── Uninstall.cmd        # Launcher (double-click to uninstall)
├── scripts/
│   ├── Install.ps1      # Installer script
│   └── Uninstall.ps1    # Uninstaller script
└── src/
    ├── constants.ps1    # Shared paths & config
    ├── proj.ps1         # Project manager
    ├── corsproxy.ps1    # CORS proxy
    └── i18n/
        ├── en.json      # English strings
        └── ru.json      # Russian strings
```

After installation, scripts are stored in:

```
~/.config/FrontNox/
├── bin/                 # Scripts & i18n
├── proj.json            # Saved projects
└── lang.conf            # Language setting
```

---

## Requirements

- **Windows** with **PowerShell 5.1** (built-in) or **PowerShell 7+** (pwsh)
- No external modules, no Node.js, no admin rights

---

## License

MIT
