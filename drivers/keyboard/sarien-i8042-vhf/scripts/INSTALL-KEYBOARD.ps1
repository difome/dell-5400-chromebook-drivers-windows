#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $here

Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' SARIEN KEYBOARD DRIVER INSTALLER' -ForegroundColor Cyan
$modeFile = Join-Path $here 'TOP-ROW-MODE.txt'
if (Test-Path -LiteralPath $modeFile) {
    Write-Host (' ' + (Get-Content -LiteralPath $modeFile -Raw).Trim()) -ForegroundColor Cyan
}
Write-Host '============================================================' -ForegroundColor Cyan

$inf = Join-Path $here 'SarienI8042.inf'
$sys = Join-Path $here 'SarienI8042.sys'
$cer = Join-Path $here 'SarienI8042-Test.cer'
$devcon = Join-Path $here 'devcon.exe'
foreach ($file in @($inf,$sys,$cer,$devcon)) {
    if (!(Test-Path -LiteralPath $file)) {
        Write-Host "ERROR: missing $file" -ForegroundColor Red
        Write-Host 'Extract the entire ZIP and run this script from that folder.' -ForegroundColor Yellow
        pause
        exit 1
    }
}

Write-Host '[1/5] Enabling Windows Test Mode...' -ForegroundColor Green
& bcdedit.exe /set testsigning on | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host 'ERROR: TESTSIGNING could not be enabled. Check Secure Boot.' -ForegroundColor Red
    pause
    exit 2
}
$startOptions = Get-ItemPropertyValue -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name SystemStartOptions -ErrorAction SilentlyContinue
if ($startOptions -notmatch '(?i)TESTSIGNING') {
    Write-Host 'Test Mode becomes active only after a reboot.' -ForegroundColor Yellow
    Write-Host 'Reboot and run this same script again.' -ForegroundColor Yellow
    $answer = Read-Host 'Reboot now? (y/n)'
    if ($answer -eq 'y') { Restart-Computer }
    exit 0
}

Write-Host '[2/5] Importing the test certificate...' -ForegroundColor Green
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null

Write-Host '[3/5] Looking for the existing Sarien keyboard device...' -ForegroundColor Green
$oldDevices = Get-PnpDevice -PresentOnly:$false -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'ROOT\SARIENI8042VHF*' }
if ($oldDevices) {
    Write-Host 'Existing device found; it will be updated in place.' -ForegroundColor Green
} else {
    Write-Host 'No existing device found; a new root device will be created.' -ForegroundColor Yellow
}

Write-Host '[4/5] Installing the selected build...' -ForegroundColor Green
if ($oldDevices) {
    & $devcon update $inf 'Root\SarienI8042Vhf' | Out-Host
} else {
    & $devcon install $inf 'Root\SarienI8042Vhf' | Out-Host
}
if ($LASTEXITCODE -notin 0,1) {
    Write-Host "ERROR: DevCon exit code $LASTEXITCODE" -ForegroundColor Red
    pause
    exit 3
}

Write-Host '[5/5] Checking the device...' -ForegroundColor Green
Start-Sleep -Seconds 2
$installed = Get-PnpDevice -PresentOnly:$false -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'ROOT\SARIENI8042VHF*' } | Select-Object -First 1
if ($installed) {
    Write-Host "Device:  $($installed.InstanceId)" -ForegroundColor Green
    Write-Host "Status:  $($installed.Status)" -ForegroundColor Green
    Write-Host "Problem: $($installed.Problem)" -ForegroundColor Green
} else {
    Write-Host 'ERROR: the root keyboard device was not created.' -ForegroundColor Red
}

Write-Host 'Reboot Windows and test the selected top-row mode.' -ForegroundColor Yellow
Write-Host 'To change mode, extract the other ZIP and run its INSTALL-KEYBOARD.ps1.' -ForegroundColor Cyan
pause
