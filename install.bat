@echo off
REM ============================================================
REM install.bat — Install QrisDisplay as a Windows NSSM service
REM ============================================================
setlocal enabledelayedexpansion

set SERVICE_NAME=QrisDisplay
set DISPLAY_NAME=QRIS Display Server
set PORT=8001
set ROOT_DIR=%~dp0
set VENV_DIR=%ROOT_DIR%venv
set PYTHON_EXE=%VENV_DIR%\Scripts\python.exe
set MAIN_SCRIPT=%ROOT_DIR%src\main.py

echo.
echo ========================================
echo  %DISPLAY_NAME% — NSSM Installer
echo ========================================
echo.

REM ---- Check if NSSM is available ----
where nssm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] NSSM not found in PATH.
    echo     Download from: https://nssm.cc/download
    echo     Place nssm.exe in %%PATH%% or this folder.
    pause
    exit /b 1
)

REM ---- Check if service already exists ----
nssm status %SERVICE_NAME% >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [*] Service '%SERVICE_NAME%' already exists.
    echo     Stopping and removing old service...
    nssm stop %SERVICE_NAME%
    nssm remove %SERVICE_NAME% confirm
)

REM ---- Create virtualenv if missing ----
if not exist "%VENV_DIR%" (
    echo [*] Creating virtual environment...
    python -m venv "%VENV_DIR%"
    if !ERRORLEVEL! NEQ 0 (
        echo [!] Failed to create venv. Make sure Python 3.9+ is installed.
        pause
        exit /b 1
    )
)

REM ---- Install dependencies ----
echo [*] Installing Python dependencies...
"%PYTHON_EXE%" -m pip install --upgrade pip -q
"%PYTHON_EXE%" -m pip install -r "%ROOT_DIR%requirements.txt" -q
if %ERRORLEVEL% NEQ 0 (
    echo [!] pip install failed.
    pause
    exit /b 1
)

REM ---- Install service ----
echo [*] Installing NSSM service '%SERVICE_NAME%'...
nssm install %SERVICE_NAME% "%PYTHON_EXE%" "%MAIN_SCRIPT%"

REM ---- Set working directory ----
nssm set %SERVICE_NAME% AppDirectory "%ROOT_DIR%"

REM ---- Auto-restart on crash ----
nssm set %SERVICE_NAME% AppRestartDelay 5000

REM ---- Logging ----
nssm set %SERVICE_NAME% AppStdout "%ROOT_DIR%logs\stdout.log"
nssm set %SERVICE_NAME% AppStderr "%ROOT_DIR%logs\stderr.log"
nssm set %SERVICE_NAME% AppRotateFiles 1
nssm set %SERVICE_NAME% AppRotateOnline 1
nssm set %SERVICE_NAME% AppRotateSeconds 86400
nssm set %SERVICE_NAME% AppRotateBytes 10485760

REM ---- Display name ----
nssm set %SERVICE_NAME% DisplayName "%DISPLAY_NAME%"

REM ---- Start service ----
echo [*] Starting service...
nssm start %SERVICE_NAME%
if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Service '%SERVICE_NAME%' installed and started.
    echo           Listening on port %PORT%
    echo.
) else (
    echo [!] Service installed but failed to start.
    echo     Check logs in %ROOT_DIR%logs\
)

echo.
pause
