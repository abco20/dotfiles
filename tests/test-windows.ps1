$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Get-Content "$Root/packages/windows/common.json" -Raw | ConvertFrom-Json | Out-Null
Get-Content "$Root/packages/windows/desktop.json" -Raw | ConvertFrom-Json | Out-Null
[System.Management.Automation.Language.Parser]::ParseFile(
    "$Root/scripts/bootstrap-windows.ps1", [ref]$null, [ref]$null
) | Out-Null
[System.Management.Automation.Language.Parser]::ParseFile(
    "$Root/home/private_dot_config/powershell/main.ps1", [ref]$null, [ref]$null
) | Out-Null
Write-Host 'windows tests passed'
