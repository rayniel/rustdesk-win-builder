$ErrorActionPreference = "Stop"

$installer = Get-ChildItem -Path rustdesk -Filter "rustdesk-*-install.exe" | Select-Object -First 1
if (-not $installer) {
    throw "Installer artifact not found under rustdesk root."
}

if ([string]::IsNullOrWhiteSpace($env:RUSTDESK_CONFIG)) {
    throw "RUSTDESK_CONFIG is empty."
}

$source = if ([string]::IsNullOrWhiteSpace($env:RUSTDESK_CONFIG_SOURCE)) {
    "unknown"
} else {
    $env:RUSTDESK_CONFIG_SOURCE
}

New-Item -ItemType Directory -Force -Path dist | Out-Null

$psScript = @"
$ErrorActionPreference = 'Stop'

$installer = Join-Path $PSScriptRoot '$($installer.Name)'
$config = @'
$env:RUSTDESK_CONFIG
'@

if (-not (Test-Path $installer)) {
    throw "Installer not found: $installer"
}

Start-Process -FilePath $installer -ArgumentList '--silent-install' -Wait

$rustdeskExe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
if (-not (Test-Path $rustdeskExe)) {
    throw "Installed rustdesk.exe not found: $rustdeskExe"
}

& $rustdeskExe --config $config
Write-Host 'RustDesk self-hosted config imported.'
"@

$batScript = @"
@echo off
setlocal
set "INSTALLER=%~dp0$($installer.Name)"
set "RUSTDESK_EXE=%ProgramFiles%\RustDesk\rustdesk.exe"

if not exist "%INSTALLER%" (
  echo Installer not found: %INSTALLER%
  exit /b 1
)

start /wait "" "%INSTALLER%" --silent-install

if not exist "%RUSTDESK_EXE%" (
  echo Installed rustdesk.exe not found: %RUSTDESK_EXE%
  exit /b 1
)

"%RUSTDESK_EXE%" --config "$env:RUSTDESK_CONFIG"
echo RustDesk self-hosted config imported.
"@

Set-Content -Path "dist\install-selfhosted.ps1" -Value $psScript -Encoding ASCII
Set-Content -Path "dist\install-selfhosted.bat" -Value $batScript -Encoding ASCII
Set-Content -Path "dist\selfhost-config-source.txt" -Value "Config source: $source" -Encoding ASCII