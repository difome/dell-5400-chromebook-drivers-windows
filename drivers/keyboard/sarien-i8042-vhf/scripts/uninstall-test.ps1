#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$PackageDirectory = $PSScriptRoot,
    [switch]$RemoveTestCertificate
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$devcon = Join-Path $package 'devcon.exe'
if (!(Test-Path -LiteralPath $devcon)) {
    $devcon = Get-ChildItem -LiteralPath 'C:\Program Files (x86)\Windows Kits\10\Tools' -Filter devcon.exe -Recurse -ErrorAction SilentlyContinue |
        Where-Object FullName -Match '\\x64\\' | Select-Object -First 1 -ExpandProperty FullName
}
if (!$devcon) { throw 'devcon.exe (x64) was not found. Install WDK tools.' }
& $devcon remove 'Root\SarienI8042Vhf'
if ($LASTEXITCODE -notin 0,1) { throw "devcon failed with exit code $LASTEXITCODE" }

if ($RemoveTestCertificate) {
    $cer = Join-Path $package 'SarienI8042-Test.cer'
    if (Test-Path -LiteralPath $cer) {
        $thumbprint = (Get-PfxCertificate -FilePath $cer).Thumbprint
        foreach ($store in 'Root','TrustedPublisher') {
            Remove-Item -LiteralPath "Cert:\LocalMachine\$store\$thumbprint" -Force -ErrorAction SilentlyContinue
        }
    }
}
Write-Host 'The root test device was removed. Remove its OEM INF with pnputil if desired.'

