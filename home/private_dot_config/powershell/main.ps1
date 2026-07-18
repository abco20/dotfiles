$env:MISE_SYSTEM_CONFIG_DIR =
    Join-Path $HOME '.config/mise-managed'

if (Get-Command mise -ErrorAction SilentlyContinue) {
    (& mise activate pwsh) | Out-String | Invoke-Expression
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    (& starship init powershell) | Out-String | Invoke-Expression
}

if (Get-Command lsd -ErrorAction SilentlyContinue) {
    Set-Alias ls lsd -Force
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias cat bat -Force
}
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias vi nvim -Force
}
