# Single-command environment setup for Windows (PowerShell).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
Set-Location $ProjectDir

Write-Host "=== DevOps Observability Stack — Setup ===" -ForegroundColor Cyan
Write-Host ""

# ── Prerequisites check ────────────────────────────────────────────────────
Write-Host "Checking prerequisites..."
try {
    $null = Get-Command docker -ErrorAction Stop
    Write-Host "  OK: docker found" -ForegroundColor Green
} catch {
    Write-Host "ERROR: 'docker' not found. Install Docker Desktop and retry." -ForegroundColor Red
    exit 1
}

try {
    docker info 2>&1 | Out-Null
    Write-Host "  OK: Docker daemon is running" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker daemon is not running. Start Docker Desktop and retry." -ForegroundColor Red
    exit 1
}
Write-Host ""

# ── Environment file ───────────────────────────────────────────────────────
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example." -ForegroundColor Yellow
    Write-Host "NOTICE: Default admin password is 'admin'. Change GF_SECURITY_ADMIN_PASSWORD for production." -ForegroundColor Yellow
} else {
    Write-Host ".env already exists — skipping." -ForegroundColor Green
}
Write-Host ""

# ── Build & start ──────────────────────────────────────────────────────────
Write-Host "Building and starting the stack (this may take a minute on first run)..."
docker compose up --build -d
Write-Host ""

# ── Wait for health ────────────────────────────────────────────────────────
Write-Host -NoNewline "Waiting for app to become healthy"
$timeout = 90
$elapsed = 0
while ($elapsed -lt $timeout) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) { break }
    } catch {}
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 3
    $elapsed += 3
}
Write-Host " ready." -ForegroundColor Green

Write-Host -NoNewline "Waiting for Prometheus"
$elapsed = 0
while ($elapsed -lt 60) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9090/-/healthy" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) { break }
    } catch {}
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 3
    $elapsed += 3
}
Write-Host " ready." -ForegroundColor Green
Write-Host ""

# ── Validate ───────────────────────────────────────────────────────────────
& "$ScriptDir\validate.ps1"

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  App:        http://localhost:3000"
Write-Host "  Grafana:    http://localhost:3001  (admin / admin)"
Write-Host "  Prometheus: http://localhost:9090"
Write-Host "  Loki:       http://localhost:3100"
Write-Host ""
Write-Host "To stop:       docker compose down"
Write-Host "To stop+clean: docker compose down -v"
