<#
.SYNOPSIS
    Parkir QRIS Display - Service Installer v2
#>

param([switch]$Install,[switch]$Update,[switch]$Uninstall,[switch]$Status,[switch]$Silent,[int]$Port=8001,[string]$FotoDir="Z:\Foto_Masuk",[string]$Outlet="SISTEM PARKIR")

$ErrorActionPreference = "Continue"
$script:PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServiceDir = $script:PSScriptRoot
. (Join-Path $ServiceDir "..\parkir-installer\shared.ps1")

$ServiceName = "QrisDisplay"; $DisplayName = "QRIS Display Server"

function Do-Status { try { $s=Get-Service $ServiceName -ErrorAction Stop; Write-Host "  ${DisplayName}: $($s.Status)" -ForegroundColor $(if($s.Status-eq"Running"){"Green"}else{"Red"}) } catch { Write-Host "  ${DisplayName}: BELUM TERINSTALL" -ForegroundColor DarkGray } }
function Do-Uninstall { wStep "Uninstall ${DisplayName}..."; try { $s=Get-Service $ServiceName -ErrorAction SilentlyContinue; if($s){if($s.Status-eq"Running"){Stop-Service $ServiceName -Force};& $script:NssmExe remove $ServiceName confirm 2>&1|Out-Null;wOK "Service removed"} } catch { wErr "Gagal: $_" } }
function Do-Update { wStep "Update ${DisplayName}..."; if(Test-Path (Join-Path $ServiceDir ".git")){Push-Location $ServiceDir;git pull 2>&1|Out-Null;Pop-Location;wOK "Git pull OK"};$pip=Join-Path $ServiceDir "venv\Scripts\pip.exe";if(Test-Path $pip){& $pip install -r (Join-Path $ServiceDir "requirements.txt") --quiet 2>&1|Out-Null};try{Restart-Service $ServiceName -Force;wOK "Restarted"}catch{Start-Service $ServiceName -ErrorAction SilentlyContinue} }

function Do-Install {
    wStep "Install ${DisplayName}..."
    if (-not $Silent) {
        Write-Host ""; Write-Host "Konfigurasi QRIS Display:" -ForegroundColor Yellow
        $p=Read-Host "  Port [${Port}]"; if($p){$Port=[int]$p}
        $f=Read-Host "  Folder Foto [${FotoDir}]"; if($f){$FotoDir=$f}
        $o=Read-Host "  Nama Outlet [${Outlet}]"; if($o){$Outlet=$o}
    }

    $cfg = Join-Path $ServiceDir "config.yaml"
    $content = @"
server:
  port: ${Port}
  host: 0.0.0.0
foto_dir: ${FotoDir}
outlet_name: ${Outlet}
"@
    [System.IO.File]::WriteAllText($cfg, $content, (New-Object System.Text.UTF8Encoding($false)))
    wOK "config.yaml dibuat"

    $venvPath = Join-Path $ServiceDir "venv"; if(-not(Test-Path $venvPath)){python -m venv $venvPath 2>&1|Out-Null;wOK "venv dibuat"}
    $pip=Join-Path $venvPath "Scripts\pip.exe"; if(Test-Path (Join-Path $ServiceDir "requirements.txt")){wStep "Install deps..."; & $pip install -r (Join-Path $ServiceDir "requirements.txt") --quiet 2>&1|Out-Null;wOK "Dependencies OK"}
    $logDir=Join-Path $ServiceDir "logs"; if(-not(Test-Path $logDir)){New-Item -ItemType Directory -Path $logDir -Force|Out-Null}

    wStep "Register NSSM service..."
    $py=Join-Path $venvPath "Scripts\python.exe"; $main=Join-Path $ServiceDir "src\main.py"
    Register-Service $ServiceName $py "`"$main`"" $DisplayName "QRIS payment display via SSE" (Join-Path $logDir "stdout.log") (Join-Path $logDir "stderr.log") $ServiceDir
    & $script:NssmExe set $ServiceName AppRestartDelay 5000 2>&1|Out-Null
    & $script:NssmExe set $ServiceName AppRotateFiles 1 2>&1|Out-Null
    & $script:NssmExe set $ServiceName AppRotateSeconds 86400 2>&1|Out-Null
    & $script:NssmExe set $ServiceName AppRotateBytes 10485760 2>&1|Out-Null
    wOK "Service registered"

    if(Start-ServiceSafe $ServiceName){wOK "RUNNING - http://localhost:${Port}"}else{wWarn "Cek: Get-Service ${ServiceName}"}
}

if($Uninstall){Do-Uninstall}elseif($Update){Do-Update}elseif($Status){Do-Status|Out-Null}else{Do-Install}
