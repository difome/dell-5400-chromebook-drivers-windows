#Requires -RunAsAdministrator
# ============================================================
#  SarienI8042 - installation manager
#  Dell Latitude 5400 Chromebook (Sarien), Windows 10 x64
# ============================================================

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-BcdFlag([string]$name) {
    $line = bcdedit /enum '{current}' 2>$null | Select-String -Pattern $name
    if (-not $line) { return $false }
    return [bool]($line -match '(?i)\byes\b')
}

function Get-State {
    $dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -like 'ROOT\SARIENI8042VHF*' }
    $sb = 'n/a'
    try { $sb = if (Confirm-SecureBootUEFI -ErrorAction Stop) { 'ON' } else { 'off' } } catch { $sb = 'not supported (normal)' }
    [pscustomobject]@{
        TestSigning = Get-BcdFlag 'testsigning'
        SecureBoot  = $sb
        Driver      = if ($dev) { $dev.Status } else { 'not installed' }
    }
}

function Show-Header {
    Clear-Host
    $s = Get-State
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  SarienI8042 - manager" -ForegroundColor Cyan
    Write-Host "  Dell Latitude 5400 Chromebook (Sarien)" -ForegroundColor DarkGray
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ("  Test signing : {0}" -f $(if ($s.TestSigning) { 'ON' } else { 'off' })) -ForegroundColor $(if ($s.TestSigning) { 'Green' } else { 'DarkGray' })
    Write-Host ("  Secure Boot  : {0}" -f $s.SecureBoot) -ForegroundColor DarkGray
    Write-Host ("  Driver       : {0}" -f $s.Driver) -ForegroundColor $(if ($s.Driver -eq 'OK') { 'Green' } else { 'Yellow' })
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) Install driver" -ForegroundColor White
    Write-Host "  2) Enable test signing" -ForegroundColor White
    Write-Host "  3) Import certificate" -ForegroundColor White
    Write-Host "  4) Diagnostics" -ForegroundColor White
    Write-Host "  5) Uninstall driver" -ForegroundColor White
    Write-Host "  6) Disable test signing" -ForegroundColor White
    Write-Host "  7) Reboot" -ForegroundColor White
    Write-Host "  8) Clean up devices (keep driver)" -ForegroundColor White
    Write-Host "  9) Remove everything" -ForegroundColor White
    Write-Host "  0) Exit" -ForegroundColor White
    Write-Host ""
}

if (-not (Test-Admin)) {
    Write-Host "Administrator rights required. Run start-manager.cmd" -ForegroundColor Red
    Read-Host "Enter"
    exit 1
}

while ($true) {
    Show-Header
    $choice = Read-Host "Select an option"
    switch ($choice) {
        '1' {
            Write-Host ""
            if (Test-Path '.\install-test.ps1') { & '.\install-test.ps1' } else { Write-Host "install-test.ps1 not found" -ForegroundColor Red }
        }
        '2' {
            bcdedit /set testsigning on | Out-Null
            Write-Host "Test signing enabled. Reboot required." -ForegroundColor Yellow
        }
        '3' {
            if (Test-Path '.\SarienI8042-Test.cer') {
                certutil -addstore -f Root '.\SarienI8042-Test.cer' | Out-Null
                certutil -addstore -f TrustedPublisher '.\SarienI8042-Test.cer' | Out-Null
                Write-Host "Certificate added to Root and TrustedPublisher." -ForegroundColor Green
            } else { Write-Host "SarienI8042-Test.cer not found" -ForegroundColor Red }
        }
        '4' {
            Write-Host ""
            Get-State | Format-List | Out-String | Write-Host
            if (Test-Path '.\collect-diagnostics.ps1') { & '.\collect-diagnostics.ps1' }
            $log = Get-ChildItem -Filter '*diag*.txt' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($log) { Write-Host "Report: $($log.FullName)" -ForegroundColor Green }
        }
        '5' {
            if (Test-Path '.\uninstall-test.ps1') { & '.\uninstall-test.ps1' } else { Write-Host "uninstall-test.ps1 not found" -ForegroundColor Red }
        }
        '6' {
            bcdedit /set testsigning off | Out-Null
            Write-Host "Test signing disabled. Reboot required." -ForegroundColor Yellow
        }
        '7' {
            if ((Read-Host "Reboot now? (y/n)") -eq 'y') { Restart-Computer -Force }
        }
        '8' {
            if (Test-Path '.\cleanup.ps1') { & '.\cleanup.ps1' } else { Write-Host "cleanup.ps1 not found" -ForegroundColor Red }
        }
        '9' {
            if (Test-Path '.\cleanup.ps1') {
                if ((Read-Host "Remove the driver package too? (y/n)") -eq 'y') {
                    & '.\cleanup.ps1' -RemoveDriverPackage
                } else {
                    & '.\cleanup.ps1'
                }
            } else { Write-Host "cleanup.ps1 not found" -ForegroundColor Red }
        }
        '0' { exit 0 }
        default { Write-Host "Unknown option" -ForegroundColor Red }
    }
    Write-Host ""
    Read-Host "Enter - back to menu"
}
