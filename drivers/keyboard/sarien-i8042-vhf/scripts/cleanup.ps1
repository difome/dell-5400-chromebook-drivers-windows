#Requires -RunAsAdministrator
# ============================================================
#  SarienI8042 - cleanup
#  Removes the root device, stale (ghost) keyboard entries and,
#  optionally, the driver package itself.
# ============================================================

[CmdletBinding()]
param(
    [switch]$RemoveDriverPackage
)

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

function Write-Step([string]$text) {
    Write-Host ""
    Write-Host "=== $text ===" -ForegroundColor Cyan
}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  SarienI8042 - cleanup" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

Write-Step "Keyboard devices before"
Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue |
    Select-Object Status, Present, FriendlyName, InstanceId |
    Format-Table -AutoSize | Out-String | Write-Host

# ---------- 1. Root device ----------
Write-Step "Removing root device Root\SarienI8042Vhf"
$root = Get-PnpDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'ROOT\SARIENI8042VHF*' }
if ($root) {
    if (Test-Path '.\devcon.exe') {
        & .\devcon.exe remove 'Root\SarienI8042Vhf' 2>&1 | ForEach-Object { "  $_" }
    } else {
        foreach ($device in $root) {
            pnputil /remove-device $device.InstanceId 2>&1 | ForEach-Object { "  $_" }
        }
    }
} else {
    Write-Host "  root device not present"
}

# ---------- 2. Ghost keyboards ----------
Write-Step "Removing non-present keyboard devices"
$ghosts = Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue |
    Where-Object { $_.Present -ne $true -or $_.Status -eq 'Unknown' }
if ($ghosts) {
    foreach ($device in $ghosts) {
        Write-Host "  $($device.InstanceId)"
        pnputil /remove-device $device.InstanceId 2>&1 | ForEach-Object { "    $_" }
    }
} else {
    Write-Host "  none"
}

# ---------- 3. Driver package ----------
if ($RemoveDriverPackage) {
    Write-Step "Removing the driver package from the driver store"
    $published = @()
    try {
        $published = Get-WindowsDriver -Online -ErrorAction Stop |
            Where-Object { $_.OriginalFileName -match 'sarieni8042' } |
            Select-Object -ExpandProperty Driver
    } catch {
        Write-Host "  Get-WindowsDriver unavailable, falling back to pnputil"
    }
    if (-not $published) {
        $blocks = (pnputil /enum-drivers | Out-String) -split '(?m)^Published Name:\s*'
        foreach ($block in $blocks) {
            if ($block -match '(?im)^\s*sarieni8042\.inf\s*$') {
                $published += ($block -split "`n")[0].Trim()
            }
        }
    }
    if ($published) {
        foreach ($package in $published) {
            if ($package -match '^oem\d+\.inf$') {
                Write-Host "  deleting $package"
                pnputil /delete-driver $package /uninstall /force 2>&1 | ForEach-Object { "    $_" }
            }
        }
    } else {
        Write-Host "  no matching package in the driver store"
    }
} else {
    Write-Host ""
    Write-Host "Driver package kept. Re-run with -RemoveDriverPackage to delete it as well." -ForegroundColor DarkGray
}

Write-Step "Keyboard devices after"
Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue |
    Select-Object Status, Present, FriendlyName, InstanceId |
    Format-Table -AutoSize | Out-String | Write-Host

Write-Host "Done. Reboot to finish." -ForegroundColor Green
