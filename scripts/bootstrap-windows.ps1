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

$ProfilePath = $PROFILE.CurrentUserAllHosts
if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
    throw 'CurrentUserAllHosts profile path is unavailable.'
}
& "$PSScriptRoot/update-powershell-profile.ps1" -ProfilePath $ProfilePath
