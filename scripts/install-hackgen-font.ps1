[CmdletBinding()]
param(
    [string]$Version = '2.10.0',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ArchiveName = "HackGen_NF_v$Version.zip"
$DownloadUri =
    "https://github.com/yuru7/HackGen/releases/download/v$Version/$ArchiveName"

if ($DryRun) {
    Write-Host "+ install HackGen Nerd Font v$Version"
    return
}

$Work = Join-Path ([System.IO.Path]::GetTempPath()) `
    "hackgen-$([guid]::NewGuid())"
$Archive = Join-Path $Work $ArchiveName
$Expanded = Join-Path $Work 'expanded'
$FontsDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts'
$FontsRegistry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

New-Item -ItemType Directory -Force -Path $Work, $Expanded | Out-Null
try {
    Invoke-WebRequest -Uri $DownloadUri -OutFile $Archive
    Expand-Archive -Path $Archive -DestinationPath $Expanded
    $Fonts = @(Get-ChildItem -Path $Expanded -Recurse -Filter '*.ttf')
    if ($Fonts.Count -eq 0) {
        throw "No TrueType fonts were found in $ArchiveName."
    }

    New-Item -ItemType Directory -Force -Path $FontsDirectory | Out-Null
    New-Item -Path $FontsRegistry -Force | Out-Null
    foreach ($Font in $Fonts) {
        $Destination = Join-Path $FontsDirectory $Font.Name
        Copy-Item -Force -Path $Font.FullName -Destination $Destination
        New-ItemProperty -Path $FontsRegistry `
            -Name "$($Font.BaseName) (TrueType)" `
            -Value $Destination -PropertyType String -Force | Out-Null
    }
}
finally {
    Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}
