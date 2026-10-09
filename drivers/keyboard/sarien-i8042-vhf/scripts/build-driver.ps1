[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string]$Configuration = 'Debug',
    [ValidateSet('ActionKeys','FunctionKeys')][string]$TopRowMode = 'ActionKeys'
)

$ErrorActionPreference = 'Stop'
$solution = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\SarienI8042.sln'))
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'vswhere.exe not found. Install Visual Studio 2022.' }
$install = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
if (!$install) { throw 'Visual Studio with MSBuild was not found.' }
$msbuild = Join-Path $install 'MSBuild\Current\Bin\amd64\MSBuild.exe'
if (!(Test-Path -LiteralPath $msbuild)) {
    $msbuild = Join-Path $install 'MSBuild\Current\Bin\MSBuild.exe'
}
if (!(Test-Path -LiteralPath $msbuild)) { throw "MSBuild not found: $msbuild" }

$toolsDirectory = Join-Path $projectRoot '.tools'
$nuget = Join-Path $toolsDirectory 'nuget.exe'
if (!(Test-Path -LiteralPath $nuget)) {
    New-Item -ItemType Directory -Path $toolsDirectory -Force | Out-Null
    Write-Host 'Downloading the official NuGet CLI...'
    Invoke-WebRequest -UseBasicParsing 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget
}

& $nuget restore (Join-Path $projectRoot 'packages.config') -PackagesDirectory (Join-Path $projectRoot 'packages') -NonInteractive -Source 'https://api.nuget.org/v3/index.json'
if ($LASTEXITCODE -ne 0) { throw "WDK NuGet restore failed with exit code $LASTEXITCODE" }

$functionRowMode = if ($TopRowMode -eq 'FunctionKeys') { 1 } else { 0 }
& $msbuild $solution /m /t:Rebuild "/p:Configuration=$Configuration" /p:Platform=x64 "/p:SarienFunctionRowMode=$functionRowMode" /v:minimal
if ($LASTEXITCODE -ne 0) { throw "Driver build failed with exit code $LASTEXITCODE" }

$driverPackage = Join-Path $projectRoot "driver\x64\$Configuration\SarienI8042"
$driverBinary = Join-Path $driverPackage 'SarienI8042.sys'
if (!(Test-Path -LiteralPath $driverBinary)) { throw "Built driver package was not found: $driverPackage" }

$signature = Get-AuthenticodeSignature -LiteralPath $driverBinary
if (!$signature.SignerCertificate) { throw 'The built driver is not signed.' }
Export-Certificate -Cert $signature.SignerCertificate `
    -FilePath (Join-Path $driverPackage 'SarienI8042-Test.cer') -Type CERT -Force | Out-Null

$devcon = Get-ChildItem (Join-Path $projectRoot 'packages') -Filter devcon.exe -Recurse -File |
    Where-Object { $_.FullName -Match 'Microsoft\.Windows\.WDK\.x64\.' -and $_.FullName -Match '\\x64\\' } |
    Select-Object -First 1 -ExpandProperty FullName
if (!$devcon) { throw 'The x64 DevCon test tool was not found in the restored WDK package.' }
Copy-Item -LiteralPath $devcon -Destination (Join-Path $driverPackage 'devcon.exe') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install-test.ps1') -Destination $driverPackage -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'INSTALL-KEYBOARD.ps1') -Destination $driverPackage -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall-test.ps1') -Destination $driverPackage -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'collect-diagnostics.ps1') -Destination $driverPackage -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $driverPackage -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'INSTALL-RU.md') -Destination $driverPackage -Force
"Top row mode: $TopRowMode" | Set-Content -LiteralPath (Join-Path $driverPackage 'TOP-ROW-MODE.txt') -Encoding ASCII
$symbols = Join-Path $projectRoot "driver\x64\$Configuration\SarienI8042.pdb"
if (Test-Path -LiteralPath $symbols) {
    Copy-Item -LiteralPath $symbols -Destination $driverPackage -Force
}

$artifacts = Join-Path $projectRoot 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$archive = Join-Path $artifacts "SarienI8042-$TopRowMode-$Configuration-x64.zip"
Compress-Archive -Path (Join-Path $driverPackage '*') -DestinationPath $archive -Force

$outputs = Get-ChildItem (Join-Path $PSScriptRoot '..\driver') -Recurse -File |
    Where-Object { $_.Extension -in '.sys','.inf','.cat','.pdb' -and $_.FullName -match "x64.+$Configuration|$Configuration.+x64" }
Write-Host 'Build completed. Candidate package files:'
$outputs | Select-Object FullName,Length | Format-Table -AutoSize
Write-Host "Deployable test package: $archive"

