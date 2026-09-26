@echo off
title Stop Shuttle Services
echo =====================================================================
echo Stopping running Flutter and Spring Boot processes...
echo =====================================================================
taskkill /F /IM "java.exe" /FI "WINDOWTITLE eq Shuttle Backend*" 2>nul
taskkill /F /IM "dart.exe" 2>nul
echo Done! All services stopped.
pause
