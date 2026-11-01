#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\diagnostics'))

$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$destination = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) "sarien-$stamp"
New-Item -ItemType Directory -Path $destination -Force | Out-Null

function Save-Text([string]$Name, [scriptblock]$Action) {
    $path = Join-Path $destination $Name
    try { & $Action 2>&1 | Out-String -Width 4096 | Set-Content -LiteralPath $path -Encoding utf8 }
    catch { $_ | Out-String | Set-Content -LiteralPath $path -Encoding utf8 }
}

Save-Text '00-system.txt' {
    Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber,
        OsArchitecture,CsManufacturer,CsModel,BiosManufacturer,BiosName,BiosVersion
    Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
    bcdedit /enum '{current}'
}

Save-Text '01-target-devices.txt' {
    $pattern = 'PNP0303|PNP030B|GOOG000A|GOOG000[BCDEF]|GOOG9999|ELAN0000|BOOT0000|INT34BB'
    Get-PnpDevice -PresentOnly:$false | Where-Object InstanceId -Match $pattern |
        Sort-Object InstanceId | Format-List Status,Class,FriendlyName,InstanceId,Problem
}

Save-Text '02-target-properties.txt' {
    $pattern = 'PNP0303|PNP030B|GOOG000A|GOOG000[BCDEF]|GOOG9999|ELAN0000|BOOT0000|INT34BB'
    Get-PnpDevice -PresentOnly:$false | Where-Object InstanceId -Match $pattern | ForEach-Object {
        "===== $($_.InstanceId) ====="
        Get-PnpDeviceProperty -InstanceId $_.InstanceId |
            Sort-Object KeyName | Format-Table KeyName,Type,Data -Wrap -AutoSize
    }
}

Save-Text '03-all-problem-devices.txt' { pnputil /enum-devices /problem /deviceids }
Save-Text '04-all-drivers.txt' { pnputil /enum-drivers /files }
Save-Text '05-i8042-services.txt' {
    reg query 'HKLM\SYSTEM\CurrentControlSet\Services\i8042prt' /s
    reg query 'HKLM\SYSTEM\CurrentControlSet\Services\kbdclass' /s
    sc.exe qc i8042prt
    sc.exe query i8042prt
    driverquery /v /fo list | Select-String -Pattern 'i8042|kbdclass|cros|wilco|elan' -Context 3,8
    sc.exe qc vhf
    sc.exe query vhf
}

Save-Text '06-resources.txt' {
    Get-CimInstance Win32_PnPAllocatedResource | ForEach-Object {
        $dependent = $_.Dependent.DeviceID
        if (!$dependent) { $dependent = [string]$_.Dependent }
        if ($dependent -match 'PNP0303|GOOG000A|ELAN0000|INT34BB') { $_ | Format-List * }
    }
}

Save-Text '07-power.txt' {
    powercfg /a
    powercfg /requests
    powercfg /lastwake
    powercfg /waketimers
}

Save-Text '08-events.txt' {
    $start = (Get-Date).AddDays(-7)
    Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=$start} -ErrorAction SilentlyContinue |
        Where-Object { $_.ProviderName -match 'Kernel-PnP|ACPI|Kernel-Power|DriverFrameworks' -or
                       $_.Message -match 'PNP0303|GOOG000A|GOOG000[BCDEF]|ELAN0000|i8042' } |
        Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message | Format-List
}

Save-Text '09-crash-dumps.txt' {
    Get-ChildItem -LiteralPath "$env:SystemRoot\Minidump" -Filter '*.dmp' -ErrorAction SilentlyContinue |
        Select-Object FullName,Length,CreationTime,LastWriteTime | Format-Table -AutoSize
    Get-Item -LiteralPath "$env:SystemRoot\MEMORY.DMP" -ErrorAction SilentlyContinue |
        Select-Object FullName,Length,CreationTime,LastWriteTime | Format-List
}

$setupApi = Join-Path $env:SystemRoot 'INF\setupapi.dev.log'
if (Test-Path -LiteralPath $setupApi) {
    Select-String -LiteralPath $setupApi -Pattern 'PNP0303|PNP030B|GOOG000A|GOOG000[BCDEF]|ELAN0000|i8042|croskeyboard|crostouchpad|wilco' -Context 8,20 |
        Out-String -Width 4096 | Set-Content -LiteralPath (Join-Path $destination '10-setupapi-relevant.txt') -Encoding utf8
}

Save-Text '11-acpi-fadt.txt' {
    $fadtRoot = 'Registry::HKEY_LOCAL_MACHINE\HARDWARE\ACPI\FADT'
    'ACPI FADT IAPC_BOOT_ARCH is a 16-bit field at byte offset 109. Bit 1 means an 8042-compatible controller is present.'
    if (!(Test-Path -LiteralPath $fadtRoot)) {
        throw 'The Windows ACPI FADT registry branch was not found.'
    }

    $tablesFound = 0
    Get-ChildItem -LiteralPath $fadtRoot -Recurse | ForEach-Object {
        $key = $_
        foreach ($valueName in $key.GetValueNames()) {
            $table = $key.GetValue($valueName)
            if (!($table -is [byte[]]) -or $table.Length -lt 111) { continue }

            $tablesFound++
            $signature = [Text.Encoding]::ASCII.GetString($table, 0, 4)
            $declaredLength = [BitConverter]::ToUInt32($table, 4)
            $revision = $table[8]
            $bootArch = [BitConverter]::ToUInt16($table, 109)
            [pscustomobject]@{
                RegistryKey        = $key.Name
                ValueName          = $valueName
                Signature          = $signature
                StoredLength       = $table.Length
                DeclaredLength     = $declaredLength
                Revision           = $revision
                IapcBootArch       = ('0x{0:X4}' -f $bootArch)
                LegacyDevicesBit0  = (($bootArch -band 0x0001) -ne 0)
                Controller8042Bit1 = (($bootArch -band 0x0002) -ne 0)
            } | Format-List
        }
    }
    if ($tablesFound -eq 0) { throw 'No parseable FADT table value was found.' }
}

$archive = "$destination.zip"
Compress-Archive -Path (Join-Path $destination '*') -DestinationPath $archive -Force
Write-Host "Diagnostics saved to: $archive"

