# SCION Windows uninstaller (PowerShell).
#
#   irm https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/uninstall.ps1 | iex

$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:USERPROFILE "scion"

if (-not (Test-Path $InstallDir)) {
    Write-Host "Nothing to uninstall - $InstallDir doesn't exist."
    exit 0
}

Write-Host ">> Stopping SCION containers"
Push-Location $InstallDir
try {
    docker compose down
} finally { Pop-Location }

$wipe = Read-Host "  Also delete the data volume (SQLite DB will be lost)? [y/N]"
if ($wipe -match '^[Yy]$') {
    Push-Location $InstallDir
    try {
        docker compose down -v
        Write-Host "  OK Volume removed"
    } finally { Pop-Location }
}

$wipeDir = Read-Host "  Remove $InstallDir (config + .env)? [y/N]"
if ($wipeDir -match '^[Yy]$') {
    Remove-Item -Recurse -Force $InstallDir
    Write-Host "  OK $InstallDir removed"
}

Write-Host "OK SCION uninstalled"
