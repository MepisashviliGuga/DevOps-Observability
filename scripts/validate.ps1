# Post-deployment validation for Windows (PowerShell).
$AppUrl        = if ($env:APP_URL)        { $env:APP_URL }        else { "http://localhost:3000" }
$GrafanaUrl    = if ($env:GRAFANA_URL)    { $env:GRAFANA_URL }    else { "http://localhost:3001" }
$PrometheusUrl = if ($env:PROMETHEUS_URL) { $env:PROMETHEUS_URL } else { "http://localhost:9090" }
$LokiUrl       = if ($env:LOKI_URL)       { $env:LOKI_URL }       else { "http://localhost:3100" }

$pass = 0
$fail = 0

function Check-Endpoint {
    param([string]$Name, [string]$Url, [string]$Pattern = "")
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $body = $response.Content
        if ($Pattern -ne "" -and $body -notmatch $Pattern) {
            Write-Host "  FAIL  $Name" -ForegroundColor Red
            $script:fail++
        } else {
            Write-Host "  PASS  $Name" -ForegroundColor Green
            $script:pass++
        }
    } catch {
        Write-Host "  FAIL  $Name  ($Url)" -ForegroundColor Red
        $script:fail++
    }
}

Write-Host "=== Deployment Validation ===" -ForegroundColor Cyan
Check-Endpoint "App /health"     "$AppUrl/health"            '"status":"healthy"'
Check-Endpoint "App /"           "$AppUrl/"                  '"status":"ok"'
Check-Endpoint "App /metrics"    "$AppUrl/metrics"           'app_requests_total'
Check-Endpoint "Prometheus"      "$PrometheusUrl/-/healthy"  'Prometheus'
Check-Endpoint "Loki /ready"     "$LokiUrl/ready"            ''
Check-Endpoint "Grafana /health" "$GrafanaUrl/api/health"    '"database"'
Write-Host ""

if ($fail -gt 0) {
    Write-Host "Result: $pass passed, $fail FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Result: all $pass checks passed." -ForegroundColor Green
}
