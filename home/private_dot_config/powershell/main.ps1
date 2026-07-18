$env:MISE_SYSTEM_CONFIG_DIR =
    Join-Path $HOME '.config/mise-managed'
$env:MISE_CONFIG_DIR =
    Join-Path $HOME '.config/mise'

if (Get-Command mise -ErrorAction SilentlyContinue) {
    (& mise activate pwsh) | Out-String | Invoke-Expression
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    (& starship init powershell) | Out-String | Invoke-Expression
}

Set-Alias ls lsd -Force
Set-Alias cat bat -Force
Set-Alias vi nvim -Force
