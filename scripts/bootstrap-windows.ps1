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
mise install --locked

$ManagedMain = Join-Path $HOME '.config/powershell/main.ps1'
$ManagedLocal = Join-Path $HOME '.config/powershell/local.ps1'
$ProfilePath = $PROFILE.CurrentUserAllHosts
$Start = '# >>> abco20 dotfiles >>>'
$End = '# <<< abco20 dotfiles <<<'
$Block = @"
$Start
if (Test-Path '$ManagedMain') { . '$ManagedMain' }
if (Test-Path '$ManagedLocal') { . '$ManagedLocal' }
$End
"@

$Existing = if (Test-Path $ProfilePath) { Get-Content $ProfilePath -Raw } else { '' }
$Pattern = '(?ms)^' + [regex]::Escape($Start) + '.*?^' + [regex]::Escape($End) + '\r?\n?'
$Updated = ([regex]::Replace($Existing, $Pattern, '')).TrimEnd() + "`r`n" + $Block + "`r`n"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ProfilePath) | Out-Null
Set-Content -Path $ProfilePath -Value $Updated -Encoding utf8NoBOM
