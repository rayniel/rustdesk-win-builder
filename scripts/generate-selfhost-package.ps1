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

$makeNsis = Get-Command makensis.exe -ErrorAction SilentlyContinue
if (-not $makeNsis) {
    throw "NSIS compiler (makensis.exe) was not found."
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

$setupName = $installer.Name -replace '-install\.exe$', '-selfhosted-setup.exe'
if ($setupName -eq $installer.Name) {
    throw "Unexpected RustDesk installer filename: $($installer.Name)"
}

$nsiScript = @'
Unicode true
Name "RustDesk Self-Hosted Setup"
OutFile "dist\__SETUP_NAME__"
RequestExecutionLevel admin

Section
  SetOutPath "$TEMP\RustDeskSelfHostedSetup"
  File "/oname=rustdesk-installer.exe" "rustdesk\__INSTALLER_NAME__"

  ExecWait '"$TEMP\RustDeskSelfHostedSetup\rustdesk-installer.exe" --silent-install' $0
  StrCmp $0 0 import_config install_failed

  import_config:
  IfFileExists "$PROGRAMFILES\RustDesk\rustdesk.exe" 0 client_missing
  ExecWait '"$PROGRAMFILES\RustDesk\rustdesk.exe" --config "__RUSTDESK_CONFIG__"' $0
  StrCmp $0 0 cleanup config_failed

  cleanup:
  Delete "$TEMP\RustDeskSelfHostedSetup\rustdesk-installer.exe"
  RMDir "$TEMP\RustDeskSelfHostedSetup"
  Goto done

  install_failed:
  MessageBox MB_ICONSTOP|MB_OK "RustDesk installation failed (exit code: $0)."
  Abort

  client_missing:
  MessageBox MB_ICONSTOP|MB_OK "RustDesk was installed, but rustdesk.exe was not found."
  Abort

  config_failed:
  MessageBox MB_ICONSTOP|MB_OK "RustDesk was installed, but the self-hosted configuration could not be imported (exit code: $0)."
  Abort

  done:
SectionEnd
'@

$nsiPath = "selfhosted-setup.nsi"
$nsiScript = $nsiScript.
    Replace('__SETUP_NAME__', $setupName).
    Replace('__INSTALLER_NAME__', $installer.Name).
    Replace('__RUSTDESK_CONFIG__', $env:RUSTDESK_CONFIG)
Set-Content -Path $nsiPath -Value $nsiScript -Encoding ASCII

try {
    & $makeNsis.Source /V2 $nsiPath
    if ($LASTEXITCODE -ne 0) {
        throw "NSIS compilation failed with exit code $LASTEXITCODE."
    }
} finally {
    Remove-Item -Path $nsiPath -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path "dist\$setupName" -PathType Leaf)) {
    throw "Expected self-hosted setup executable was not created: dist\$setupName"
}