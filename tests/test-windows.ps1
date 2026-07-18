$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Get-Content "$Root/packages/windows/common.json" -Raw | ConvertFrom-Json | Out-Null
Get-Content "$Root/packages/windows/desktop.json" -Raw | ConvertFrom-Json | Out-Null

function Assert-PowerShellSyntax([string]$Path) {
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$Tokens, [ref]$Errors
    ) | Out-Null
    if ($Errors.Count -gt 0) {
        throw "PowerShell syntax error in ${Path}: $($Errors -join '; ')"
    }
}

Assert-PowerShellSyntax "$Root/scripts/bootstrap-windows.ps1"
Assert-PowerShellSyntax "$Root/home/private_dot_config/powershell/main.ps1"
Assert-PowerShellSyntax "$Root/home/run_once_after_10-migrate-mise-lock.ps1"

if (-not (Test-Path "$Root/home/private_dot_config/mise-managed/mise.lock")) {
    throw 'Shared mise lockfile is missing.'
}
if (-not (Test-Path "$Root/home/private_dot_config/mise/create_config.toml") -or
    -not (Test-Path "$Root/home/private_dot_config/mise/create_mise.lock")) {
    throw 'Machine-local mise create files are missing.'
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'CI must use PowerShell 7 or later.'
}

$PreviousMiseSystemConfig = $env:MISE_SYSTEM_CONFIG_DIR
try {
    function global:lsd { }
    function global:bat { }
    function global:nvim { }
    . "$Root/home/private_dot_config/powershell/main.ps1"
    if ($env:MISE_SYSTEM_CONFIG_DIR -ne (Join-Path $HOME '.config/mise-managed')) {
        throw 'MISE_SYSTEM_CONFIG_DIR does not point to mise-managed.'
    }
    if ((Get-Alias ls).Definition -ne 'lsd') { throw 'ls alias was not replaced.' }
    if ((Get-Alias cat).Definition -ne 'bat') { throw 'cat alias was not replaced.' }
    if ((Get-Alias vi).Definition -ne 'nvim') { throw 'vi alias was not replaced.' }
}
finally {
    $env:MISE_SYSTEM_CONFIG_DIR = $PreviousMiseSystemConfig
    Remove-Item Function:\lsd, Function:\bat, Function:\nvim -ErrorAction SilentlyContinue
}
Write-Host 'windows tests passed'
