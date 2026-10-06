# -----------------------------------------------------------------------------
#  Instalador del agente RiceConsole (modo consola del rice) en Windows.
#  Correr UNA vez en PowerShell como ADMINISTRADOR, desde la carpeta donde
#  estan install.ps1 y agent.ps1:
#      Set-ExecutionPolicy -Scope Process Bypass; .\install.ps1
#  Para desinstalar:  .\install.ps1 -Uninstall
#
#  Crea la tarea programada "RiceConsole": corre agent.ps1 al iniciar sesion,
#  con permisos de administrador (para leer el buzon en la particion EFI) y en
#  tu escritorio (para poder mostrar sus ventanas). Sin pedido de Linux en el
#  buzon, el agente termina enseguida sin hacer nada.
# -----------------------------------------------------------------------------
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$Base = Join-Path $env:ProgramData 'RiceConsole'
$Task = 'RiceConsole'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host 'Abri PowerShell como administrador y volve a correrlo.' -ForegroundColor Red; exit 1 }

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $Task -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $Base -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'RiceConsole desinstalado.'
    exit 0
}

New-Item -ItemType Directory -Force -Path $Base | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'agent.ps1') $Base -Force

$user = "$env:USERDOMAIN\$env:USERNAME"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Base\agent.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName $Task -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

# Que el agente encuentre la entrada de Linux para volver
$fw = (bcdedit /enum firmware) -join "`n"
if ($fw -match '(?i)limine') { Write-Host 'Entrada de Linux (Limine) encontrada: OK' -ForegroundColor Green }
else { Write-Host 'OJO: no encontre la entrada de Linux (Limine) en el firmware.' -ForegroundColor Yellow }

Write-Host "Listo: tarea '$Task' instalada en $Base." -ForegroundColor Green
Write-Host 'Falta el inicio de sesion automatico (Autologon).'
