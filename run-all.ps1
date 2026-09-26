# Shuttle Management System - All-in-One Launcher for Windows
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   University Shuttle Management System - All-in-One" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$Root = $PSScriptRoot

# 1. Start Backend in new window
Write-Host "`n[1/3] Starting Spring Boot Backend (Port 8080)..." -ForegroundColor Yellow
Start-Process cmd.exe -ArgumentList "/k cd /d `"$Root\backend`" && mvn spring-boot:run"

# Wait for backend health
Write-Host "Waiting for backend health check at http://localhost:8080/actuator/health..." -ForegroundColor Gray
$healthy = $false
$retries = 30
while (-not $healthy -and $retries -gt 0) {
    Start-Sleep -Seconds 3
    try {
        $res = Invoke-RestMethod -Uri "http://localhost:8080/actuator/health" -TimeoutSec 2 -ErrorAction Stop
        if ($res.status -eq "UP") { $healthy = $true }
    } catch {}
    $retries--
    Write-Host "." -NoNewline -ForegroundColor Gray
}

if ($healthy) {
    Write-Host "`n[+] Backend is UP and Healthy!" -ForegroundColor Green
} else {
    Write-Host "`n[!] Warning: Backend is still starting up. Proceeding with frontend launch..." -ForegroundColor Yellow
}

# 2. Start Admin Web in new window
Write-Host "`n[2/3] Starting Admin Web Dashboard (Port 8081)..." -ForegroundColor Yellow
Start-Process cmd.exe -ArgumentList "/k cd /d `"$Root\admin-web`" && flutter run -d chrome --web-port 8081"

# 3. Start Mobile App in new window
Write-Host "`n[3/3] Starting Mobile App on Chrome (Port 4165)..." -ForegroundColor Yellow
Start-Process cmd.exe -ArgumentList "/k cd /d `"$Root\mobile`" && flutter run -d chrome --web-port 4165"

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " All services have been launched in separate terminals:" -ForegroundColor Green
Write-Host "  - Backend API:       http://localhost:8080" -ForegroundColor White
Write-Host "  - Swagger Docs:      http://localhost:8080/swagger-ui.html" -ForegroundColor White
Write-Host "  - Admin Dashboard:   http://localhost:8081" -ForegroundColor White
Write-Host "  - Mobile Web App:    http://localhost:4165" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
