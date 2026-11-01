#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$PackageDirectory = $PSScriptRoot,
    [switch]$AllowExistingI8042
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$inf = Join-Path $package 'SarienI8042.inf'
$sys = Join-Path $package 'SarienI8042.sys'
$cer = Join-Path $package 'SarienI8042-Test.cer'
if (!(Test-Path -LiteralPath $inf) -or !(Test-Path -LiteralPath $sys) -or !(Test-Path -LiteralPath $cer)) {
    throw "Package must contain SarienI8042.inf, SarienI8042.sys, and SarienI8042-Test.cer: $package"
}

# Secure Boot must not abort the installation on firmware that does not implement
# it at all (Chromebooks booting through TianoCore/RW_LEGACY). In that case
# Confirm-SecureBootUEFI throws instead of returning $false, which previously
# killed the whole script with a generic error.
$secureBoot = $false
try {
    $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
} catch {
    Write-Host 'Secure Boot: not supported by firmware (expected on Chromebook/TianoCore).'
    $secureBoot = $false
}
if ($secureBoot) {
    Write-Warning 'Secure Boot is enabled. A test-signed kernel driver cannot load until Secure Boot is disabled in firmware.'
    Write-Warning 'Continuing: the driver will be installed but will stay in Code 52 until Secure Boot is turned off.'
}

$startOptions = Get-ItemPropertyValue -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control' `
    -Name SystemStartOptions -ErrorAction SilentlyContinue
if ($startOptions -notmatch '(?i)TESTSIGNING') {
    Write-Host 'Test signing is off. Enabling it: bcdedit /set testsigning on'
    & bcdedit /set testsigning on | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not run "bcdedit /set testsigning on". Start PowerShell as Administrator.'
    }
    Write-Host ''
    Write-Host 'Test signing enabled. A reboot is required.' -ForegroundColor Yellow
    Write-Host 'Run this script again after the reboot to continue the installation.' -ForegroundColor Yellow
    exit 0
}
Write-Host 'Test signing is active.'

$signature = Get-AuthenticodeSignature -LiteralPath $sys
$certificate = Get-PfxCertificate -FilePath $cer
if (!$signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $certificate.Thumbprint) {
    throw 'The included test certificate does not match the driver signature.'
}

$existing = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object InstanceId -Like 'ROOT\SARIENI8042VHF*'
if ($existing) {
    throw 'SarienI8042Vhf is already installed. Run uninstall-test.ps1 first.'
}

$firmwareKeyboard = @(Get-PnpDevice -PresentOnly:$false -ErrorAction SilentlyContinue |
    Where-Object InstanceId -Match 'PNP0303|PNP030B|GOOG000A')
$firmwareOwners = @($firmwareKeyboard | ForEach-Object {
    $service = Get-PnpDeviceProperty -InstanceId $_.InstanceId `
        -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue
    if ($service.Data) {
        [pscustomobject]@{
            Status       = $_.Status
            FriendlyName = $_.FriendlyName
            InstanceId   = $_.InstanceId
            Service      = [string]$service.Data
            Problem      = $_.Problem
        }
    }
})
$i8042Driver = Get-CimInstance Win32_SystemDriver -Filter "Name='i8042prt'" `
    -ErrorAction SilentlyContinue
$i8042Running = $i8042Driver -and $i8042Driver.State -eq 'Running'

if (($firmwareOwners.Count -gt 0 -or $i8042Running) -and !$AllowExistingI8042) {
    if ($firmwareOwners.Count -gt 0) {
        $firmwareOwners | Format-Table Status,FriendlyName,InstanceId,Service,Problem -AutoSize
    }
    if ($i8042Running) {
        Write-Host "i8042prt state: $($i8042Driver.State); start mode: $($i8042Driver.StartMode)"
    }
    throw 'A driver already owns, or may be polling, the i8042 controller. Do not run two port consumers. Diagnose the in-box stack first. Use -AllowExistingI8042 only during kernel-debugged development.'
}

if ($firmwareKeyboard.Count -gt 0 -and $firmwareOwners.Count -eq 0) {
    Write-Warning 'Firmware advertises the keyboard, but no function-driver service is attached to that device node. Continuing with the root-enumerated diagnostic prototype.'
}
if ($AllowExistingI8042 -and ($firmwareOwners.Count -gt 0 -or $i8042Running)) {
    Write-Warning 'Safety override active: another i8042 driver may access ports 0x60/0x64 concurrently. Keep kernel debugging and an external USB keyboard available.'
}

foreach ($store in 'Root','TrustedPublisher') {
    if (!(Test-Path -LiteralPath "Cert:\LocalMachine\$store\$($certificate.Thumbprint)")) {
        Import-Certificate -FilePath $cer -CertStoreLocation "Cert:\LocalMachine\$store" | Out-Null
    }
}

$devcon = Join-Path $package 'devcon.exe'
if (!(Test-Path -LiteralPath $devcon)) {
    $devcon = Get-ChildItem -LiteralPath 'C:\Program Files (x86)\Windows Kits\10\Tools' -Filter devcon.exe -Recurse -ErrorAction SilentlyContinue |
        Where-Object FullName -Match '\\x64\\' | Select-Object -First 1 -ExpandProperty FullName
}
if (!$devcon) { throw 'devcon.exe (x64) was not found. Install WDK tools.' }

Write-Host 'Creating restore point information and installing test device...'
& $devcon install $inf 'Root\SarienI8042Vhf'
if ($LASTEXITCODE -notin 0,1) { throw "devcon failed with exit code $LASTEXITCODE" }

Write-Host 'Installed. Keep an external USB keyboard connected during testing.'
Write-Host 'If Windows reports signature error 52, enable TESTSIGNING and reboot before retrying: bcdedit /set testsigning on'
Write-Host 'Kernel log prefix: SarienI8042 (view with WinDbg or DbgView kernel capture).'

