[CmdletBinding()]
param(
    [Alias('Profile')]
    [ValidateSet('Host')]
    [string]$DotfilesProfile = 'Host',
    [switch]$Desktop,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'This script requires PowerShell 7 or later.'
}

$Root = Split-Path -Parent $PSScriptRoot
$WingetArgs = @(
    'import',
    '--accept-package-agreements',
    '--accept-source-agreements',
    '--disable-interactivity',
    '--no-upgrade'
)

function Install-WingetFile([string]$Path) {
    if ($DryRun) { Write-Host "+ winget import $Path"; return }
    winget @WingetArgs --import-file $Path
}

function Add-GitInclude([string]$Config, [string]$Include) {
    $Directory = Split-Path -Parent $Config
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null

    $Existing = @(git config --file $Config --get-all include.path 2>$null)
    if ($Existing -notcontains $Include) {
        git config --file $Config --add include.path $Include
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add $Include to $Config."
        }
    }
}

Install-WingetFile "$Root/packages/windows/common.json"
if ($Desktop) {
    Install-WingetFile "$Root/packages/windows/desktop.json"
    & "$PSScriptRoot/install-hackgen-font.ps1" -DryRun:$DryRun
}
if ($DryRun) { return }

$env:DOTFILES_PROFILE = 'host'
$env:DOTFILES_DESKTOP = $Desktop.ToString().ToLowerInvariant()
$env:DOTFILES_ROBOTICS = 'false'
$env:DOTFILES_ROS_DISTRO = ''
$env:MISE_SYSTEM_CONFIG_DIR =
    Join-Path $HOME '.config/mise-managed'
$env:MISE_CONFIG_DIR =
    Join-Path $HOME '.config/mise'

mise x aqua:twpayne/chezmoi@latest -- chezmoi init --apply --force --source $Root
if ($LASTEXITCODE -ne 0) {
    throw "chezmoi apply failed with exit code $LASTEXITCODE."
}

Add-GitInclude `
    (Join-Path $HOME '.gitconfig') `
    '~/.config/git/config'
Add-GitInclude `
    (Join-Path $HOME '.config/git/config') `
    '~/.config/git/config.dotfiles'
Add-GitInclude `
    (Join-Path $HOME '.config/git/config') `
    '~/.config/git/config.local'

mise install
if ($LASTEXITCODE -ne 0) {
    throw "mise install failed with exit code $LASTEXITCODE."
}

$LoadedConfigs = mise config ls --no-header | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "mise config ls failed with exit code $LASTEXITCODE."
}

$ExpectedCommonConfig =
    [regex]::Escape(
        (Join-Path $env:MISE_SYSTEM_CONFIG_DIR 'conf.d/10-common.toml')
    )

if ($LoadedConfigs -notmatch $ExpectedCommonConfig) {
    throw 'mise did not load the managed common configuration.'
}

$ChezmoiTool = 'aqua:twpayne/chezmoi@2.71.0'

$ChezmoiInstallDirectory = (
    mise where $ChezmoiTool |
        Out-String
).Trim()

if ($LASTEXITCODE -ne 0 -or
    [string]::IsNullOrWhiteSpace($ChezmoiInstallDirectory)) {
    throw 'chezmoi was not installed by mise.'
}

if (-not (Test-Path $ChezmoiInstallDirectory)) {
    throw "chezmoi install directory does not exist: $ChezmoiInstallDirectory"
}

$ChezmoiExecutable = (
    mise which chezmoi --tool $ChezmoiTool |
        Out-String
).Trim()

if ($LASTEXITCODE -ne 0 -or
    [string]::IsNullOrWhiteSpace($ChezmoiExecutable)) {
    throw 'mise could not resolve the chezmoi executable.'
}

if (-not (Test-Path $ChezmoiExecutable)) {
    throw "chezmoi executable does not exist: $ChezmoiExecutable"
}

Write-Host "chezmoi install directory: $ChezmoiInstallDirectory"
Write-Host "chezmoi executable: $ChezmoiExecutable"

& $ChezmoiExecutable --version
if ($LASTEXITCODE -ne 0) {
    throw "chezmoi failed with exit code $LASTEXITCODE."
}

$ProfilePath = $PROFILE.CurrentUserAllHosts
if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
    throw 'CurrentUserAllHosts profile path is unavailable.'
}
& "$PSScriptRoot/update-powershell-profile.ps1" -ProfilePath $ProfilePath
