@echo off
title Shuttle Management System - All In One Runner
echo =====================================================================
echo           University Shuttle Management System
echo           Starting All Services (All-in-One Runner)
echo =====================================================================
echo.

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

echo [1/3] Launching Spring Boot Backend (Port 8080)...
start "Shuttle Backend (Spring Boot)" cmd /k "cd /d \"%SCRIPT_DIR%backend\" && mvn spring-boot:run"

echo Waiting for Backend to initialize...
:wait_backend
timeout /t 4 /nobreak >nul
powershell -Command "try { $r = Invoke-RestMethod -Uri http://localhost:8080/actuator/health -TimeoutSec 2; if ($r.status -eq 'UP') { exit 0 } else { exit 1 } } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo   Waiting for backend to be ready at http://localhost:8080/actuator/health...
    goto wait_backend
)
echo [+] Backend is UP and Healthy!
echo.

echo [2/3] Launching Admin Web Dashboard (Port 8081)...
start "Shuttle Admin Web (Flutter)" cmd /k "cd /d \"%SCRIPT_DIR%admin-web\" && flutter run -d chrome --web-port 8081"

echo [3/3] Launching Student & Driver Mobile App (Port 4165)...
start "Shuttle Mobile App (Flutter)" cmd /k "cd /d \"%SCRIPT_DIR%mobile\" && flutter run -d chrome --web-port 4165"

echo.
echo =====================================================================
echo All services launched!
echo - Backend API & Swagger: http://localhost:8080/swagger-ui.html
echo - Admin Web Dashboard:   http://localhost:8081
echo - Mobile App (Web):      http://localhost:4165
echo =====================================================================
pause
