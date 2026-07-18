[CmdletBinding()]
param(
    [string]$ProfilePath = $PROFILE.CurrentUserAllHosts,
    [string]$ManagedMain = (Join-Path $HOME '.config/powershell/main.ps1'),
    [string]$ManagedLocal = (Join-Path $HOME '.config/powershell/local.ps1')
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'This script requires PowerShell 7 or later.'
}

$Start = '# >>> abco20 dotfiles >>>'
$End = '# <<< abco20 dotfiles <<<'
$Block = @"
$Start
if (Test-Path '$ManagedMain') { . '$ManagedMain' }
if (Test-Path '$ManagedLocal') { . '$ManagedLocal' }
$End
"@

$Existing = if (Test-Path $ProfilePath) {
    Get-Content $ProfilePath -Raw
} else {
    ''
}
$StartMatches = [regex]::Matches($Existing, [regex]::Escape($Start))
$EndMatches = [regex]::Matches($Existing, [regex]::Escape($End))

if ($StartMatches.Count -ne $EndMatches.Count) {
    throw 'PowerShell profile contains unmatched dotfiles markers.'
}
if ($StartMatches.Count -gt 1) {
    throw 'PowerShell profile contains multiple dotfiles blocks.'
}
if ($StartMatches.Count -eq 1 -and
    $StartMatches[0].Index -gt $EndMatches[0].Index) {
    throw 'PowerShell profile markers are out of order.'
}

$Pattern = '(?ms)^' + [regex]::Escape($Start) +
    '.*?^' + [regex]::Escape($End) + '\r?\n?'
$Unmanaged = ([regex]::Replace($Existing, $Pattern, '')).TrimEnd()
$Updated = if ($Unmanaged.Length -eq 0) {
    $Block + "`r`n"
} else {
    $Unmanaged + "`r`n" + $Block + "`r`n"
}

$ProfileDirectory = Split-Path -Parent $ProfilePath
New-Item -ItemType Directory -Force -Path $ProfileDirectory | Out-Null
$TempProfile = Join-Path $ProfileDirectory ".profile-$([guid]::NewGuid()).tmp"
try {
    Set-Content -Path $TempProfile -Value $Updated -Encoding utf8NoBOM
    Move-Item -Force $TempProfile $ProfilePath
}
finally {
    Remove-Item -Force $TempProfile -ErrorAction SilentlyContinue
}
