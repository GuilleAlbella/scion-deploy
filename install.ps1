# SCION Windows one-liner installer (PowerShell).
#
# Usage from any PowerShell terminal (Win10/11) with Docker Desktop installed:
#   irm https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/install.ps1 | iex
#
# What it does:
#   1. Verifies Docker Desktop is installed and running.
#   2. Creates %USERPROFILE%\scion as the deploy root.
#   3. Downloads docker-compose.yml + nginx.conf from this repo.
#   4. Prompts for region, GROQ key, public port (with sensible defaults).
#   5. Auto-generates a strong API_KEY.
#   6. Pulls images from GHCR and brings the stack up.
#   7. Prints the URL + admin key on success.
#
# Why Docker Desktop must be pre-installed (vs. the Linux installer
# which auto-installs Docker): Docker Desktop on Windows requires
# accepting an EULA and a system reboot, neither of which a script
# can do unattended. The user runs `Docker Desktop installer.exe`
# once manually, then this script handles everything else.
#
# Idempotent: re-running on an existing install only refreshes the
# compose files and restarts containers — never overwrites .env.

$ErrorActionPreference = "Stop"

# ──── Constants ────
$RepoRaw     = "https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main"
$InstallDir  = Join-Path $env:USERPROFILE "scion"
$DeployFiles = @("docker-compose.yml", "nginx.conf", ".env.example")

# ──── Helpers ────
function Step($msg)  { Write-Host "`n$([char]0x25B6) $msg" -ForegroundColor Blue }
function OK($msg)    { Write-Host "  $([char]0x2713) $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "  $([char]0x2717) $msg" -ForegroundColor Red; exit 1 }

# ──── Pre-flight ────
Step "SCION installer (Windows)"

# 1. Docker present?
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail "Docker not found. Install Docker Desktop from https://www.docker.com/products/docker-desktop/ and re-run."
}
OK "Docker CLI found ($((docker --version) -replace '^Docker version ', '' -replace ',.*$', ''))"

# 2. Compose plugin present?
$composeOk = $false
try {
    $null = docker compose version 2>$null
    if ($LASTEXITCODE -eq 0) { $composeOk = $true }
} catch {}
if (-not $composeOk) { Fail "Docker Compose plugin not available. Update Docker Desktop." }
OK "Docker Compose plugin available"

# 3. Docker daemon running?
$daemonOk = $false
try {
    $null = docker info 2>$null
    if ($LASTEXITCODE -eq 0) { $daemonOk = $true }
} catch {}
if (-not $daemonOk) { Fail "Docker daemon not running. Open Docker Desktop and wait for the whale icon to stabilise, then re-run." }
OK "Docker daemon running"

# ──── Step 1: deploy directory ────
Step "Preparing deploy directory at $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
OK "$InstallDir ready"

# ──── Step 2: download compose + nginx config ────
Step "Downloading deploy files from $RepoRaw"
foreach ($f in $DeployFiles) {
    $dest = Join-Path $InstallDir $f
    Invoke-WebRequest -Uri "$RepoRaw/$f" -OutFile $dest -UseBasicParsing
    OK $f
}

# ──── Step 3: configure ────
$EnvFile = Join-Path $InstallDir ".env"

if (Test-Path $EnvFile) {
    Warn ".env already exists - keeping current values, skipping prompts"
} else {
    Step "Configuration (press Enter to accept defaults)"

    $region = Read-Host "  Region [us-east-1]"
    if ([string]::IsNullOrWhiteSpace($region)) { $region = "us-east-1" }

    $port = Read-Host "  Public port [80]"
    if ([string]::IsNullOrWhiteSpace($port)) { $port = "80" }

    $groqKey = Read-Host "  Groq API key (TAISA - leave empty to configure later)"

    # API_KEY: 32 random bytes, hex-encoded. The user never types this.
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $generatedKey = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""

    $template = Get-Content (Join-Path $InstallDir ".env.example") -Raw
    $template = $template -replace '(?m)^DATA_REGION=.*$',       "DATA_REGION=$region"
    $template = $template -replace '(?m)^SCION_PUBLIC_PORT=.*$', "SCION_PUBLIC_PORT=$port"
    $template = $template -replace '(?m)^API_KEY=.*$',           "API_KEY=$generatedKey"
    if (-not [string]::IsNullOrWhiteSpace($groqKey)) {
        $template = $template -replace '(?m)^GROQ_API_KEY=.*$', "GROQ_API_KEY=$groqKey"
    }

    # Write .env as UTF-8 without BOM so docker compose parses it correctly.
    [System.IO.File]::WriteAllText($EnvFile, $template, (New-Object System.Text.UTF8Encoding $false))
    OK "Wrote $EnvFile"
}

# ──── Step 4: pull + start ────
Step "Pulling images from GHCR"
Push-Location $InstallDir
try {
    docker compose pull
    if ($LASTEXITCODE -ne 0) { Fail "docker compose pull failed" }
} finally { Pop-Location }
OK "Images pulled"

Step "Starting SCION"
Push-Location $InstallDir
try {
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { Fail "docker compose up failed" }
} finally { Pop-Location }

# ──── Step 5: report ────
Start-Sleep -Seconds 3

$envContent = Get-Content $EnvFile
$portFromEnv = ($envContent | Where-Object { $_ -match '^SCION_PUBLIC_PORT=' }) -replace '^SCION_PUBLIC_PORT=', ''
$keyFromEnv  = ($envContent | Where-Object { $_ -match '^API_KEY=' })           -replace '^API_KEY=', ''

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "  SCION is up" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  URL:        http://localhost:$portFromEnv"
Write-Host "  Admin key:  $keyFromEnv"
Write-Host "  Config:     $EnvFile"
Write-Host ""
Write-Host "  Status:   cd $InstallDir; docker compose ps"
Write-Host "  Logs:     cd $InstallDir; docker compose logs -f"
Write-Host "  Update:   irm $RepoRaw/update.ps1 | iex"
Write-Host "  Stop:     cd $InstallDir; docker compose down"
Write-Host ""
Write-Host "  Watchtower will auto-pull new releases every 6h. To force"
Write-Host "  an upgrade now, run the Update command above."
Write-Host ""
