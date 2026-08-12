[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseDirectory,

    [Parameter(Mandatory = $true)]
    [string]$SevenZipPath,

    [Parameter(Mandatory = $true)]
    [string]$SfxModulePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+(\.\d+)?$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releasePath = (Resolve-Path -LiteralPath $ReleaseDirectory).Path
$sevenZip = (Resolve-Path -LiteralPath $SevenZipPath).Path
$sfxSource = (Resolve-Path -LiteralPath $SfxModulePath).Path
$iconPath = Join-Path $repositoryRoot 'app\windows\runner\resources\app_icon.ico'
$licensePath = Join-Path $repositoryRoot 'LICENSE'
$patchScript = Join-Path $PSScriptRoot 'patch_sfx.mjs'
$absoluteOutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $absoluteOutputPath

if (-not (Test-Path -LiteralPath (Join-Path $releasePath 'mkLS.exe'))) {
    throw "找不到已編譯的 mkLS.exe：$releasePath"
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$workDirectory = Join-Path ([IO.Path]::GetTempPath()) ("mkls-build-" + [guid]::NewGuid().ToString('N'))
$payloadDirectory = Join-Path $workDirectory 'payload'
$archivePath = Join-Path $workDirectory 'payload.7z'
$sfxPath = Join-Path $workDirectory 'mkLS-sfx.exe'
$configPath = Join-Path $workDirectory 'sfx-config.txt'

try {
    New-Item -ItemType Directory -Force -Path $payloadDirectory | Out-Null
    Copy-Item -Path (Join-Path $releasePath '*') -Destination $payloadDirectory -Recurse -Force

    foreach ($unneededFile in @(
        'install_msix_helper.ps1',
        'localsend_app.exe.manifest',
        'localsend_msix_helper.msix'
    )) {
        Remove-Item -LiteralPath (Join-Path $payloadDirectory $unneededFile) -Force -ErrorAction SilentlyContinue
    }

    [IO.File]::WriteAllText((Join-Path $payloadDirectory 'settings.json'), '{}', [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $licensePath -Destination (Join-Path $payloadDirectory 'LICENSE-LocalSend-Apache-2.0.txt') -Force

    & $sevenZip a -t7z -mx=9 -mmt=on $archivePath (Join-Path $payloadDirectory '*')
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip 建立封裝檔失敗，結束代碼：$LASTEXITCODE"
    }

    Copy-Item -LiteralPath $sfxSource -Destination $sfxPath -Force
    & node $patchScript $sfxPath $iconPath $Version
    if ($LASTEXITCODE -ne 0) {
        throw "無法設定單檔執行檔的圖示與版本資訊，結束代碼：$LASTEXITCODE"
    }

    $sfxConfiguration = @"
;!@Install@!UTF-8!
Title="mkLS $Version 單檔可攜版"
Progress="yes"
RunProgram="mkLS.exe"
;!@InstallEnd@!
"@
    [IO.File]::WriteAllText($configPath, $sfxConfiguration, [Text.UTF8Encoding]::new($false))

    $outputStream = [IO.File]::Create($absoluteOutputPath)
    try {
        foreach ($part in @($sfxPath, $configPath, $archivePath)) {
            $inputStream = [IO.File]::OpenRead($part)
            try {
                $inputStream.CopyTo($outputStream)
            } finally {
                $inputStream.Dispose()
            }
        }
    } finally {
        $outputStream.Dispose()
    }

    Write-Host "已建立：$absoluteOutputPath"
    Get-FileHash -Algorithm SHA256 -LiteralPath $absoluteOutputPath | Format-List
} finally {
    Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
