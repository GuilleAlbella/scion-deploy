# SCION Windows manual updater (PowerShell).
#
#   irm https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/update.ps1 | iex

$ErrorActionPreference = "Stop"

$RepoRaw    = "https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main"
$InstallDir = Join-Path $env:USERPROFILE "scion"

if (-not (Test-Path $InstallDir)) {
    Write-Host "X $InstallDir not found. Run install.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host ">> Refreshing compose + nginx config from $RepoRaw"
Invoke-WebRequest -Uri "$RepoRaw/docker-compose.yml" -OutFile (Join-Path $InstallDir "docker-compose.yml") -UseBasicParsing
Invoke-WebRequest -Uri "$RepoRaw/nginx.conf"         -OutFile (Join-Path $InstallDir "nginx.conf")         -UseBasicParsing

Write-Host ">> Pulling latest images"
Push-Location $InstallDir
try {
    docker compose pull
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host ">> Recreating containers"
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host "OK SCION updated. Current containers:"
    docker compose ps
} finally { Pop-Location }
