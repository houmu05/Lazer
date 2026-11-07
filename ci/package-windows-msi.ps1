# Builds the Windows MSI from a Flutter release bundle.
#
#   ./ci/package-windows-msi.ps1 -ReleaseDir build/windows/x64/runner/Release
#
# The script installs the WiX v3 toolset through Chocolatey when candle.exe is
# not already on the runner, harvests the bundle with heat.exe and links the
# MSI into dist/. Version metadata comes from pubspec.yaml unless the caller
# passes -ProductVersion/-DisplayName explicitly.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReleaseDir,
    [string]$OutputDir = 'dist',
    [string]$ProductVersion = '',
    [string]$DisplayName = '',
    [string]$Icon = 'windows/runner/resources/app_icon.ico'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$release = (Resolve-Path -LiteralPath $ReleaseDir).Path
$exe = Join-Path $release 'lazer_nextgen.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    throw "The release bundle has no lazer_nextgen.exe: $release"
}

# pubspec.yaml carries `version: 0.1.1-beta.1+9`; the MSI ProductVersion must
# be numeric, so the pre-release and build parts are dropped here.
$pubspecVersion = ''
$manifest = Join-Path $repo 'pubspec.yaml'
if (Test-Path -LiteralPath $manifest) {
    $line = Select-String -LiteralPath $manifest -Pattern '^version:\s*(\S+)' |
        Select-Object -First 1
    if ($line) { $pubspecVersion = $line.Matches[0].Groups[1].Value }
}
if ([string]::IsNullOrWhiteSpace($pubspecVersion)) {
    $pubspecVersion = '0.1.0'
}
$numeric = ($pubspecVersion -split '[+-]')[0]
$parts = $numeric.Split('.')
while ($parts.Count -lt 3) { $parts += '0' }
$numeric = ($parts[0..2] -join '.')
if ([string]::IsNullOrWhiteSpace($ProductVersion)) { $ProductVersion = $numeric }
if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = "Lazer $pubspecVersion" }

$wixBin = Join-Path ${env:ProgramFiles(x86)} 'WiX Toolset v3.14\bin'
if (-not (Test-Path -LiteralPath (Join-Path $wixBin 'candle.exe'))) {
    Write-Host 'Installing the WiX v3 toolset'
    choco install wixtoolset --no-progress -y
    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path -LiteralPath (Join-Path $wixBin 'candle.exe'))) {
        throw 'WiX v3 could not be installed'
    }
}

$work = Join-Path $env:RUNNER_TEMP 'lazer-msi'
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
New-Item -ItemType Directory -Path (Join-Path $work 'obj') -Force | Out-Null

$iconPath = (Resolve-Path -LiteralPath (Join-Path $repo $Icon)).Path
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$outputPath = (Resolve-Path -LiteralPath $OutputDir).Path
$msiPath = Join-Path $outputPath 'Lazer-Windows-x86_64.msi'

Push-Location $work
try {
    # -ag leaves Guid="*" on every component so candle derives a stable
    # component GUID from the file path instead of baking a placeholder.
    & (Join-Path $wixBin 'heat.exe') dir $release -cg AppFiles -dr INSTALLFOLDER `
        -sfrag -srd -sreg -ag -var var.ReleaseDir -out files.wxs
    if ($LASTEXITCODE -ne 0) { throw 'heat.exe failed' }

    $sources = @('files.wxs', (Join-Path $repo 'ci/windows/lazer.wxs'))
    & (Join-Path $wixBin 'candle.exe') -arch x64 -nologo `
        "-dReleaseDir=$release" "-dProductVersion=$ProductVersion" `
        "-dDisplayName=$DisplayName" "-dAppIcon=$iconPath" `
        -out 'obj\' @sources
    if ($LASTEXITCODE -ne 0) { throw 'candle.exe failed' }

    & (Join-Path $wixBin 'light.exe') -nologo -sval -out $msiPath 'obj\*.wixobj'
    if ($LASTEXITCODE -ne 0) { throw 'light.exe failed' }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $msiPath)) { throw "The MSI was not produced: $msiPath" }
Write-Host "Built $msiPath"

# Administrative extraction proves the package really carries the app before
# CI uploads it; a missing file here means the harvest missed the bundle.
$extract = Join-Path $env:RUNNER_TEMP 'lazer-msi-extract'
if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
Start-Process -FilePath msiexec.exe -ArgumentList @(
    '/a', "`"$msiPath`"", '/qn', "TARGETDIR=`"$extract`""
) -Wait -NoNewWindow
if (-not (Test-Path -LiteralPath (Join-Path $extract 'Lazer\lazer_nextgen.exe'))) {
    throw "The MSI does not install lazer_nextgen.exe into Lazer\ (extracted to $extract)"
}
Write-Host 'MSI administrative extraction contains the app'
