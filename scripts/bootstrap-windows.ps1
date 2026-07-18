[CmdletBinding()]
param(
    [ValidateSet('Host')]
    [string]$Profile = 'Host',
    [switch]$Desktop,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'This script requires PowerShell 7 or later.'
}

$Root = Split-Path -Parent $PSScriptRoot
$WingetArgs = @('import', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')

function Install-WingetFile([string]$Path) {
    if ($DryRun) { Write-Host "+ winget import $Path"; return }
    winget @WingetArgs --import-file $Path
}

Install-WingetFile "$Root/packages/windows/common.json"
if ($Desktop) { Install-WingetFile "$Root/packages/windows/desktop.json" }
if ($DryRun) { return }

$env:DOTFILES_PROFILE = 'host'
$env:DOTFILES_DESKTOP = $Desktop.ToString().ToLowerInvariant()
$env:DOTFILES_ROBOTICS = 'false'
$env:DOTFILES_ROS_DISTRO = ''
$env:MISE_SYSTEM_CONFIG_DIR =
    Join-Path $HOME '.config/mise-managed'

mise x aqua:twpayne/chezmoi@latest -- chezmoi init --apply --less-interactive --source $Root
mise install
if ($LASTEXITCODE -ne 0) {
    throw "mise install failed with exit code $LASTEXITCODE."
}

& "$PSScriptRoot/update-powershell-profile.ps1"
